import UIKit
import zlib

// MARK: - ExportService

enum ExportService {

    // MARK: - Public API

    /// Plain .txt file — always available.
    static func textURL(for message: Message) throws -> URL {
        let url = tempURL(name: fileName(message), ext: "txt")
        try textBody(for: message).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Formatted .pdf — always available.
    static func pdfURL(for message: Message) throws -> URL {
        let url = tempURL(name: fileName(message), ext: "pdf")
        try makePDF(for: message).write(to: url)
        return url
    }

    /// Returns the stored video file URL — nil when no video attached.
    static func videoURL(for message: Message) -> URL? {
        guard let fn = message.videoFileName else { return nil }
        return StorageService.shared.videoURL(for: fn)
    }

    /// ZIP containing text + video (if present). Dependency-free.
    static func zipURL(for message: Message) throws -> URL {
        let name = fileName(message)
        let url  = tempURL(name: name, ext: "zip")

        var entries: [(String, Data)] = []

        if let d = textBody(for: message).data(using: .utf8) {
            entries.append((name + ".txt", d))
        }
        if let vidURL = videoURL(for: message),
           let d = try? Data(contentsOf: vidURL) {
            entries.append((name + ".mov", d))
        }

        try ZipWriter.archive(entries).write(to: url)
        return url
    }

    // MARK: - Text body

    private static func textBody(for message: Message) -> String {
        var lines: [String] = []
        if let title = message.title {
            lines += [title, String(repeating: "─", count: 44), ""]
        }
        lines += [message.content, ""]
        lines += [String(repeating: "─", count: 44)]
        lines += ["Written:  \(message.createdDate.formatted(date: .long, time: .shortened))"]
        lines += ["Unlocked: \(message.formattedUnlockDate)"]
        if let note = message.reflectNote, !note.isEmpty {
            lines += ["", "My reflection:", note]
        }
        lines += ["", "Future Message"]
        return lines.joined(separator: "\n")
    }

    // MARK: - PDF

    private static func makePDF(for message: Message) -> Data {
        let page    = CGRect(x: 0, y: 0, width: 612, height: 792)   // US Letter
        let margin: CGFloat = 64
        let cw      = page.width - margin * 2

        return UIGraphicsPDFRenderer(bounds: page).pdfData { ctx in
            ctx.beginPage()
            var y = margin

            // ── Title ──────────────────────────────────────────────────────
            if let title = message.title {
                let a: [NSAttributedString.Key: Any] = [
                    .font:            UIFont(name: "Georgia", size: 26) ?? .boldSystemFont(ofSize: 26),
                    .foregroundColor: UIColor.black
                ]
                let s = NSAttributedString(string: title, attributes: a)
                s.draw(at: CGPoint(x: margin, y: y))
                y += ceil(s.size().height) + 8
            }

            // ── Date ───────────────────────────────────────────────────────
            let dateA: [NSAttributedString.Key: Any] = [
                .font:            UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.gray
            ]
            let dateS = NSAttributedString(
                string: "Written \(message.timeAgoString)  ·  Opens \(message.formattedUnlockDate)",
                attributes: dateA
            )
            dateS.draw(at: CGPoint(x: margin, y: y))
            y += ceil(dateS.size().height) + 18

            // ── Rule ───────────────────────────────────────────────────────
            let rule = UIBezierPath()
            rule.move(to: CGPoint(x: margin, y: y))
            rule.addLine(to: CGPoint(x: page.width - margin, y: y))
            UIColor.lightGray.withAlphaComponent(0.5).setStroke()
            rule.lineWidth = 0.5
            rule.stroke()
            y += 22

            // ── Body ───────────────────────────────────────────────────────
            let ps = NSMutableParagraphStyle()
            ps.lineSpacing = 7
            let bodyA: [NSAttributedString.Key: Any] = [
                .font:            UIFont(name: "Georgia", size: 16) ?? .systemFont(ofSize: 16),
                .foregroundColor: UIColor.black,
                .paragraphStyle:  ps
            ]
            let bodyS   = NSAttributedString(string: message.content, attributes: bodyA)
            let bodyH   = page.height - y - margin - 36
            bodyS.draw(in: CGRect(x: margin, y: y, width: cw, height: bodyH))

            // ── Reflection ────────────────────────────────────────────────
            if let note = message.reflectNote, !note.isEmpty {
                // Place reflection near bottom above footer
                let reflY = page.height - margin - 36 - 80
                let reflA: [NSAttributedString.Key: Any] = [
                    .font:            UIFont(name: "Georgia-Italic", size: 13) ?? .italicSystemFont(ofSize: 13),
                    .foregroundColor: UIColor.darkGray
                ]
                let reflS = NSAttributedString(string: "Reflection: \(note)", attributes: reflA)
                reflS.draw(in: CGRect(x: margin, y: reflY, width: cw, height: 80))
            }

            // ── Footer ─────────────────────────────────────────────────────
            let footA: [NSAttributedString.Key: Any] = [
                .font:            UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.lightGray
            ]
            let footS = NSAttributedString(string: "Future Message", attributes: footA)
            let fw    = footS.size().width
            footS.draw(at: CGPoint(x: page.midX - fw / 2, y: page.height - margin + 18))
        }
    }

    // MARK: - Helpers

    private static func fileName(_ message: Message) -> String {
        let raw = message.title ?? "message"
        let safe = raw
            .components(separatedBy: CharacterSet.alphanumerics.union(.init(charactersIn: "-_ ")).inverted)
            .joined()
            .trimmingCharacters(in: .whitespaces)
        return safe.isEmpty ? "message" : safe
    }

    private static func tempURL(name: String, ext: String) -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fm_exports", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(name)_\(Int(Date().timeIntervalSince1970)).\(ext)")
    }
}

