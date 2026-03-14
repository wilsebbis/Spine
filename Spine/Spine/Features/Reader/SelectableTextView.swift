import SwiftUI
import UIKit

// MARK: - Selectable Text View
// A UITextView-based component that provides native iOS text selection
// with blue cursors and drag handles. Supports custom menu actions
// for Highlight, Share Quote, Explain, and Define Word.
// Renders existing highlights with colored backgrounds and supports
// tapping on highlights to edit them.

struct SelectableTextView: UIViewRepresentable {
    let text: String
    let font: UIFont
    let textColor: UIColor
    let lineSpacing: CGFloat
    
    /// Existing highlights to render with colored background
    var highlights: [HighlightRange] = []
    
    /// Callbacks for custom menu actions
    var onHighlight: ((String) -> Void)?
    var onShareQuote: ((String) -> Void)?
    var onExplain: ((String) -> Void)?
    var onDefineWord: ((String) -> Void)?
    
    /// Callback when user taps an existing highlight
    var onTapHighlight: ((UUID) -> Void)?
    
    /// Lightweight struct to avoid passing SwiftData models into UIKit
    struct HighlightRange: Equatable {
        let id: UUID
        let selectedText: String
        let colorHex: String
    }
    
    func makeUIView(context: Context) -> SpineTextView {
        let textView = SpineTextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.dataDetectorTypes = []
        textView.delegate = context.coordinator
        
        // Disable link interactions that cause gesture conflicts
        textView.isUserInteractionEnabled = true
        textView.textContainer.maximumNumberOfLines = 0
        textView.textContainer.lineBreakMode = .byWordWrapping
        
        // Store callbacks
        textView.onHighlight = onHighlight
        textView.onShareQuote = onShareQuote
        textView.onExplain = onExplain
        textView.onDefineWord = onDefineWord
        textView.onTapHighlight = onTapHighlight
        
        // Tap gesture for highlight-tap detection only
        // Requires that no text is currently selected (via gestureRecognizerShouldBegin).
        // Does NOT fire simultaneously with selection gestures to avoid gate timeouts.
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.cancelsTouchesInView = false
        tapGesture.delaysTouchesBegan = false
        tapGesture.delaysTouchesEnded = false
        tapGesture.delegate = context.coordinator
        
        // Require built-in long-press (selection) gestures to fail first
        for gesture in textView.gestureRecognizers ?? [] {
            if gesture is UILongPressGestureRecognizer {
                tapGesture.require(toFail: gesture)
            }
        }
        
        textView.addGestureRecognizer(tapGesture)
        
        configureText(textView)
        return textView
    }
    
    func updateUIView(_ textView: SpineTextView, context: Context) {
        textView.onHighlight = onHighlight
        textView.onShareQuote = onShareQuote
        textView.onExplain = onExplain
        textView.onDefineWord = onDefineWord
        textView.onTapHighlight = onTapHighlight
        textView.highlightRanges = highlights
        
        // Only rebuild attributed string when content actually changed
        let isDirty = textView.lastConfiguredText != text
            || textView.lastConfiguredHighlights != highlights
        if isDirty {
            configureText(textView)
        }
    }
    
