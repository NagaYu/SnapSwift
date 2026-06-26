import CoreGraphics
import Foundation
import ImageIO

/// Decodes image files into `CGImage`s, independent of any analysis backend.
public enum ImageLoader {
    /// Decode a `CGImage` from a file URL (PNG, JPEG, HEIC, TIFF, …).
    public static func load(at url: URL) throws -> CGImage {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SnapSwiftError.imageNotFound(path: url.path)
        }
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw SnapSwiftError.imageDecodingFailed(path: url.path)
        }
        return image
    }
}
