// Фон окна установочного DMG: стрелка от приложения к «Программам» и подсказки.
// Запуск: swift scripts/make-dmg-background.swift <выходной.png> <масштаб>
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let scale = Int(args[2]) else {
    fatalError("использование: make-dmg-background.swift <выходной.png> <масштаб>")
}

// Размер должен совпадать с окном в scripts/make-dmg.sh.
let width = 660, height = 400

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: width * scale, pixelsHigh: height * scale,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
), let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
    fatalError("не удалось создать холст")
}
rep.size = NSSize(width: width, height: height)
NSGraphicsContext.current = ctx
let cg = ctx.cgContext
cg.scaleBy(x: CGFloat(scale), y: CGFloat(scale))

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

// Светлый фон с лёгким оттенком индиго из иконки.
NSGradient(starting: color(248, 249, 255), ending: color(229, 233, 252))?
    .draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -90)

func drawCentered(_ text: String, y: CGFloat, font: NSFont, color textColor: NSColor) {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    NSAttributedString(string: text, attributes: [
        .font: font, .foregroundColor: textColor, .paragraphStyle: style
    ]).draw(in: NSRect(x: 30, y: y, width: CGFloat(width) - 60, height: 60))
}

drawCentered("Перетащите AutoSwitcher в папку Applications",
             y: 310, font: .systemFont(ofSize: 20, weight: .semibold), color: color(55, 48, 163))

// Стрелка между значками (центры значков заданы в make-dmg.sh: x = 170 и x = 490).
let arrowY = CGFloat(height) - 190
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 268, y: arrowY))
arrow.line(to: NSPoint(x: 382, y: arrowY))
arrow.lineWidth = 7
arrow.lineCapStyle = .round
color(99, 102, 241).setStroke()
arrow.stroke()

let head = NSBezierPath()
head.move(to: NSPoint(x: 366, y: arrowY + 19))
head.line(to: NSPoint(x: 392, y: arrowY))
head.line(to: NSPoint(x: 366, y: arrowY - 19))
head.lineWidth = 7
head.lineCapStyle = .round
head.lineJoinStyle = .round
head.stroke()

let hintFont = NSFont.systemFont(ofSize: 12)
let hintColor = color(75, 85, 120)
drawCentered("Если macOS не даст открыть приложение: Системные настройки →",
             y: 38, font: hintFont, color: hintColor)
drawCentered("Конфиденциальность и безопасность → «Всё равно открыть»",
             y: 20, font: hintFont, color: hintColor)

NSGraphicsContext.current = nil
guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("не удалось закодировать PNG")
}
try! png.write(to: URL(fileURLWithPath: args[1]))
