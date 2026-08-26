#!/usr/bin/env swift

import AppKit
import CoreGraphics
import CoreText

// MARK: - RackOff App Store Story Card Generator
// Generates 5 high-converting marketing cards at 2880x1800 and 1440x900

struct CardSpec {
    let filename: String
    let badge: String
    let headline: String
    let subheadline: String
    let type: CardType
}

enum CardType {
    case heroPopover
    case threeModes
    case fileToggles
    case safeArchive
    case noSubscriptions
}

let cards: [CardSpec] = [
    CardSpec(
        filename: "01-instant-desktop-relief",
        badge: "✨ INSTANT DESKTOP RELIEF",
        headline: "Desktop chaos? Cleaned in one click.",
        subheadline: "RackOff sweeps screenshots, random PDFs, and clutter into tidy dated folders, then gets out of your way.",
        type: .heroPopover
    ),
    CardSpec(
        filename: "02-three-clean-modes",
        badge: "🗂️ 3 WAYS TO ORGANIZE",
        headline: "Quick Archive, Sort by Type, or Smart Clean.",
        subheadline: "Bundle clutter by date, sort documents and media into matching tribes, or customize your own rules.",
        type: .threeModes
    ),
    CardSpec(
        filename: "03-target-file-types",
        badge: "🎯 TARGET WHAT BUGS YOU",
        headline: "Toggle screenshots, downloads, and loose files.",
        subheadline: "Tidy up debugging screenshots without touching project files you're still working on.",
        type: .fileToggles
    ),
    CardSpec(
        filename: "04-nothing-is-deleted",
        badge: "🛡️ 100% SAFE & REVERSIBLE",
        headline: "Nothing is ever deleted. Just relocated.",
        subheadline: "Everything rests safely in Documents/Archive. Jump straight to your organized files with one click.",
        type: .safeArchive
    ),
    CardSpec(
        filename: "05-no-subscriptions",
        badge: "🔒 100% PRIVATE • ZERO SUBSCRIPTIONS",
        headline: "Pay once. Yours forever.",
        subheadline: "$9.99 one-time. No accounts, no cloud sync, and zero tracking. Works completely locally on your Mac.",
        type: .noSubscriptions
    )
]

