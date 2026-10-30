// Writes colourful JPEGs with EXIF capture dates, two per month going back from today:
// a small photo, and a big one captured a minute earlier, so a size sort has something to move.
// Older months get smaller big photos, yet every big photo stays far bigger than every small one.
// Usage: swift scripts/make-seed-photos.swift <output-dir> <months>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count == 3, let count = Int(arguments[2]), count > 0 else {
    FileHandle.standardError.write(Data("usage: make-seed-photos.swift <output-dir> <months>\n".utf8))
    exit(64)
}
let outputDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let width = 1200
let height = 1600
/// Rows of noise in the big photo of the newest and of the oldest month. Noise survives JPEG compression,
/// so the file size follows the band height.
let (newestBand, oldestBand) = (1400, 300)
let exifFormatter = DateFormatter()
exifFormatter.locale = Locale(identifier: "en_US_POSIX")
exifFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
let stamp = Int(Date().timeIntervalSince1970)

func write(_ context: CGContext, to url: URL, captured: Date) {
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
    else { exit(1) }
    let properties: [CFString: Any] = [
        kCGImageDestinationLossyCompressionQuality: 0.85,
        kCGImagePropertyExifDictionary: [
            kCGImagePropertyExifDateTimeOriginal: exifFormatter.string(from: captured),
            kCGImagePropertyExifDateTimeDigitized: exifFormatter.string(from: captured),
        ],
    ]
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { exit(1) }
    print(url.path)
}

/// Overwrites the top `rows` rows with noise from a fixed-seed LCG, so every run writes the same files.
func fillNoise(_ context: CGContext, rows: Int, seed: Int) {
    guard let data = context.data else { exit(1) }
    let words = context.bytesPerRow * rows / MemoryLayout<UInt64>.size
    let pixels = data.bindMemory(to: UInt64.self, capacity: words)
    var state = UInt64(seed + 1) &* 0x9E37_79B9_7F4A_7C15
    for word in 0..<words {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        pixels[word] = state ^ (state >> 32)
    }
}

for index in 0..<count {
    guard let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { exit(1) }

    let hue = Double(index) / Double(count)
    func color(_ shift: Double, _ brightness: Double) -> CGColor {
        let h = (hue + shift).truncatingRemainder(dividingBy: 1) * 6
        let x = 1 - abs(h.truncatingRemainder(dividingBy: 2) - 1)
        let (r, g, b): (Double, Double, Double) = switch Int(h) {
        case 0: (1, x, 0)
        case 1: (x, 1, 0)
        case 2: (0, 1, x)
        case 3: (0, x, 1)
        case 4: (x, 0, 1)
        default: (1, 0, x)
        }
        return CGColor(srgbRed: r * brightness, green: g * brightness, blue: b * brightness, alpha: 1)
    }

    let gradient = CGGradient(colorsSpace: nil, colors: [color(0, 0.95), color(0.15, 0.55)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: width, y: height), options: [])
    for ring in 0..<6 {
        context.setFillColor(color(0.5 + Double(ring) * 0.05, 1).copy(alpha: 0.35)!)
        let size = CGFloat(220 + ring * 90)
        let center = CGPoint(x: CGFloat(200 + (index * 97 + ring * 151) % 800), y: CGFloat(300 + (index * 211 + ring * 173) % 1000))
        context.fillEllipse(in: CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size))
    }

    let captured = Calendar.current.date(byAdding: .month, value: -index, to: Date())!
    write(context, to: outputDirectory.appendingPathComponent("seed-\(stamp)-\(index).jpg"), captured: captured)

    let band = count == 1 ? newestBand : newestBand - (newestBand - oldestBand) * index / (count - 1)
    fillNoise(context, rows: band, seed: index)
    write(context, to: outputDirectory.appendingPathComponent("seed-\(stamp)-\(index)-big.jpg"), captured: captured.addingTimeInterval(-60))
}
