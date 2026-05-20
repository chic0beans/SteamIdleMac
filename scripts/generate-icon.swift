#!/usr/bin/env swift
import AppKit
import CoreGraphics

let size = 1024
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: size, height: size,
                    bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// Background: dark green rounded square (macOS-style mask shrink ~ 80%)
let inset: CGFloat = 100
let rect = CGRect(x: inset, y: inset, width: CGFloat(size) - inset*2, height: CGFloat(size) - inset*2)
let radius: CGFloat = 200

// Gradient background
let colors = [
    CGColor(red: 0.08, green: 0.30, blue: 0.20, alpha: 1),
    CGColor(red: 0.05, green: 0.18, blue: 0.13, alpha: 1)
] as CFArray
let gradient = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1])!

let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
ctx.saveGState()
ctx.addPath(path)
ctx.clip()
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: 0, y: CGFloat(size)),
                       end: CGPoint(x: 0, y: 0),
                       options: [])
ctx.restoreGState()

// Inner highlight stroke
ctx.addPath(path)
ctx.setStrokeColor(CGColor(red: 0.30, green: 0.55, blue: 0.42, alpha: 0.5))
ctx.setLineWidth(6)
ctx.strokePath()

// Draw a stylized capsule (Steam game banner) with two dots (eyes-of-controller hint)
let capsuleW: CGFloat = 540
let capsuleH: CGFloat = 220
let cx = CGFloat(size) / 2
let cy = CGFloat(size) / 2 + 50
let capsuleRect = CGRect(x: cx - capsuleW/2, y: cy - capsuleH/2, width: capsuleW, height: capsuleH)
let capsulePath = CGPath(roundedRect: capsuleRect, cornerWidth: capsuleH/2, cornerHeight: capsuleH/2, transform: nil)

ctx.saveGState()
ctx.addPath(capsulePath)
ctx.setFillColor(CGColor(red: 0.93, green: 0.96, blue: 0.94, alpha: 1))
ctx.fillPath()
ctx.restoreGState()

// Two "controller eyes" / Z motif: draw a stylized Z inside capsule
ctx.saveGState()
ctx.setStrokeColor(CGColor(red: 0.06, green: 0.20, blue: 0.14, alpha: 1))
ctx.setLineWidth(48)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)

let zPad: CGFloat = 60
let zRect = capsuleRect.insetBy(dx: zPad, dy: 30)
ctx.move(to: CGPoint(x: zRect.minX, y: zRect.maxY))
ctx.addLine(to: CGPoint(x: zRect.maxX, y: zRect.maxY))
ctx.addLine(to: CGPoint(x: zRect.minX, y: zRect.minY))
ctx.addLine(to: CGPoint(x: zRect.maxX, y: zRect.minY))
ctx.strokePath()
ctx.restoreGState()

// "STEAM IDLE" tiny mark at bottom
let str = NSAttributedString(string: "IDLE", attributes: [
    .font: NSFont.systemFont(ofSize: 110, weight: .heavy),
    .foregroundColor: NSColor(red: 0.80, green: 0.92, blue: 0.85, alpha: 1),
    .kern: 12
])
let line = CTLineCreateWithAttributedString(str)
let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
ctx.textPosition = CGPoint(x: cx - bounds.width/2, y: cy - capsuleH/2 - 180)
CTLineDraw(line, ctx)

guard let cg = ctx.makeImage() else { exit(1) }
let rep = NSBitmapImageRep(cgImage: cg)
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
let outPath = CommandLine.arguments.dropFirst().first ?? "icon-1024.png"
try png.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath)")
