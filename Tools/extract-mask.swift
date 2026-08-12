import AppKit

// Renders a stock macOS app icon at high resolution and writes its alpha channel.
//
// Apple's icon outline is a continuous-corner rounded rectangle, not a plain rounded
// rect and not a true superellipse — fitting one numerically lands ~20% off on the
// corner, which reads as "too square" next to real icons. Taking the system's own
// shape is exact and stays correct if Apple revises it.

let candidates = [
    "/System/Applications/Music.app",
    "/System/Applications/App Store.app",
    "/System/Applications/Mail.app",
]

guard let source = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
    FileHandle.standardError.write(Data("no stock icon found to sample\n".utf8))
    exit(1)
}

let side = 4096   // oversampled, so downsampling gives a clean antialiased edge
let icon = NSWorkspace.shared.icon(forFile: source)
let image = NSImage(size: NSSize(width: side, height: side))
image.lockFocus()
icon.draw(in: NSRect(x: 0, y: 0, width: side, height: side), from: .zero, operation: .copy, fraction: 1)
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("could not rasterise\n".utf8))
    exit(1)
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "mask-source.png"
try png.write(to: URL(fileURLWithPath: out))
print("sampled \(source) at \(side)px -> \(out)")
