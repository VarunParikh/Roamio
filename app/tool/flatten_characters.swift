// Puts each character on an opaque white square, for assets/characters/ (see
// lib/features/profile/domain/characters.dart). Characters are never shipped
// with their transparent background (owner, 2026-10-31).
//
//   swift tool/flatten_characters.swift ../Images/Characters/Individual <out-dir>
//   for f in <out-dir>/*.png; do
//     cwebp -quiet -q 90 "$f" -o assets/characters/"$(basename "${f%.png}")".webp
//   done
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let travellers = (1...17).map { String(format: "traveller_%02d", $0) }
let sheetRows: [[String]] = [
  Array(travellers[0..<10]),
  [
    "astronaut", "robot", "alien", "dinosaur", "unicorn", "cool_smiley",
    "cowboy", "witch", "samurai", "ninja",
  ],
  [
    "monkey", "sloth", "owl", "bunny", "shiba", "husky", "raccoon",
    "red_panda", "lion", "giraffe",
  ],
  Array(travellers[10..<17]),
  [
    "panda", "fox", "bear", "frog", "cat", "dog", "koala", "penguin",
    "elephant", "tiger",
  ],
]

let args = CommandLine.arguments
guard args.count == 3 else {
  fatalError("usage: flatten_characters.swift <individual-dir> <out-dir>")
}
for (r, names) in sheetRows.enumerated() {
  for (c, name) in names.enumerated() {
    let file = String(format: "character_r%02d_c%02d.png", r + 1, c + 1)
    let url = URL(fileURLWithPath: args[1]).appendingPathComponent(file)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { fatalError("can't read \(file)") }
    // A little room around the character, at its own size (no resampling).
    let side = Int((Double(max(image.width, image.height)) * 1.12).rounded())
    let out = CGContext(
      data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    out.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    out.fill(CGRect(x: 0, y: 0, width: side, height: side))
    out.draw(
      image,
      in: CGRect(
        x: (side - image.width) / 2, y: (side - image.height) / 2,
        width: image.width, height: image.height))
    let target = URL(fileURLWithPath: args[2]).appendingPathComponent("\(name).png")
    let written = CGImageDestinationCreateWithURL(
      target as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(written, out.makeImage()!, nil)
    guard CGImageDestinationFinalize(written) else { fatalError("can't write \(target)") }
  }
}
