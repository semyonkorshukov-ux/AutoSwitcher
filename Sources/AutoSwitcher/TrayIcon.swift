import AppKit

/// Значок строки меню: контур клавиши с буквами A и Я, как на логотипе.
/// Шаблонное изображение: цвет под тему и обои подбирает сама macOS.
enum TrayIcon {
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            guard let cg = NSGraphicsContext.current?.cgContext else { return false }
            cg.setStrokeColor(NSColor.black.cgColor)
            cg.setFillColor(NSColor.black.cgColor)

            cg.setLineWidth(1.3)
            let key = CGRect(x: 1.65, y: 1.65, width: 14.7, height: 14.7)
            cg.addPath(CGPath(roundedRect: key, cornerWidth: 4, cornerHeight: 4, transform: nil))
            cg.strokePath()

            cg.addPath(letter(letterA, width: 260, centerX: 6.4, centerY: 11.4))
            cg.fillPath(using: .evenOdd)
            cg.addPath(letter(letterYa, width: 208, centerX: 11.6, centerY: 6.6))
            cg.fillPath(using: .evenOdd)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "AutoSwitcher"
        return image
    }

    /// Высота букв в значке; контуры заданы при высоте 220, как в scripts/make-icon.swift.
    private static let letterHeight: CGFloat = 5.2

    private static func letter(_ path: CGPath, width: CGFloat, centerX: CGFloat, centerY: CGFloat) -> CGPath {
        let scale = letterHeight / 220
        var transform = CGAffineTransform(translationX: centerX - width * scale / 2, y: centerY - letterHeight / 2)
            .scaledBy(x: scale, y: scale)
        return path.copy(using: &transform) ?? path
    }

    private static let letterA: CGPath = {
        let p = CGMutablePath()
        p.addLines(between: [
            CGPoint(x: 0, y: 0), CGPoint(x: 66, y: 0), CGPoint(x: 85, y: 46), CGPoint(x: 175, y: 46),
            CGPoint(x: 194, y: 0), CGPoint(x: 260, y: 0), CGPoint(x: 168, y: 220), CGPoint(x: 92, y: 220)
        ])
        p.closeSubpath()
        p.addLines(between: [CGPoint(x: 104, y: 92), CGPoint(x: 156, y: 92), CGPoint(x: 130, y: 153)])
        p.closeSubpath()
        return p
    }()

    private static let letterYa: CGPath = {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 208, y: 220))
        p.addLine(to: CGPoint(x: 208, y: 0))
        p.addLine(to: CGPoint(x: 138, y: 0))
        p.addLine(to: CGPoint(x: 138, y: 72))
        p.addLine(to: CGPoint(x: 112, y: 72))
        p.addLine(to: CGPoint(x: 74, y: 0))
        p.addLine(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: 46, y: 84))
        p.addCurve(to: CGPoint(x: 6, y: 148), control1: CGPoint(x: 20, y: 96), control2: CGPoint(x: 6, y: 118))
        p.addCurve(to: CGPoint(x: 84, y: 220), control1: CGPoint(x: 6, y: 194), control2: CGPoint(x: 38, y: 220))
        p.closeSubpath()
        p.move(to: CGPoint(x: 138, y: 170))
        p.addLine(to: CGPoint(x: 96, y: 170))
        p.addCurve(to: CGPoint(x: 76, y: 146), control1: CGPoint(x: 84, y: 170), control2: CGPoint(x: 76, y: 160))
        p.addCurve(to: CGPoint(x: 96, y: 120), control1: CGPoint(x: 76, y: 131), control2: CGPoint(x: 84, y: 120))
        p.addLine(to: CGPoint(x: 138, y: 120))
        p.closeSubpath()
        return p
    }()
}