func drawCard(spec: CardSpec, width: CGFloat, height: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { return image }

    let scale = width / 2880.0

    // 1. Background gradient (Warm obsidian with sunset orange glow)
    let bgColors = [
        NSColor(red: 0.08, green: 0.06, blue: 0.06, alpha: 1.0).cgColor,
        NSColor(red: 0.13, green: 0.08, blue: 0.07, alpha: 1.0).cgColor,
        NSColor(red: 0.06, green: 0.05, blue: 0.05, alpha: 1.0).cgColor
    ]
    let bgGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                            colors: bgColors as CFArray,
                            locations: [0.0, 0.5, 1.0])!
    ctx.drawLinearGradient(bgGrad,
                           start: CGPoint(x: width * 0.5, y: height),
                           end: CGPoint(x: width * 0.5, y: 0),
                           options: [])

    // 2. Ambient top glow orb (Sunset Orange & Pink)
    let glowColors = [
        NSColor(red: 1.0, green: 0.55, blue: 0.20, alpha: 0.22).cgColor,
        NSColor(red: 1.0, green: 0.35, blue: 0.60, alpha: 0.09).cgColor,
        NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0).cgColor
    ]
    let glowGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: glowColors as CFArray,
                              locations: [0.0, 0.4, 1.0])!
    ctx.drawRadialGradient(glowGrad,
                           startCenter: CGPoint(x: width * 0.5, y: height * 0.85),
                           startRadius: 0,
                           endCenter: CGPoint(x: width * 0.5, y: height * 0.85),
                           endRadius: width * 0.55,
                           options: [])

    // 3. Header Text Section
    let topY = height - (140 * scale)

    // Badge
    let badgeFont = NSFont.systemFont(ofSize: 22 * scale, weight: .bold)
    let badgeAttrs: [NSAttributedString.Key: Any] = [
        .font: badgeFont,
        .foregroundColor: NSColor(red: 1.0, green: 0.65, blue: 0.25, alpha: 0.95),
        .kern: 2.0 * scale
    ]
    let badgeString = NSAttributedString(string: spec.badge, attributes: badgeAttrs)
    let badgeSize = badgeString.size()
    let badgeRect = CGRect(x: (width - badgeSize.width) / 2, y: topY - badgeSize.height, width: badgeSize.width, height: badgeSize.height)
    badgeString.draw(in: badgeRect)

    // Headline
    let headlineFont = NSFont.systemFont(ofSize: 64 * scale, weight: .black)
    let headlineStyle = NSMutableParagraphStyle()
    headlineStyle.alignment = .center
    let headlineAttrs: [NSAttributedString.Key: Any] = [
        .font: headlineFont,
        .foregroundColor: NSColor(red: 0.99, green: 0.97, blue: 0.94, alpha: 1.0),
        .paragraphStyle: headlineStyle
    ]
    let headlineString = NSAttributedString(string: spec.headline, attributes: headlineAttrs)
    let headlineRect = CGRect(x: width * 0.08, y: badgeRect.minY - (90 * scale), width: width * 0.84, height: 80 * scale)
    headlineString.draw(in: headlineRect)

    // Subheadline
    let subFont = NSFont.systemFont(ofSize: 28 * scale, weight: .medium)
    let subStyle = NSMutableParagraphStyle()
    subStyle.alignment = .center
    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: subFont,
        .foregroundColor: NSColor(red: 0.92, green: 0.85, blue: 0.82, alpha: 0.80),
        .paragraphStyle: subStyle
    ]
    let subString = NSAttributedString(string: spec.subheadline, attributes: subAttrs)
    let subRect = CGRect(x: width * 0.12, y: headlineRect.minY - (54 * scale), width: width * 0.76, height: 50 * scale)
    subString.draw(in: subRect)

    // 4. Main Body Content Area
    let contentY: CGFloat = 80 * scale
    let contentHeight = subRect.minY - contentY - (40 * scale)
    let contentRect = CGRect(x: width * 0.10, y: contentY, width: width * 0.80, height: contentHeight)

    switch spec.type {
    case .heroPopover:
        drawHeroPopover(in: contentRect, scale: scale, ctx: ctx)
    case .threeModes:
        drawThreeModes(in: contentRect, scale: scale, ctx: ctx)
    case .fileToggles:
        drawFileToggles(in: contentRect, scale: scale, ctx: ctx)
    case .safeArchive:
        drawSafeArchive(in: contentRect, scale: scale, ctx: ctx)
    case .noSubscriptions:
        drawNoSubscriptions(in: contentRect, scale: scale, ctx: ctx)
    }

    image.unlockFocus()
    return image
}

