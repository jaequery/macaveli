#!/usr/bin/env swift
// render-icon.swift — Macaveli app icon renderer
// Renders all 7 required sizes independently using AppKit/CoreGraphics.
// Run from project root: swift scripts/render-icon.swift

import AppKit
import CoreGraphics
import CoreText

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

let sizes = [16, 32, 64, 128, 256, 512, 1024]

// sRGB color components
let gradientTopLeft    = (r: 0.427, g: 0.157, b: 0.851, a: 1.0) // #6D28D9
let gradientBotRight   = (r: 0.655, g: 0.545, b: 0.980, a: 1.0) // #A78BFA
let recordingRed       = (r: 1.000, g: 0.231, b: 0.188, a: 1.0) // #FF3B30

let outputDir: String = {
    let fm = FileManager.default
    // Support running from any cwd by resolving relative to this script's location
    // But the brief says cwd = project root, so just use relative path.
    let rel = "Macaveli/Assets.xcassets/AppIcon.appiconset"
    let cwd = fm.currentDirectoryPath
    return (cwd as NSString).appendingPathComponent(rel)
}()

// ---------------------------------------------------------------------------
// Render one size
// ---------------------------------------------------------------------------

func renderIcon(size: Int) -> CGImage {
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
    ) else {
        fatalError("Could not create CGContext for size \(size)")
    }

    // ---- coordinate system: origin bottom-left in CG, but we'll work top-down
    // by flipping the context.
    ctx.translateBy(x: 0, y: s)
    ctx.scaleBy(x: 1, y: -1)

    // ---- geometry
    let padding    = s * 0.10          // 10% bleed
    let rectSize   = s - padding * 2
    let cornerR    = rectSize * 0.22   // ~22% corner radius
    let iconRect   = CGRect(x: padding, y: padding, width: rectSize, height: rectSize)

    // ---- rounded rect path
    let path = CGPath(roundedRect: iconRect, cornerWidth: cornerR, cornerHeight: cornerR, transform: nil)

    // ---- clip to rounded rect for gradient fill
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()

    // gradient: top-left -> bottom-right
    let gradColors = [
        CGColor(colorSpace: cs, components: [
            gradientTopLeft.r, gradientTopLeft.g, gradientTopLeft.b, gradientTopLeft.a
        ])!,
        CGColor(colorSpace: cs, components: [
            gradientBotRight.r, gradientBotRight.g, gradientBotRight.b, gradientBotRight.a
        ])!
    ]
    let locations: [CGFloat] = [0.0, 1.0]
    guard let gradient = CGGradient(colorsSpace: cs, colors: gradColors as CFArray, locations: locations) else {
        fatalError("Could not create gradient")
    }
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: iconRect.minX, y: iconRect.minY),
        end:   CGPoint(x: iconRect.maxX, y: iconRect.maxY),
        options: []
    )

    // subtle inner highlight (top edge, white semi-transparent)
    let highlightH = rectSize * 0.45
    let highlightColors = [
        CGColor(colorSpace: cs, components: [1.0, 1.0, 1.0, 0.18])!,
        CGColor(colorSpace: cs, components: [1.0, 1.0, 1.0, 0.0])!
    ]
    guard let hlGradient = CGGradient(colorsSpace: cs, colors: highlightColors as CFArray, locations: locations) else {
        fatalError("Could not create highlight gradient")
    }
    ctx.drawLinearGradient(
        hlGradient,
        start: CGPoint(x: iconRect.midX, y: iconRect.minY),
        end:   CGPoint(x: iconRect.midX, y: iconRect.minY + highlightH),
        options: []
    )

    ctx.restoreGState()

    // ---- outer shadow (drawn by stroking behind — we simulate with a blurred shadow)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: s * 0.015),
                  blur: s * 0.06,
                  color: CGColor(colorSpace: cs, components: [0, 0, 0, 0.35])!)
    ctx.addPath(path)
    ctx.setFillColor(CGColor(colorSpace: cs, components: [0, 0, 0, 0])!)
    ctx.fillPath()
    ctx.restoreGState()

    // ---- "M" letter
    // Use NSAttributedString + CTLine for precise, size-independent rendering
    let targetFontSize = rectSize * 0.55
    // Try SF Rounded Heavy; fall back to system heavy
    var font = CTFontCreateWithName("SF Rounded" as CFString, targetFontSize, nil)
    // Check if we got a real SF Rounded or just a fallback
    let fontName = CTFontCopyPostScriptName(font) as String
    if !fontName.lowercased().contains("rounded") {
        // Try alternate name
        font = CTFontCreateWithName(".AppleSystemUIFontRounded-Heavy" as CFString, targetFontSize, nil)
        let fn2 = CTFontCopyPostScriptName(font) as String
        if !fn2.lowercased().contains("rounded") {
            // Use system font with rounded design via descriptor
            let desc = CTFontDescriptorCreateWithAttributes([
                kCTFontTraitsAttribute: [
                    kCTFontWeightTrait: 0.62 as CFNumber
                ] as CFDictionary
            ] as CFDictionary)
            font = CTFontCreateWithFontDescriptor(desc, targetFontSize, nil)
        }
    }

    // Build attributed string
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white
    ]
    let attrStr = NSAttributedString(string: "M", attributes: attrs)
    let line = CTLineCreateWithAttributedString(attrStr)
    var ascent: CGFloat = 0
    var descent: CGFloat = 0
    var leading: CGFloat = 0
    let lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
    let lineHeight = ascent + descent

    let textX = iconRect.midX - CGFloat(lineWidth) / 2
    let textY = iconRect.midY + lineHeight / 2 - ascent

    ctx.saveGState()
    ctx.textPosition = CGPoint(x: textX, y: textY + descent)
    CTLineDraw(line, ctx)
    ctx.restoreGState()

    // ---- recording dot (bottom-right)
    let dotDiameter = s * 0.14
    let dotRadius   = dotDiameter / 2
    let dotCenterX  = iconRect.maxX - s * 0.14
    let dotCenterY  = iconRect.maxY - s * 0.14
    let dotRect = CGRect(
        x: dotCenterX - dotRadius,
        y: dotCenterY - dotRadius,
        width: dotDiameter,
        height: dotDiameter
    )

    // dot fill — pure Apple red
    ctx.saveGState()
    ctx.addEllipse(in: dotRect)
    ctx.setFillColor(CGColor(colorSpace: cs, components: [
        recordingRed.r, recordingRed.g, recordingRed.b, recordingRed.a
    ])!)
    ctx.fillPath()

    // tiny white inner highlight on the dot
    let hlDotDiam = dotDiameter * 0.38
    let hlDotRect = CGRect(
        x: dotCenterX - hlDotDiam / 2 - dotRadius * 0.15,
        y: dotCenterY - hlDotDiam / 2 - dotRadius * 0.20,
        width: hlDotDiam,
        height: hlDotDiam
    )
    ctx.addEllipse(in: hlDotRect)
    ctx.setFillColor(CGColor(colorSpace: cs, components: [1.0, 1.0, 1.0, 0.55])!)
    ctx.fillPath()
    ctx.restoreGState()

    guard let image = ctx.makeImage() else {
        fatalError("Could not create CGImage for size \(size)")
    }
    return image
}