// MARK: - Minimal dependency-free ZIP writer (store / no compression)
// Produces valid ZIP 2.0 archives readable by all standard tools.

private enum ZipWriter {

    static func archive(_ entries: [(String, Data)]) -> Data {
        var local  = Data()
        var central = Data()

        for (name, data) in entries {
            let offset  = UInt32(local.count)
            let nameD   = Data(name.utf8)
            let crc     = crc32(data)
            let size    = UInt32(data.count)

            local.append(localHeader(name: nameD, crc: crc, size: size))
            local.append(data)
            central.append(centralEntry(name: nameD, crc: crc, size: size, offset: offset))
        }

        let cdOffset = UInt32(local.count)
        let cdSize   = UInt32(central.count)
        var result   = local
        result.append(central)
        result.append(endRecord(count: UInt16(entries.count), cdSize: cdSize, cdOffset: cdOffset))
        return result
    }

    // Local file header (method = 0 → store)
    private static func localHeader(name: Data, crc: UInt32, size: UInt32) -> Data {
        var d = Data()
        d.le(UInt32(0x04034b50))   // signature
        d.le(UInt16(20))            // version needed
        d.le(UInt16(0))             // flags
        d.le(UInt16(0))             // compression: store
        d.le(UInt16(0))             // mod time
        d.le(UInt16(0))             // mod date
        d.le(crc)
        d.le(size)                  // compressed size
        d.le(size)                  // uncompressed size
        d.le(UInt16(name.count))
        d.le(UInt16(0))             // extra length
        d.append(name)
        return d
    }

    // Central directory entry
    private static func centralEntry(name: Data, crc: UInt32, size: UInt32, offset: UInt32) -> Data {
        var d = Data()
        d.le(UInt32(0x02014b50))
        d.le(UInt16(20))            // version made by
        d.le(UInt16(20))            // version needed
        d.le(UInt16(0))             // flags
        d.le(UInt16(0))             // compression: store
        d.le(UInt16(0))             // mod time
        d.le(UInt16(0))             // mod date
        d.le(crc)
        d.le(size)
        d.le(size)
        d.le(UInt16(name.count))
        d.le(UInt16(0))             // extra
        d.le(UInt16(0))             // comment
        d.le(UInt16(0))             // disk number
        d.le(UInt16(0))             // internal attr
        d.le(UInt32(0))             // external attr
        d.le(offset)
        d.append(name)
        return d
    }

    // End of central directory record
    private static func endRecord(count: UInt16, cdSize: UInt32, cdOffset: UInt32) -> Data {
        var d = Data()
        d.le(UInt32(0x06054b50))
        d.le(UInt16(0))             // disk
        d.le(UInt16(0))             // disk with cd
        d.le(count)
        d.le(count)
        d.le(cdSize)
        d.le(cdOffset)
        d.le(UInt16(0))             // comment length
        return d
    }

    // CRC-32 via system zlib (always available on iOS/macOS)
    private static func crc32(_ data: Data) -> UInt32 {
        data.withUnsafeBytes { ptr in
            UInt32(zlib.crc32(0, ptr.baseAddress?.assumingMemoryBound(to: Bytef.self), uInt(data.count)))
        }
    }
}

// MARK: - Export errors

enum ExportError: LocalizedError {
    case noVideo

    var errorDescription: String? {
        switch self {
        case .noVideo: return "This message has no video attached."
        }
    }
}

// Little-endian append helper
private extension Data {
    mutating func le<T: FixedWidthInteger>(_ v: T) {
        var x = v.littleEndian
        append(contentsOf: Swift.withUnsafeBytes(of: &x, Array.init))
    }
}