func drawHeroPopover(in rect: CGRect, scale: CGFloat, ctx: CGContext) {
    let mockWidth: CGFloat = rect.width * 0.65
    let mockHeight: CGFloat = rect.height * 0.92
    let mockRect = CGRect(x: rect.midX - (mockWidth / 2), y: rect.midY - (mockHeight / 2), width: mockWidth, height: mockHeight)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -24 * scale), blur: 50 * scale, color: NSColor.black.withAlphaComponent(0.65).cgColor)
    let path = CGPath(roundedRect: mockRect, cornerWidth: 24 * scale, cornerHeight: 24 * scale, transform: nil)
    ctx.addPath(path)
    ctx.setFillColor(NSColor(red: 0.12, green: 0.09, blue: 0.09, alpha: 0.96).cgColor)
    ctx.fillPath()

    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    ctx.setLineWidth(2.5 * scale)
    ctx.setStrokeColor(NSColor(red: 1.0, green: 0.55, blue: 0.25, alpha: 0.45).cgColor)
    ctx.addPath(path)
    ctx.strokePath()
    ctx.restoreGState()

    // Header
    let hFont = NSFont.systemFont(ofSize: 28 * scale, weight: .heavy)
    let hAttrs: [NSAttributedString.Key: Any] = [
        .font: hFont,
        .foregroundColor: NSColor(red: 1.0, green: 0.60, blue: 0.30, alpha: 1.0)
    ]
    let hStr = NSAttributedString(string: "✨ RackOff", attributes: hAttrs)
    hStr.draw(at: CGPoint(x: mockRect.midX - (hStr.size().width / 2), y: mockRect.maxY - (64 * scale)))

    // Big Glowing Clean Button
    let btnWidth = mockWidth - (64 * scale)
    let btnHeight: CGFloat = 80 * scale
    let btnRect = CGRect(x: mockRect.minX + (32 * scale), y: mockRect.maxY - (170 * scale), width: btnWidth, height: btnHeight)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8 * scale), blur: 24 * scale, color: NSColor(red: 1.0, green: 0.45, blue: 0.30, alpha: 0.55).cgColor)
    let btnPath = CGPath(roundedRect: btnRect, cornerWidth: 20 * scale, cornerHeight: 20 * scale, transform: nil)
    ctx.addPath(btnPath)

    let btnGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                             colors: [
                                NSColor(red: 1.0, green: 0.60, blue: 0.20, alpha: 1.0).cgColor,
                                NSColor(red: 1.0, green: 0.35, blue: 0.55, alpha: 1.0).cgColor
                             ] as CFArray,
                             locations: [0.0, 1.0])!
    ctx.clip()
    ctx.drawLinearGradient(btnGrad, start: CGPoint(x: btnRect.minX, y: btnRect.midY), end: CGPoint(x: btnRect.maxX, y: btnRect.midY), options: [])
    ctx.restoreGState()

    let bFont = NSFont.systemFont(ofSize: 24 * scale, weight: .black)
    let bAttrs: [NSAttributedString.Key: Any] = [
        .font: bFont,
        .foregroundColor: NSColor.white,
        .kern: 1.0 * scale
    ]
    let bStr = NSAttributedString(string: "🧹 Clean Desktop Now", attributes: bAttrs)
    let bSize = bStr.size()
    bStr.draw(at: CGPoint(x: btnRect.midX - (bSize.width / 2), y: btnRect.midY - (bSize.height / 2)))

    // Status / Mode Rows
    let rows = [
        ("📁 Organization Mode", "Quick Archive (Daily Folders)"),
        ("📸 Screenshots", "Include (14 found)"),
        ("📄 Documents & PDFs", "Include (8 found)"),
        ("📦 Archive Destination", "~/Documents/Archive/2026-08-26/")
    ]

    let listY = btnRect.minY - (30 * scale)
    let rowHeight = (listY - mockRect.minY - (20 * scale)) / CGFloat(rows.count)

    for (i, row) in rows.enumerated() {
        let rY = listY - CGFloat(i + 1) * rowHeight
        let rRect = CGRect(x: mockRect.minX + (32 * scale), y: rY + (6 * scale), width: mockWidth - (64 * scale), height: rowHeight - (12 * scale))

        ctx.saveGState()
        let rPath = CGPath(roundedRect: rRect, cornerWidth: 14 * scale, cornerHeight: 14 * scale, transform: nil)
        ctx.addPath(rPath)
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.04).cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        let lFont = NSFont.systemFont(ofSize: 16 * scale, weight: .bold)
        let lAttrs: [NSAttributedString.Key: Any] = [
            .font: lFont,
            .foregroundColor: NSColor(red: 1.0, green: 0.75, blue: 0.40, alpha: 0.95)
        ]
        let lStr = NSAttributedString(string: row.0, attributes: lAttrs)
        lStr.draw(at: CGPoint(x: rRect.minX + 20 * scale, y: rRect.midY - (lStr.size().height / 2)))

        let vFont = NSFont.systemFont(ofSize: 15 * scale, weight: .medium)
        let vAttrs: [NSAttributedString.Key: Any] = [
            .font: vFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.85)
        ]
        let vStr = NSAttributedString(string: row.1, attributes: vAttrs)
        let vSize = vStr.size()
        vStr.draw(at: CGPoint(x: rRect.maxX - vSize.width - 20 * scale, y: rRect.midY - (vSize.height / 2)))
    }
}

