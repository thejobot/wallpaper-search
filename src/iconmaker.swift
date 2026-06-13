import AppKit

// Renders a 1024x1024 app icon PNG. Output path is argv[1], default "icon_1024.png".
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

let S: CGFloat = 1024
let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

let inset: CGFloat = 80
let rect = CGRect(x: inset, y: inset, width: S-2*inset, height: S-2*inset)
let path = CGPath(roundedRect: rect, cornerWidth: 200, cornerHeight: 200, transform: nil)
ctx.addPath(path); ctx.clip()
let cs = CGColorSpaceCreateDeviceRGB()
let grad = CGGradient(colorsSpace: cs, colors: [
    NSColor(calibratedRed: 0.36, green: 0.44, blue: 0.95, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.55, green: 0.30, blue: 0.85, alpha: 1).cgColor] as CFArray,
    locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])

// sun
ctx.setFillColor(NSColor(calibratedRed: 1, green: 0.85, blue: 0.4, alpha: 1).cgColor)
ctx.fillEllipse(in: CGRect(x: S*0.60, y: S*0.62, width: S*0.16, height: S*0.16))

// back mountain
ctx.setFillColor(NSColor(white: 1, alpha: 0.45).cgColor)
ctx.beginPath()
ctx.move(to: CGPoint(x: inset, y: S*0.42))
ctx.addLine(to: CGPoint(x: S*0.42, y: S*0.70))
ctx.addLine(to: CGPoint(x: S*0.66, y: S*0.46))
ctx.addLine(to: CGPoint(x: S-inset, y: S*0.66))
ctx.addLine(to: CGPoint(x: S-inset, y: inset))
ctx.addLine(to: CGPoint(x: inset, y: inset))
ctx.closePath(); ctx.fillPath()

// front mountain
ctx.setFillColor(NSColor(white: 1, alpha: 0.95).cgColor)
ctx.beginPath()
ctx.move(to: CGPoint(x: inset, y: inset))
ctx.addLine(to: CGPoint(x: S*0.30, y: S*0.52))
ctx.addLine(to: CGPoint(x: S*0.52, y: S*0.30))
ctx.addLine(to: CGPoint(x: S*0.78, y: S*0.58))
ctx.addLine(to: CGPoint(x: S-inset, y: S*0.40))
ctx.addLine(to: CGPoint(x: S-inset, y: inset))
ctx.closePath(); ctx.fillPath()

img.unlockFocus()

if let tiff = img.tiffRepresentation, let bmp = NSBitmapImageRep(data: tiff),
   let png = bmp.representation(using: .png, properties: [:]) {
    try? png.write(to: URL(fileURLWithPath: outPath))
    print("icon written: \(outPath)")
}