// ---------------------------------------------------------------------------
// Write PNG
// ---------------------------------------------------------------------------

func writePNG(image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        fatalError("Could not create image destination for \(path)")
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        fatalError("Could not write PNG to \(path)")
    }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

let fm = FileManager.default
if !fm.fileExists(atPath: outputDir) {
    print("ERROR: output directory not found: \(outputDir)")
    print("Run this script from the project root.")
    exit(1)
}

let fileMap: [Int: String] = [
    16:   "16-mac.png",
    32:   "32-mac.png",
    64:   "64-mac.png",
    128:  "128-mac.png",
    256:  "256-mac.png",
    512:  "512-mac.png",
    1024: "1024-mac.png"
]

for size in sizes {
    let filename = fileMap[size]!
    let outPath = (outputDir as NSString).appendingPathComponent(filename)
    let image = renderIcon(size: size)
    writePNG(image: image, to: outPath)
    print("Wrote \(size)x\(size) -> \(filename)")
}

print("Done. All \(sizes.count) icons written to:")
print(outputDir)

// ---------------------------------------------------------------------------
// Build a proper AppIcon.icns via iconutil
//
// Xcode's asset compiler silently drops slot variants when the same PNG file
// is referenced for multiple Contents.json entries, producing an .icns with
// only 4 of 10 expected size chunks. We work around that by building the
// .icns directly here. The Makefile's `build` target overwrites the broken
// asset-catalog .icns inside the built .app with the one we produce.
// ---------------------------------------------------------------------------

let cwd = fm.currentDirectoryPath
let iconsetDir = (cwd as NSString).appendingPathComponent("build/.tmp-iconset.iconset")
let icnsOut = (cwd as NSString).appendingPathComponent("Macaveli/AppIcon.icns")

// Clean + recreate the temp iconset
try? fm.removeItem(atPath: iconsetDir)
do {
    try fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)
} catch {
    print("WARN: could not create \(iconsetDir): \(error)")
    exit(0)
}

// iconutil's expected iconset filenames → source PNG mapping
let iconsetMap: [(name: String, sourcePixels: Int)] = [
    ("icon_16x16.png",      16),
    ("icon_16x16@2x.png",   32),
    ("icon_32x32.png",      32),
    ("icon_32x32@2x.png",   64),
    ("icon_128x128.png",    128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png",    256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png",    512),
    ("icon_512x512@2x.png", 1024)
]

for entry in iconsetMap {
    let src = (outputDir as NSString).appendingPathComponent(fileMap[entry.sourcePixels]!)
    let dst = (iconsetDir as NSString).appendingPathComponent(entry.name)
    try? fm.removeItem(atPath: dst)
    do {
        try fm.copyItem(atPath: src, toPath: dst)
    } catch {
        print("WARN: copy \(src) -> \(dst) failed: \(error)")
    }
}

// Invoke iconutil to produce the .icns
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconsetDir, "-o", icnsOut]
let errPipe = Pipe()
proc.standardError = errPipe
do {
    try proc.run()
    proc.waitUntilExit()
    if proc.terminationStatus == 0 {
        let attrs = try fm.attributesOfItem(atPath: icnsOut)
        let bytes = attrs[.size] as? Int ?? 0
        print("Wrote \(icnsOut) (\(bytes) bytes)")
    } else {
        let err = errPipe.fileHandleForReading.readDataToEndOfFile()
        print("WARN: iconutil exit \(proc.terminationStatus): \(String(data: err, encoding: .utf8) ?? "")")
    }
} catch {
    print("WARN: failed to run iconutil: \(error)")
}

try? fm.removeItem(atPath: iconsetDir)