func drawThreeModes(in rect: CGRect, scale: CGFloat, ctx: CGContext) {
    let modes = [
        ("📅 QUICK ARCHIVE", "DAILY BUNDLES", "Sweeps clutter into clean dated folders (YYYY-MM-DD). Perfect for daily clean slate workflows.", NSColor(red: 1.0, green: 0.60, blue: 0.20, alpha: 1.0)),
        ("🏷️ SORT BY TYPE", "MATCHING TRIBES", "Sorts screenshots into Screenshots/, PDFs into Documents/, and videos into Media/ automatically.", NSColor(red: 1.0, green: 0.40, blue: 0.55, alpha: 1.0)),
        ("⚡ SMART CLEAN", "CUSTOM DESTINATIONS", "You decide what goes where. Keep work files separate from personal downloads with zero fuss.", NSColor(red: 1.0, green: 0.75, blue: 0.35, alpha: 1.0))
    ]

    let cardWidth = (rect.width - (30 * scale * 2)) / 3
    let cardHeight = rect.height * 0.90
    let cardY = rect.midY - (cardHeight / 2)

    for (i, m) in modes.enumerated() {
        let cardX = rect.minX + CGFloat(i) * (cardWidth + (30 * scale))
        let cardRect = CGRect(x: cardX, y: cardY, width: cardWidth, height: cardHeight)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -16 * scale), blur: 32 * scale, color: NSColor.black.withAlphaComponent(0.5).cgColor)
        let path = CGPath(roundedRect: cardRect, cornerWidth: 20 * scale, cornerHeight: 20 * scale, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(NSColor(red: 0.11, green: 0.08, blue: 0.09, alpha: 0.92).cgColor)
        ctx.fillPath()

        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        ctx.setLineWidth(2 * scale)
        ctx.setStrokeColor(m.3.withAlphaComponent(0.5).cgColor)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()

        let pad = 28 * scale

        // Title
        let tFont = NSFont.systemFont(ofSize: 22 * scale, weight: .black)
        let tAttrs: [NSAttributedString.Key: Any] = [
            .font: tFont,
            .foregroundColor: m.3,
            .kern: 1.2 * scale
        ]
        let tStr = NSAttributedString(string: m.0, attributes: tAttrs)
        tStr.draw(at: CGPoint(x: cardX + pad, y: cardY + cardHeight - pad - 26 * scale))

        // Role
        let rFont = NSFont.systemFont(ofSize: 14 * scale, weight: .bold)
        let rAttrs: [NSAttributedString.Key: Any] = [
            .font: rFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.55),
            .kern: 1.0 * scale
        ]
        let rStr = NSAttributedString(string: m.1, attributes: rAttrs)
        rStr.draw(at: CGPoint(x: cardX + pad, y: cardY + cardHeight - pad - 54 * scale))

        // Description
        let dFont = NSFont.systemFont(ofSize: 18 * scale, weight: .medium)
        let dStyle = NSMutableParagraphStyle()
        dStyle.lineSpacing = 6 * scale
        let dAttrs: [NSAttributedString.Key: Any] = [
            .font: dFont,
            .foregroundColor: NSColor(red: 0.94, green: 0.90, blue: 0.92, alpha: 0.85),
            .paragraphStyle: dStyle
        ]
        let dStr = NSAttributedString(string: m.2, attributes: dAttrs)
        dStr.draw(in: CGRect(x: cardX + pad, y: cardY + pad, width: cardWidth - (pad * 2), height: cardHeight * 0.6))
    }
}

