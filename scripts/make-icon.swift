// Отрисовка иконки AutoSwitcher: индиго-синий градиент, белая клавиатура,
// янтарная клавиша-акцент. Запуск: swift scripts/make-icon.swift <папка-выхода>
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

func roundedPath(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil)
}

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    NSColor(calibratedRed: r / 255, green: g / 255, blue: b / 255, alpha: a).cgColor
}

func drawIcon(_ cg: CGContext) {
    // Фон: сквиркл с диагональным градиентом индиго → синий.
    cg.saveGState()
    cg.addPath(roundedPath(0, 0, 1024, 1024, 232))
    cg.clip()
    let grad = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [color(99, 102, 241), color(37, 99, 235)] as CFArray,
        locations: [0, 1]
    )!
    cg.drawLinearGradient(grad, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [])
    cg.restoreGState()

    // Плашка клавиатуры с мягкой тенью.
    let plateX: CGFloat = 172, plateY: CGFloat = 322, plateW: CGFloat = 680, plateH: CGFloat = 388
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -14), blur: 34, color: color(0, 0, 0, 0.28))
    cg.addPath(roundedPath(plateX, plateY, plateW, plateH, 56))
    cg.setFillColor(color(255, 255, 255))
    cg.fillPath()
    cg.restoreGState()

    // Клавиши.
    let margin: CGFloat = 44
    let keyH: CGFloat = 72
    let gap: CGFloat = 20
    let innerX = plateX + margin
    let innerW = plateW - 2 * margin
    let keyFill = color(199, 210, 254)   // светло-индиговые клавиши
    let accentFill = color(245, 158, 11) // янтарный акцент

    func keyRow(count: Int, yTop: CGFloat, accentIndex: Int? = nil) {
        let w = (innerW - CGFloat(count - 1) * gap) / CGFloat(count)
        for i in 0..<count {
            let x = innerX + CGFloat(i) * (w + gap)
            cg.addPath(roundedPath(x, yTop - keyH, w, keyH, 16))
            cg.setFillColor(i == accentIndex ? accentFill : keyFill)
            cg.fillPath()
        }
    }

    let row1Top = plateY + plateH - margin              // 666
    let row2Top = row1Top - keyH - gap                  // 574
    let row3Top = row2Top - keyH - gap                  // 482

    keyRow(count: 10, yTop: row1Top)
    keyRow(count: 9, yTop: row2Top, accentIndex: 4)
    // Нижний ряд: 4 клавиши + пробел + 2 клавиши.
    let sideKeyW = (innerW - 190 - 6 * gap) / 6
    var x = innerX
    for _ in 0..<4 {
        cg.addPath(roundedPath(x, row3Top - keyH, sideKeyW, keyH, 16))
        cg.setFillColor(keyFill); cg.fillPath()
        x += sideKeyW + gap
    }
    cg.addPath(roundedPath(x, row3Top - keyH, 190, keyH, 16))
    cg.setFillColor(color(148, 163, 236)); cg.fillPath()
    x += 190 + gap
    for _ in 0..<2 {
        cg.addPath(roundedPath(x, row3Top - keyH, sideKeyW, keyH, 16))
        cg.setFillColor(keyFill); cg.fillPath()
        x += sideKeyW + gap
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
    drawIcon(cg)
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
