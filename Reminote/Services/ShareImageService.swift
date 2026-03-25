import UIKit

struct ShareImageService {

    static func generate(for message: Message) -> UIImage {
        let size = CGSize(width: 1080, height: 1080)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            drawBackground(size: size)
            drawDivider(y: 130, width: size.width, padding: 80)
            drawHeader(message: message, size: size, padding: 80)
            drawQuoteMark(size: size, padding: 80)
            drawContent(message: message, size: size, padding: 80)
            drawDivider(y: 820, width: size.width, padding: 80)
            drawFooter(size: size, padding: 80)
            drawWatermark(size: size, padding: 80)
        }
    }

    // MARK: - Drawing helpers

    private static func drawBackground(size: CGSize) {
        UIColor.black.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))

        // Subtle grain texture
        for i in stride(from: 0, to: Int(size.height), by: 4) {
            UIColor.white.withAlphaComponent(0.015).setFill()
            UIRectFill(CGRect(x: 0, y: CGFloat(i), width: size.width, height: 1))
        }
    }

    private static func drawDivider(y: CGFloat, width: CGFloat, padding: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: padding, y: y))
        path.addLine(to: CGPoint(x: width - padding, y: y))
        path.lineWidth = 0.5
        UIColor.white.withAlphaComponent(0.25).setStroke()
        path.stroke()
    }

    private static func drawHeader(message: Message, size: CGSize, padding: CGFloat) {
        let style = centered()
        let text = "I wrote this \(message.timeAgoString)…"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: georgia(size: 22, italic: true),
            .foregroundColor: UIColor.white.withAlphaComponent(0.55),
            .paragraphStyle: style
        ]
        text.draw(in: CGRect(x: padding, y: 150, width: size.width - padding * 2, height: 60), withAttributes: attrs)
    }

    private static func drawQuoteMark(size: CGSize, padding: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: georgia(size: 100, italic: false),
            .foregroundColor: UIColor.white.withAlphaComponent(0.08),
            .paragraphStyle: centered()
        ]
        "\u{201C}".draw(in: CGRect(x: padding, y: 200, width: size.width - padding * 2, height: 120), withAttributes: attrs)
    }

    private static func drawContent(message: Message, size: CGSize, padding: CGFloat) {
        let snippet: String
        if message.content.count > 160 {
            snippet = String(message.content.prefix(160)).trimmingCharacters(in: .whitespaces) + "…"
        } else {
            snippet = message.content
        }

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = 10

        let attrs: [NSAttributedString.Key: Any] = [
            .font: georgia(size: 32, italic: false),
            .foregroundColor: UIColor.white,
            .paragraphStyle: style,
            .kern: 0.3
        ]

        snippet.draw(in: CGRect(x: padding, y: 310, width: size.width - padding * 2, height: 470), withAttributes: attrs)
    }

    private static func drawFooter(size: CGSize, padding: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: georgia(size: 20, italic: true),
            .foregroundColor: UIColor.white.withAlphaComponent(0.55),
            .paragraphStyle: centered()
        ]
        "And today I read it.".draw(
            in: CGRect(x: padding, y: 840, width: size.width - padding * 2, height: 50),
            withAttributes: attrs
        )
    }

    private static func drawWatermark(size: CGSize, padding: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .ultraLight),
            .foregroundColor: UIColor.white.withAlphaComponent(0.2),
            .paragraphStyle: centered()
        ]
        "Future Message".draw(
            in: CGRect(x: padding, y: 960, width: size.width - padding * 2, height: 30),
            withAttributes: attrs
        )
    }

    // MARK: - Utilities

    private static func georgia(size: CGFloat, italic: Bool) -> UIFont {
        let name = italic ? "Georgia-Italic" : "Georgia"
        return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size, weight: .light)
    }

    private static func centered() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        return style
    }
}
