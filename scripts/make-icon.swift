// Отрисовка иконки AutoSwitcher: индиго-синий фон и клавиатура Mac с настоящей раскладкой.
// Янтарным выделена клавиша глобуса — именно она переключает языки.
// Запуск: swift scripts/make-icon.swift <папка-выхода>
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

func roundedPath(_ rect: CGRect, _ r: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
}

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    NSColor(calibratedRed: r / 255, green: g / 255, blue: b / 255, alpha: a).cgColor
}

// Раскладка в единицах ширины клавиши: каждый ряд занимает ровно 14,5 единицы.
struct Key {
    var width: CGFloat = 1
    var latin = ""
    var cyrillic = ""
    var isGlobe = false
}

func letters(_ latin: String, _ cyrillic: String) -> [Key] {
    zip(latin, cyrillic).map { Key(latin: String($0), cyrillic: String($1)) }
}

func blanks(_ count: Int) -> [Key] {
    Array(repeating: Key(), count: count)
}

let rows: [[Key]] = [
    blanks(13) + [Key(width: 1.5)],
    [Key(width: 1.5)] + letters("QWERTYUIOP", "ЙЦУКЕНГШЩЗ") + letters("[]", "ХЪ") + blanks(1),
    [Key(width: 1.75)] + letters("ASDFGHJKL", "ФЫВАПРОЛД") + letters(";'", "ЖЭ") + [Key(width: 1.75)],
    [Key(width: 2.25)] + letters("ZXCVBNM", "ЯЧСМИТЬ") + letters(",.", "БЮ") + blanks(1) + [Key(width: 2.25)],
    [Key(isGlobe: true), Key(), Key(), Key(width: 1.25), Key(width: 5), Key(width: 1.25), Key()]
]

let plateRect = CGRect(x: 124, y: 362, width: 776, height: 300)
let plateInset: CGFloat = 18
let unit = (plateRect.width - 2 * plateInset) / 14.5
let rowHeight = (plateRect.height - 2 * plateInset) / CGFloat(rows.count)
let keyGap: CGFloat = 5
let keyRadius: CGFloat = 8

let keyFill = color(255, 255, 255)
let accentFill = color(245, 158, 11)
let plateFill = color(203, 209, 232)

func drawKey(_ cg: CGContext, _ rect: CGRect, fill: CGColor) {
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -2), blur: 2, color: color(30, 41, 89, 0.3))
    cg.addPath(roundedPath(rect, keyRadius))
    cg.setFillColor(fill)
    cg.fillPath()
    cg.restoreGState()
}

func drawText(_ text: String, in rect: CGRect, size: CGFloat, weight: NSFont.Weight, color textColor: CGColor) {
    let string = NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: NSColor(cgColor: textColor) ?? .black
    ])
    let measured = string.size()
    string.draw(at: CGPoint(x: rect.midX - measured.width / 2, y: rect.midY - measured.height / 2))
}

func drawGlobe(_ cg: CGContext, in rect: CGRect) {
    let d = min(rect.width, rect.height) * 0.56
    let circle = CGRect(x: rect.midX - d / 2, y: rect.midY - d / 2, width: d, height: d)
    cg.saveGState()
    cg.setStrokeColor(color(255, 255, 255))
    cg.setLineWidth(3)
    cg.strokeEllipse(in: circle)
    cg.strokeEllipse(in: circle.insetBy(dx: d * 0.25, dy: 0))
    cg.move(to: CGPoint(x: circle.minX, y: circle.midY))
    cg.addLine(to: CGPoint(x: circle.maxX, y: circle.midY))
    cg.strokePath()
    cg.restoreGState()
}

func drawIcon(_ cg: CGContext, px: Int) {
    // Фон: сквиркл по сетке значков macOS (поля 100 из 1024) с лёгкой тенью.
    let background = CGRect(x: 100, y: 100, width: 824, height: 824)
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -10), blur: 20, color: color(0, 0, 0, 0.3))
    cg.addPath(roundedPath(background, 185))
    cg.setFillColor(color(67, 100, 238))
    cg.fillPath()
    cg.restoreGState()

    cg.saveGState()
    cg.addPath(roundedPath(background, 185))
    cg.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [color(99, 102, 241), color(37, 99, 235)] as CFArray,
        locations: [0, 1]
    )!
    cg.drawLinearGradient(gradient, start: CGPoint(x: 100, y: 924), end: CGPoint(x: 924, y: 100), options: [])
    cg.restoreGState()

    // Корпус клавиатуры.
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(15, 23, 60, 0.4))
    cg.addPath(roundedPath(plateRect, 26))
    cg.setFillColor(plateFill)
    cg.fillPath()
    cg.restoreGState()

    let left = plateRect.minX + plateInset
    let top = plateRect.maxY - plateInset

    // На мелких размерах подписи превратились бы в шум.
    let showLatin = px >= 256
    let showCyrillic = px >= 512
    let legend = color(55, 65, 100)
    let secondLegend = color(79, 70, 229)

    for (index, row) in rows.enumerated() {
        let y = top - rowHeight * CGFloat(index + 1)
        var x = left
        for key in row {
            let rect = CGRect(x: x + keyGap / 2, y: y + keyGap / 2,
                              width: key.width * unit - keyGap, height: rowHeight - keyGap)
            drawKey(cg, rect, fill: key.isGlobe ? accentFill : keyFill)
            if key.isGlobe {
                drawGlobe(cg, in: rect)
            } else if !key.latin.isEmpty, showLatin {
                if showCyrillic {
                    let w = rect.width * 0.52, h = rect.height * 0.52
                    drawText(key.latin, in: CGRect(x: rect.minX + 2, y: rect.maxY - h - 1, width: w, height: h),
                             size: 16, weight: .semibold, color: legend)
                    drawText(key.cyrillic, in: CGRect(x: rect.maxX - w - 2, y: rect.minY + 1, width: w, height: h),
                             size: 16, weight: .semibold, color: secondLegend)
                } else {
                    drawText(key.latin, in: rect, size: 24, weight: .semibold, color: legend)
                }
            }
            x += key.width * unit
        }
    }

    // Стрелки — перевёрнутая буква «Т» в правом конце нижнего ряда.
    let bottomY = top - rowHeight * CGFloat(rows.count)
    let arrowsX = left + 11.5 * unit
    let half = (rowHeight - keyGap) / 2 - 1
    func arrowKey(column: CGFloat, upper: Bool) {
        let y = bottomY + keyGap / 2 + (upper ? half + 2 : 0)
        drawKey(cg, CGRect(x: arrowsX + column * unit + keyGap / 2, y: y, width: unit - keyGap, height: half), fill: keyFill)
    }
    arrowKey(column: 0, upper: false)
    arrowKey(column: 1, upper: true)
    arrowKey(column: 1, upper: false)
    arrowKey(column: 2, upper: false)
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
