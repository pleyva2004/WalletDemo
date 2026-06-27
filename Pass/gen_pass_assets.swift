#!/usr/bin/env swift
//
// gen_pass_assets.swift — headless PNG asset generator for the .pkpass eventTicket bundle.
// Pure CoreGraphics (draw) + ImageIO (encode) + CoreText (text). No Xcode GUI, no AppKit.
//
//   swift gen_pass_assets.swift <output-dir>      (defaults to CWD if no arg)
//
// Produces, at the correct .pkpass eventTicket sizes:
//   icon.png / icon@2x.png / icon@3x.png   (29 / 58 / 87 px)   — REQUIRED
//   logo.png / logo@2x.png                 (160x50 / 320x100)  — header wordmark
//   strip.png / strip@2x.png / strip@3x.png(375x98 / 750x196 / 1125x294) — hero pitch
//
import Foundation
import CoreGraphics
import ImageIO
import CoreText
import UniformTypeIdentifiers

let outDir: String = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(r/255), green: CGFloat(g/255), blue: CGFloat(b/255), alpha: CGFloat(a))
}
let fieldGreen   = rgb(34, 139, 34)
let fieldGreenDk = rgb(24, 110, 28)
let brandNavy    = rgb(11, 38, 80)
let white        = rgb(255, 255, 255)
let nearBlack    = rgb(20, 20, 20)

let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

func makeContext(_ w: Int, _ h: Int) -> CGContext {
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                        bytesPerRow: 0, space: srgb,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high
    return ctx
}

func writePNG(_ ctx: CGContext, to path: String) {
    guard let image = ctx.makeImage() else {
        FileHandle.standardError.write("ERROR makeImage failed: \(path)\n".data(using: .utf8)!); exit(1)
    }
    let url = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        FileHandle.standardError.write("ERROR dest create failed: \(path)\n".data(using: .utf8)!); exit(1)
    }
    CGImageDestinationAddImage(dest, image, nil)
    if !CGImageDestinationFinalize(dest) {
        FileHandle.standardError.write("ERROR finalize failed: \(path)\n".data(using: .utf8)!); exit(1)
    }
    print("wrote \(path) (\(ctx.width)x\(ctx.height))")
}

// NOTE: in a pure Foundation+CoreText context (no AppKit/UIKit), `.font`/`.foregroundColor`
// do not exist on NSAttributedString.Key — they are AppKit/UIKit extensions. Build the keys
// from the raw CoreText constants instead.
func drawCenteredText(_ s: String, in rect: CGRect, font: CTFont, color: CGColor, ctx: CGContext) {
    let attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color
    ]
    let attr = NSAttributedString(string: s, attributes: attrs)
    let line = CTLineCreateWithAttributedString(attr)
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    ctx.textPosition = CGPoint(x: rect.midX - bounds.width/2 - bounds.minX,
                               y: rect.midY - bounds.height/2 - bounds.minY)
    CTLineDraw(line, ctx)
}

func font(_ size: CGFloat, bold: Bool = true) -> CTFont {
    CTFontCreateWithName((bold ? "HelveticaNeue-Bold" : "HelveticaNeue") as CFString, size, nil)
}

func drawIcon(_ size: Int, to path: String) {
    let ctx = makeContext(size, size); let s = CGFloat(size)
    ctx.setFillColor(brandNavy); ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))
    let r = s * 0.34; let c = CGPoint(x: s/2, y: s/2)
    ctx.setFillColor(white); ctx.fillEllipse(in: CGRect(x: c.x-r, y: c.y-r, width: 2*r, height: 2*r))
    ctx.setFillColor(nearBlack); let dot = s * 0.07
    ctx.fillEllipse(in: CGRect(x: c.x-dot/2, y: c.y-dot/2, width: dot, height: dot))
    for i in 0..<5 {
        let ang = CGFloat(i)/5 * 2 * .pi + .pi/2
        let px = c.x + cos(ang)*r*0.55, py = c.y + sin(ang)*r*0.55, d = s*0.05
        ctx.fillEllipse(in: CGRect(x: px-d/2, y: py-d/2, width: d, height: d))
    }
    writePNG(ctx, to: path)
}

func drawLogo(width: Int, height: Int, to path: String) {
    let ctx = makeContext(width, height)
    ctx.clear(CGRect(x: 0, y: 0, width: width, height: height)) // transparent bg
    drawCenteredText("WC26", in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)),
                     font: font(CGFloat(height)*0.62, bold: true), color: white, ctx: ctx)
    writePNG(ctx, to: path)
}

func drawStrip(width: Int, height: Int, to path: String) {
    let ctx = makeContext(width, height); let w = CGFloat(width), h = CGFloat(height)
    ctx.setFillColor(fieldGreen); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    let stripes = 8; let sw = w/CGFloat(stripes); ctx.setFillColor(fieldGreenDk)
    for i in stride(from: 0, to: stripes, by: 2) { ctx.fill(CGRect(x: CGFloat(i)*sw, y: 0, width: sw, height: h)) }
    ctx.setStrokeColor(white); ctx.setLineWidth(max(2, h*0.02))
    ctx.move(to: CGPoint(x: w/2, y: 0)); ctx.addLine(to: CGPoint(x: w/2, y: h)); ctx.strokePath()
    let cr = h*0.28; ctx.strokeEllipse(in: CGRect(x: w/2-cr, y: h/2-cr, width: 2*cr, height: 2*cr))
    ctx.setFillColor(white); let spot = h*0.03
    ctx.fillEllipse(in: CGRect(x: w/2-spot/2, y: h/2-spot/2, width: spot, height: spot))
    writePNG(ctx, to: path)
}

drawIcon(29, to: "\(outDir)/icon.png")
drawIcon(58, to: "\(outDir)/icon@2x.png")
drawIcon(87, to: "\(outDir)/icon@3x.png")
drawLogo(width: 160, height: 50,  to: "\(outDir)/logo.png")
drawLogo(width: 320, height: 100, to: "\(outDir)/logo@2x.png")
drawStrip(width: 375,  height: 98,  to: "\(outDir)/strip.png")
drawStrip(width: 750,  height: 196, to: "\(outDir)/strip@2x.png")
drawStrip(width: 1125, height: 294, to: "\(outDir)/strip@3x.png")
print("done -> \(outDir)")
