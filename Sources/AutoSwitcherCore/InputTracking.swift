import CoreGraphics
import Foundation

/// Какие изменения модификаторов прерывают набираемое слово.
public enum KeyEventPolicy {
    /// Shift — обычная часть набора заглавных букв и слово не прерывает.
    /// Cmd/Ctrl/Option/Fn начинают сочетание клавиш, а Caps Lock часто меняет раскладку.
    public static func modifierChangeResetsWord(flags: CGEventFlags, capsLockWasOn: Bool) -> Bool {
        let shortcutModifiers: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskSecondaryFn]
        return !flags.intersection(shortcutModifiers).isEmpty
            || flags.contains(.maskAlphaShift) != capsLockWasOn
    }
}

/// Распознаёт двойное нажатие Shift без других клавиш между нажатиями.
public struct DoubleShiftDetector {
    private let maxHold: TimeInterval
    private let maxGap: TimeInterval
    private var downAt: TimeInterval?
    private var lastTapAt: TimeInterval?

    public init(maxHold: TimeInterval = 0.3, maxGap: TimeInterval = 0.4) {
        self.maxHold = maxHold
        self.maxGap = maxGap
    }

    /// Возвращает true на втором нажатии.
    public mutating func shift(isDown: Bool, at time: TimeInterval) -> Bool {
        if isDown {
            if let lastTapAt, time - lastTapAt <= maxGap {
                cancel()
                return true
            }
            downAt = time
            lastTapAt = nil
        } else {
            if let downAt, time - downAt <= maxHold {
                lastTapAt = time
            } else {
                lastTapAt = nil
            }
            downAt = nil
        }
        return false
    }

    /// Любой другой ввод прерывает последовательность.
    public mutating func cancel() {
        downAt = nil
        lastTapAt = nil
    }
}

/// Что сделать, чтобы отменить исправление.
public struct UndoAction: Equatable {
    public let charsToDelete: Int
    public let text: String
    public let restore: FixTarget
    /// false — слово ещё набирается, и его остаток нельзя исправлять снова.
    public let wordFinished: Bool

    public init(charsToDelete: Int, text: String, restore: FixTarget, wordFinished: Bool) {
        self.charsToDelete = charsToDelete
        self.text = text
        self.restore = restore
        self.wordFinished = wordFinished
    }
}

/// Помнит последнее исправление и всё, что набрано после него в этом же слове.
public struct FixUndoTracker {
    private var fix: Fix?
    private var typedAfterFix = ""
    private var restoredAfterFix = ""
    private var wordFinished = false

    public init() {}

    public mutating func record(_ fix: Fix) {
        self.fix = fix
        typedAfterFix = ""
        restoredAfterFix = ""
        wordFinished = fix.replacement.last?.isLetter == false
    }

    public mutating func noteTyped(_ c: Character) {
        guard let fix else { return }
        guard !wordFinished else { return cancel() }
        if c.isLetter {
            typedAfterFix.append(c)
            let text = String(c)
            restoredAfterFix += fix.target == .russian ? KeyMap.mapRuToEn(text) : KeyMap.mapEnToRu(text)
        } else if c == " " || c.isPunctuation || c.isSymbol {
            typedAfterFix.append(c)
            restoredAfterFix.append(c)
            wordFinished = true
        } else {
            cancel()
        }
    }

    public mutating func cancel() {
        fix = nil
    }

    /// Возвращает действие один раз: повторное нажатие ничего не отменяет.
    public mutating func takeUndo() -> UndoAction? {
        guard let fix else { return nil }
        self.fix = nil
        return UndoAction(charsToDelete: fix.replacement.count + typedAfterFix.count,
                          text: fix.original + restoredAfterFix,
                          restore: fix.target.opposite,
                          wordFinished: wordFinished)
    }
}
