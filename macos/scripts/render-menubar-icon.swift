#!/usr/bin/env swift
// render-menubar-icon.swift — Macaveli menubar icon renderer
//
// Renders MenuBarIcon @1x/@2x/@3x (16/32/48 px) into the asset catalog.
// macOS template rendering tints every non-transparent pixel to match the
// menubar (white on dark, black on light), so this draws solid black and
// relies on alpha-only silhouetting.
//
// Design: a bold geometric capital M. Single thick stroked path tracing
// bottom-left → top-left → V-dip → top-right → bottom-right. Direct,
// brand-forward, no metaphor required.
//
// Run from `macos/`:
//   swift scripts/render-menubar-icon.swift

import AppKit
import CoreGraphics

let outputDir = "Macaveli/Assets.xcassets/MenuBarIcon.imageset"

// (px size, filename) — keep in sync with Contents.json in the imageset.
let outputs: [(size: Int, filename: String)] = [
    (16, "icon@1x.png"),
    (32, "icon@2x.png"),
    (48, "icon@3x.png"),
]

func renderMenuBarIcon(size: Int) -> CGImage {
    let s = CGFloat(size)
    let cs = CGColorSpaceCreateDeviceRGB()

    guard let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError("Cannot create context for size \(size)") }

    // Flip to top-left origin so the math reads like SwiftUI / UIKit.
    ctx.translateBy(x: 0, y: s)
    ctx.scaleBy(x: 1, y: -1)

    // Design proportions are anchored to the 32 px ("base") canvas, then
    // scaled. This keeps the @1x/@2x/@3x outputs visually consistent.
    let scale = s / 32.0
    let padding: CGFloat = 2.0 * scale
    let strokeWidth: CGFloat = 5.0 * scale

    // Compute path corners, insetting by half-stroke so the strokes sit
    // *inside* the padded area instead of bleeding past it.
    let inset = strokeWidth / 2
    let leftX = padding + inset
    let rightX = s - padding - inset
    let topY = padding + inset
    let bottomY = s - padding - inset
    let centerX = s / 2

    // V-dip y: 60% of the way down. Below 55% the V flattens too much; above
    // 65% the angle gets so acute the miter join blows out at small sizes.
    let vDipY = topY + (bottomY - topY) * 0.6

    ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    ctx.setLineWidth(strokeWidth)
    ctx.setLineJoin(.miter)
    ctx.setMiterLimit(8)
    ctx.setLineCap(.butt)

    ctx.beginPath()
    ctx.move(to:    CGPoint(x: leftX,    y: bottomY))
    ctx.addLine(to: CGPoint(x: leftX,    y: topY))
    ctx.addLine(to: CGPoint(x: centerX,  y: vDipY))
    ctx.addLine(to: CGPoint(x: rightX,   y: topY))
    ctx.addLine(to: CGPoint(x: rightX,   y: bottomY))
    ctx.strokePath()

    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(
        url as CFURL,
        "public.png" as CFString,
        1,
        nil
    ) else { fatalError("Cannot create PNG destination at \(path)") }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        fatalError("Cannot finalize PNG at \(path)")
    }
}

// ---------------------------------------------------------------------------

let fm = FileManager.default
let cwd = fm.currentDirectoryPath
let absOutputDir = (cwd as NSString).appendingPathComponent(outputDir)
guard fm.fileExists(atPath: absOutputDir) else {
    fputs("Asset directory not found: \(absOutputDir)\n", stderr)
    fputs("Run this script from `macos/`.\n", stderr)
    exit(1)
}

for (size, filename) in outputs {
    let image = renderMenuBarIcon(size: size)
    let path = (absOutputDir as NSString).appendingPathComponent(filename)
    writePNG(image, to: path)
    print("wrote \(filename) (\(size)×\(size))")
}

print("done — built menubar icons in \(outputDir)")
