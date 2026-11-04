// Отрисовка иконки AutoSwitcher: значок сам является клавишей с буквами A и Я —
// первой и последней буквами русского алфавита. Цвета плоские, буквы нарисованы
// контурами, поэтому результат не зависит от шрифтов системы.
// Запуск: swift scripts/make-icon.swift <папка-выхода>
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

func hex(_ v: UInt32) -> CGColor {
    NSColor(calibratedRed: CGFloat((v >> 16) & 255) / 255,
            green: CGFloat((v >> 8) & 255) / 255,
            blue: CGFloat(v & 255) / 255,
            alpha: 1).cgColor
}

let ink = hex(0x16171A)
let vermilion = hex(0xE8431F)
let face = hex(0xF5F3ED)
let skirt = hex(0xCFCBC0)

// Буквы заданы в собственных координатах: начало внизу слева, высота 220.
let letterHeight: CGFloat = 220

func letterA() -> (path: CGPath, width: CGFloat) {
    let p = CGMutablePath()
    p.addLines(between: [
        CGPoint(x: 0, y: 0), CGPoint(x: 66, y: 0), CGPoint(x: 85, y: 46), CGPoint(x: 175, y: 46),
        CGPoint(x: 194, y: 0), CGPoint(x: 260, y: 0), CGPoint(x: 168, y: 220), CGPoint(x: 92, y: 220)
    ])
    p.closeSubpath()
    // Внутренний треугольник: при заливке even-odd он становится отверстием.
    p.addLines(between: [CGPoint(x: 104, y: 92), CGPoint(x: 156, y: 92), CGPoint(x: 130, y: 153)])
    p.closeSubpath()
    return (p, 260)
}

func letterYa() -> (path: CGPath, width: CGFloat) {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: 208, y: 220))
    p.addLine(to: CGPoint(x: 208, y: 0))
    p.addLine(to: CGPoint(x: 138, y: 0))
    p.addLine(to: CGPoint(x: 138, y: 72))
    p.addLine(to: CGPoint(x: 112, y: 72))
    p.addLine(to: CGPoint(x: 74, y: 0))
    p.addLine(to: CGPoint(x: 0, y: 0))
    p.addLine(to: CGPoint(x: 46, y: 84))
    // Внешний контур чаши.
    p.addCurve(to: CGPoint(x: 6, y: 148), control1: CGPoint(x: 20, y: 96), control2: CGPoint(x: 6, y: 118))
    p.addCurve(to: CGPoint(x: 84, y: 220), control1: CGPoint(x: 6, y: 194), control2: CGPoint(x: 38, y: 220))
    p.closeSubpath()
    // Отверстие чаши.
    p.move(to: CGPoint(x: 138, y: 170))
    p.addLine(to: CGPoint(x: 96, y: 170))
    p.addCurve(to: CGPoint(x: 76, y: 146), control1: CGPoint(x: 84, y: 170), control2: CGPoint(x: 76, y: 160))
    p.addCurve(to: CGPoint(x: 96, y: 120), control1: CGPoint(x: 76, y: 131), control2: CGPoint(x: 84, y: 120))
    p.addLine(to: CGPoint(x: 138, y: 120))
    p.closeSubpath()
    return (p, 208)
}

func draw(_ letter: (path: CGPath, width: CGFloat), center: CGPoint, scale: CGFloat, fill: CGColor, _ cg: CGContext) {
    cg.saveGState()
    cg.translateBy(x: center.x - letter.width * scale / 2, y: center.y - letterHeight * scale / 2)
    cg.scaleBy(x: scale, y: scale)
    cg.addPath(letter.path)
    cg.setFillColor(fill)
    cg.fillPath(using: .evenOdd)
    cg.restoreGState()
}

func drawIcon(_ cg: CGContext, px: Int) {
    // Корпус клавиши по сетке значков macOS: 824×824 на холсте 1024×1024.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -10), blur: 20, color: NSColor(white: 0, alpha: 0.28).cgColor)
    cg.addPath(CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil))
    cg.setFillColor(skirt)
    cg.fillPath()
    cg.restoreGState()

    // Верхняя площадка клавиши.
    let top = CGRect(x: 148, y: 208, width: 728, height: 676)
    cg.addPath(CGPath(roundedRect: top, cornerWidth: 148, cornerHeight: 148, transform: nil))
    cg.setFillColor(face)
    cg.fillPath()

    if px <= 16 {
        // В 16 px две буквы слились бы: остаётся одна крупная Я.
        draw(letterYa(), center: CGPoint(x: top.midX, y: top.midY), scale: 2.2, fill: vermilion, cg)
    } else {
        draw(letterA(), center: CGPoint(x: top.minX + 212, y: top.maxY - 196), scale: 1, fill: ink, cg)
        draw(letterYa(), center: CGPoint(x: top.maxX - 212, y: top.minY + 196), scale: 1, fill: vermilion, cg)
    }
}

func render(px: Int) -> NSBitmapImageRep? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    guard let g = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.current = g
    let cg = g.cgContext
    cg.scaleBy(x: CGFloat(px) / 1024, y: CGFloat(px) / 1024)
    drawIcon(cg, px: px)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let specs: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]

let dirURL = URL(fileURLWithPath: outDir)
for (name, px) in specs {
    guard let rep = render(px: px),
          let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("не удалось отрисовать \(name)")
    }
    try! data.write(to: dirURL.appendingPathComponent(name))
}
print("iconset готов: \(outDir)")