func drawFileToggles(in rect: CGRect, scale: CGFloat, ctx: CGContext) {
    let mockWidth: CGFloat = rect.width * 0.80
    let mockHeight: CGFloat = rect.height * 0.90
    let mockRect = CGRect(x: rect.midX - (mockWidth / 2), y: rect.midY - (mockHeight / 2), width: mockWidth, height: mockHeight)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -20 * scale), blur: 40 * scale, color: NSColor.black.withAlphaComponent(0.6).cgColor)
    let path = CGPath(roundedRect: mockRect, cornerWidth: 24 * scale, cornerHeight: 24 * scale, transform: nil)
    ctx.addPath(path)
    ctx.setFillColor(NSColor(red: 0.11, green: 0.08, blue: 0.09, alpha: 0.95).cgColor)
    ctx.fillPath()
    ctx.setLineWidth(2 * scale)
    ctx.setStrokeColor(NSColor(red: 1.0, green: 0.55, blue: 0.25, alpha: 0.45).cgColor)
    ctx.addPath(path)
    ctx.strokePath()
    ctx.restoreGState()

    let toggles = [
        ("📸 Screenshots & Screen Recordings", "PNG, JPG, MOV captures cluttering desktop", true),
        ("📄 Documents & PDFs", "PDF, DOCX, TXT, CSV downloads", true),
        ("🎬 Media & Audio Files", "MP3, WAV, MP4, GIF files", true),
        ("📦 Zip & DMG Archives", "Downloaded installers & extract archives", true),
        ("📁 Loose Folders", "Leave project folders untouched on desktop", false)
    ]

    let tY = mockRect.maxY - (32 * scale)
    let tHeight = (mockHeight - (64 * scale)) / CGFloat(toggles.count)

    for (i, item) in toggles.enumerated() {
        let rowY = tY - CGFloat(i + 1) * tHeight
        let rowRect = CGRect(x: mockRect.minX + 32 * scale, y: rowY + (6 * scale), width: mockWidth - 64 * scale, height: tHeight - (12 * scale))

        ctx.saveGState()
        let rPath = CGPath(roundedRect: rowRect, cornerWidth: 14 * scale, cornerHeight: 14 * scale, transform: nil)
        ctx.addPath(rPath)
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.04).cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        // Text
        let titleFont = NSFont.systemFont(ofSize: 18 * scale, weight: .bold)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: item.2 ? NSColor(red: 1.0, green: 0.75, blue: 0.40, alpha: 1.0) : NSColor.white.withAlphaComponent(0.45)
        ]
        let titleStr = NSAttributedString(string: item.0, attributes: titleAttrs)
        titleStr.draw(at: CGPoint(x: rowRect.minX + 24 * scale, y: rowRect.midY + (4 * scale)))

        let descFont = NSFont.systemFont(ofSize: 14 * scale, weight: .medium)
        let descAttrs: [NSAttributedString.Key: Any] = [
            .font: descFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.6)
        ]
        let descStr = NSAttributedString(string: item.1, attributes: descAttrs)
        descStr.draw(at: CGPoint(x: rowRect.minX + 24 * scale, y: rowRect.midY - (20 * scale)))

        // Chunky Toggle Pill
        let pillWidth: CGFloat = 56 * scale
        let pillHeight: CGFloat = 30 * scale
        let pillRect = CGRect(x: rowRect.maxX - pillWidth - (24 * scale), y: rowRect.midY - (pillHeight / 2), width: pillWidth, height: pillHeight)

        ctx.saveGState()
        let pPath = CGPath(roundedRect: pillRect, cornerWidth: 15 * scale, cornerHeight: 15 * scale, transform: nil)
        ctx.addPath(pPath)
        ctx.setFillColor(item.2 ? NSColor(red: 1.0, green: 0.55, blue: 0.25, alpha: 1.0).cgColor : NSColor.white.withAlphaComponent(0.15).cgColor)
        ctx.fillPath()

        let knobRadius = 11 * scale
        let knobCenter = CGPoint(x: item.2 ? pillRect.maxX - (15 * scale) : pillRect.minX + (15 * scale), y: pillRect.midY)
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.addArc(center: knobCenter, radius: knobRadius, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: false)
        ctx.fillPath()
        ctx.restoreGState()
    }
}