    private func configureText(_ textView: SpineTextView) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle,
        ]
        
        // Strip variant selectors and other invisible Unicode that causes
        // "variant selector cell index number could not be found" warnings
        let cleanText = text.unicodeScalars.filter { scalar in
            // Remove variant selectors (U+FE00–U+FE0F, U+E0100–U+E01EF)
            !(0xFE00...0xFE0F).contains(scalar.value) &&
            !(0xE0100...0xE01EF).contains(scalar.value)
        }
        let sanitized = String(cleanText)
        
        let attrString = NSMutableAttributedString(string: sanitized, attributes: attributes)
        
        // Apply highlight backgrounds
        for hl in highlights {
            if let range = sanitized.range(of: hl.selectedText) {
                let nsRange = NSRange(range, in: sanitized)
                let bgColor = UIColor(hex: hl.colorHex)?.withAlphaComponent(0.35) ?? UIColor.yellow.withAlphaComponent(0.35)
                attrString.addAttribute(.backgroundColor, value: bgColor, range: nsRange)
            }
        }
        
        textView.attributedText = attrString
        textView.highlightRanges = highlights
        
        // Track what we configured to avoid redundant rebuilds
        textView.lastConfiguredText = text
        textView.lastConfiguredHighlights = highlights
        
        textView.invalidateIntrinsicContentSize()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
            guard let spineTextView = textView as? SpineTextView else {
                return UIMenu(children: suggestedActions)
            }
            
            let selRange = textView.selectedRange
            guard selRange.length > 0 else {
                return UIMenu(children: suggestedActions)
            }
            
            // Use attributedText.string — more reliable than textView.text for
            // selections starting at position 0 with attributed content
            let fullText = textView.attributedText.string
            guard let swiftRange = Range(selRange, in: fullText) else {
                return UIMenu(children: suggestedActions)
            }
            
            let selectedText = String(fullText[swiftRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !selectedText.isEmpty else {
                return UIMenu(children: suggestedActions)
            }
            
            var customActions: [UIMenuElement] = []
            
            // Capture text NOW — UIKit may clear the selection before firing actions
            let capturedText = selectedText
            
            // Highlight action
            if let onHighlight = spineTextView.onHighlight {
                let highlightAction = UIAction(
                    title: "Highlight",
                    image: UIImage(systemName: "highlighter")
                ) { _ in
                    onHighlight(capturedText)
                }
                customActions.append(highlightAction)
            }
            
            // Share Quote action
            if let onShareQuote = spineTextView.onShareQuote {
                let shareAction = UIAction(
                    title: "Share Quote",
                    image: UIImage(systemName: "square.and.arrow.up")
                ) { _ in
                    onShareQuote(capturedText)
                }
                customActions.append(shareAction)
            }
            
            // Explain action (combines Explain + Define)
            if let onExplain = spineTextView.onExplain {
                let explainAction = UIAction(
                    title: "Explain",
                    image: UIImage(systemName: "lightbulb")
                ) { _ in
                    onExplain(capturedText)
                }
                customActions.append(explainAction)
            }
            
            let spineMenu = UIMenu(title: "", options: .displayInline, children: customActions)
            return UIMenu(children: [spineMenu] + suggestedActions)
        }
        
        // MARK: - UIGestureRecognizerDelegate
        
        /// Allow our tap gesture to work simultaneously with most gestures,
        /// but NOT with long-press (selection) gestures to avoid gate timeouts.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // Don't compete with selection gestures
            if otherGestureRecognizer is UILongPressGestureRecognizer {
                return false
            }
            return true
        }
        
        /// Only recognize our tap when no text is currently selected.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let textView = gestureRecognizer.view as? SpineTextView else { return false }
            // Only allow our tap for highlight-tap detection when no selection is active
            return textView.selectedRange.length == 0
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let textView = gesture.view as? SpineTextView,
                  let onTapHighlight = textView.onTapHighlight,
                  !textView.highlightRanges.isEmpty else { return }
            
            let point = gesture.location(in: textView)
            
            // Use closestPosition API — works with both TextKit 1 and 2,
            // avoids forcing TextKit 1 compatibility mode
            let offset = textView.textContainerInset
            let adjustedPoint = CGPoint(x: point.x - offset.left, y: point.y - offset.top)
            
            guard let position = textView.closestPosition(to: adjustedPoint) else { return }
            let charIndex = textView.offset(from: textView.beginningOfDocument, to: position)
            
            let text = textView.attributedText.string
            
            // Check if the tapped character falls within any highlight range
            for hl in textView.highlightRanges {
                if let range = text.range(of: hl.selectedText) {
                    let nsRange = NSRange(range, in: text)
                    if charIndex >= nsRange.location && charIndex < nsRange.location + nsRange.length {
                        onTapHighlight(hl.id)
                        return
                    }
                }
            }
        }
        
        private func getSelectedText(from textView: UITextView) -> String? {
            let selRange = textView.selectedRange
            guard selRange.length > 0 else { return nil }
            let fullText = textView.attributedText.string
            guard let swiftRange = Range(selRange, in: fullText) else {
                return nil
            }
            let selected = String(fullText[swiftRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return selected.isEmpty ? nil : selected
        }
    }
}

// MARK: - SpineTextView
// Custom UITextView subclass that stores action callbacks and
// auto-sizes to fit content.

class SpineTextView: UITextView {
    var onHighlight: ((String) -> Void)?
    var onShareQuote: ((String) -> Void)?
    var onExplain: ((String) -> Void)?
    var onDefineWord: ((String) -> Void)?
    var onTapHighlight: ((UUID) -> Void)?
    var highlightRanges: [SelectableTextView.HighlightRange] = []
    
    // Dirty tracking — skip redundant configureText calls
    var lastConfiguredText: String?
    var lastConfiguredHighlights: [SelectableTextView.HighlightRange]?
    
    // Cache the last computed height to avoid redundant sizeThatFits
    private var cachedHeight: CGFloat?
    
    override var intrinsicContentSize: CGSize {
        if let cached = cachedHeight {
            return CGSize(width: UIView.noIntrinsicMetric, height: cached)
        }
        let screenWidth: CGFloat
        if bounds.width > 0 {
            screenWidth = bounds.width
        } else if let screen = window?.windowScene?.screen {
            screenWidth = screen.bounds.width - 48
        } else {
            screenWidth = 375 - 48
        }
        let size = sizeThatFits(CGSize(width: screenWidth, height: .greatestFiniteMagnitude))
        cachedHeight = size.height
        return CGSize(width: UIView.noIntrinsicMetric, height: size.height)
    }
    
    override func invalidateIntrinsicContentSize() {
        cachedHeight = nil
        super.invalidateIntrinsicContentSize()
    }
    
    // REMOVED: layoutSubviews no longer calls invalidateIntrinsicContentSize.
    // That was creating an infinite layout loop:
    //   layoutSubviews → invalidate → setNeedsLayout → layoutSubviews → ...
    // Size is now only invalidated when configureText sets new content.
}

// MARK: - UIColor Hex Initializer

extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        guard hexSanitized.count == 6 else { return nil }
        var rgbValue: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgbValue)
        
        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}