func drawSafeArchive(in rect: CGRect, scale: CGFloat, ctx: CGContext) {
    let pillars = [
        ("🛡️ NEVER DELETED", "RackOff never trashes files. Everything is safely relocated to your local Archive folder."),
        ("📁 TIDY DATED FOLDERS", "Clips and files sit in clean YYYY-MM-DD folders so you can always find last week's downloads."),
        ("⚡ 1-CLICK DESKTOP STASH", "Open your organized Archive folder with a single click right from the menu bar."),
        ("🔒 SANDBOXED & SAFE", "Full Apple sandbox compliance with secure scoped bookmarks. Zero cloud, zero risks.")
    ]

    let boxWidth = (rect.width - (30 * scale)) / 2
    let boxHeight = (rect.height - (30 * scale)) / 2

    for (i, p) in pillars.enumerated() {
        let col = CGFloat(i % 2)
        let row = CGFloat(1 - (i / 2))

        let boxX = rect.minX + col * (boxWidth + (30 * scale))
        let boxY = rect.minY + row * (boxHeight + (30 * scale))
        let boxRect = CGRect(x: boxX, y: boxY, width: boxWidth, height: boxHeight)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -12 * scale), blur: 30 * scale, color: NSColor.black.withAlphaComponent(0.5).cgColor)
        let path = CGPath(roundedRect: boxRect, cornerWidth: 20 * scale, cornerHeight: 20 * scale, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(NSColor(red: 0.11, green: 0.08, blue: 0.09, alpha: 0.88).cgColor)
        ctx.fillPath()
        ctx.setLineWidth(1.8 * scale)
        ctx.setStrokeColor(NSColor(red: 1.0, green: 0.40, blue: 0.55, alpha: 0.40).cgColor)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()

        let pad = 36 * scale
        let titleFont = NSFont.systemFont(ofSize: 22 * scale, weight: .bold)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor(red: 1.0, green: 0.40, blue: 0.55, alpha: 1.0),
            .kern: 1.2 * scale
        ]
        let titleStr = NSAttributedString(string: p.0, attributes: titleAttrs)
        titleStr.draw(at: CGPoint(x: boxX + pad, y: boxY + boxHeight - pad - (20 * scale)))

        let descFont = NSFont.systemFont(ofSize: 20 * scale, weight: .regular)
        let descStyle = NSMutableParagraphStyle()
        descStyle.lineSpacing = 6 * scale
        let descAttrs: [NSAttributedString.Key: Any] = [
            .font: descFont,
            .foregroundColor: NSColor(red: 0.94, green: 0.90, blue: 0.92, alpha: 0.85),
            .paragraphStyle: descStyle
        ]
        let descStr = NSAttributedString(string: p.1, attributes: descAttrs)
        descStr.draw(in: CGRect(x: boxX + pad, y: boxY + pad, width: boxWidth - (pad * 2), height: boxHeight - pad - (60 * scale)))
    }
}

func drawNoSubscriptions(in rect: CGRect, scale: CGFloat, ctx: CGContext) {
    let pillars = [
        ("🔒 100% PRIVATE", "No accounts, no telemetry, no tracking. Everything runs completely locally on your Mac."),
        ("🧹 1-CLICK CLEANUP", "Instant relief from screenshot sprawl, stray PDFs, and desktop chaos in under one second."),
        ("⚙️ AUTOMATIC ARCHIVE", "Daily dated folders or type-based organization keep everything tidy without manual sorting."),
        ("💎 NO SUBSCRIPTIONS", "A single $9.99 purchase. Own it forever without monthly or annual fees.")
    ]

    let boxWidth = (rect.width - (30 * scale)) / 2
    let boxHeight = (rect.height - (30 * scale)) / 2

    for (i, p) in pillars.enumerated() {
        let col = CGFloat(i % 2)
        let row = CGFloat(1 - (i / 2))

        let boxX = rect.minX + col * (boxWidth + (30 * scale))
        let boxY = rect.minY + row * (boxHeight + (30 * scale))
        let boxRect = CGRect(x: boxX, y: boxY, width: boxWidth, height: boxHeight)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -12 * scale), blur: 30 * scale, color: NSColor.black.withAlphaComponent(0.5).cgColor)
        let path = CGPath(roundedRect: boxRect, cornerWidth: 20 * scale, cornerHeight: 20 * scale, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(NSColor(red: 0.11, green: 0.08, blue: 0.09, alpha: 0.88).cgColor)
        ctx.fillPath()
        ctx.setLineWidth(1.8 * scale)
        ctx.setStrokeColor(NSColor(red: 1.0, green: 0.60, blue: 0.20, alpha: 0.40).cgColor)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()

        let pad = 36 * scale
        let titleFont = NSFont.systemFont(ofSize: 22 * scale, weight: .bold)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor(red: 1.0, green: 0.60, blue: 0.20, alpha: 1.0),
            .kern: 1.2 * scale
        ]
        let titleStr = NSAttributedString(string: p.0, attributes: titleAttrs)
        titleStr.draw(at: CGPoint(x: boxX + pad, y: boxY + boxHeight - pad - (20 * scale)))

        let descFont = NSFont.systemFont(ofSize: 20 * scale, weight: .regular)
        let descStyle = NSMutableParagraphStyle()
        descStyle.lineSpacing = 6 * scale
        let descAttrs: [NSAttributedString.Key: Any] = [
            .font: descFont,
            .foregroundColor: NSColor(red: 0.94, green: 0.90, blue: 0.92, alpha: 0.85),
            .paragraphStyle: descStyle
        ]
        let descStr = NSAttributedString(string: p.1, attributes: descAttrs)
        descStr.draw(in: CGRect(x: boxX + pad, y: boxY + pad, width: boxWidth - (pad * 2), height: boxHeight - pad - (60 * scale)))
    }
}

// MARK: - Execution

let fileManager = FileManager.default
let outputDir = "screenshots/appstore"
try? fileManager.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

print("🎨 Rendering RackOff App Store Story Cards...")

for card in cards {
    print("📸 Rendering: \(card.filename)...")
    
    // 1. 2880x1800 (16:10 Retina)
    let img2880 = drawCard(spec: card, width: 2880, height: 1800)
    if let tiff = img2880.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiff),
       let png = bitmap.representation(using: .png, properties: [:]) {
        let path = "\(outputDir)/\(card.filename)-2880x1800.png"
        try? png.write(to: URL(fileURLWithPath: path))
        print("   ✅ Created: \(path)")
    }

    // 2. 1440x900 (16:10 Standard)
    let img1440 = drawCard(spec: card, width: 1440, height: 900)
    if let tiff = img1440.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiff),
       let png = bitmap.representation(using: .png, properties: [:]) {
        let path = "\(outputDir)/\(card.filename)-1440x900.png"
        try? png.write(to: URL(fileURLWithPath: path))
        print("   ✅ Created: \(path)")
    }
}

print("\n✨ All RackOff App Store Story Cards generated in \(outputDir)/")
