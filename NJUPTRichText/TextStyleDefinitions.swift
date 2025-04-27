import UIKit
import SwiftUI

// 文本样式命名空间
struct RichTextFormatting {
    // 标题样式枚举
    enum HeaderStyle: String, CaseIterable {
        case h1 = "H1"
        case h2 = "H2"
        case h3 = "H3"
        case h4 = "H4"
        case h5 = "H5"
        case h6 = "H6"
        
        var fontSize: CGFloat {
            switch self {
            case .h1: return 32
            case .h2: return 28
            case .h3: return 24
            case .h4: return 20
            case .h5: return 18
            case .h6: return 16
            }
        }
        
        var fontWeight: UIFont.Weight {
            switch self {
            case .h1, .h2: return .bold
            case .h3, .h4: return .semibold
            case .h5, .h6: return .medium
            }
        }
        
        var description: String {
            switch self {
            case .h1: return "标题1"
            case .h2: return "标题2"
            case .h3: return "标题3"
            case .h4: return "标题4"
            case .h5: return "标题5"
            case .h6: return "标题6"
            }
        }
        
        var font: Font {
            switch self {
            case .h1: return .system(size: fontSize, weight: .bold)
            case .h2: return .system(size: fontSize, weight: .bold)
            case .h3: return .system(size: fontSize, weight: .semibold)
            case .h4: return .system(size: fontSize, weight: .semibold)
            case .h5: return .system(size: fontSize, weight: .medium)
            case .h6: return .system(size: fontSize, weight: .medium)
            }
        }
        
        // 应用样式到AttributedString
        func apply(to attributedText: NSMutableAttributedString, range: NSRange) {
            attributedText.addAttributes(getAttributes(), range: range)
        }
        
        // 获取标题样式对应的文本属性
        func getAttributes() -> [NSAttributedString.Key: Any] {
            return [
                .font: UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
            ]
        }
    }
    
    // BIUS样式枚举
    enum FormatStyle: String, CaseIterable {
        case bold = "B"
        case italic = "I"
        case underline = "U"
        case strikethrough = "S"
        
        var icon: String {
            switch self {
            case .bold: return "bold"
            case .italic: return "italic"
            case .underline: return "underline"
            case .strikethrough: return "strikethrough"
            }
        }
        
        var description: String {
            switch self {
            case .bold: return "粗体"
            case .italic: return "斜体"
            case .underline: return "下划线"
            case .strikethrough: return "删除线"
            }
        }
        
        // 应用样式到AttributedString
        func apply(to attributedText: NSMutableAttributedString, range: NSRange) {
            switch self {
            case .bold:
                let font = attributedText.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont ?? UIFont.systemFont(ofSize: 17)
                let newFont = UIFont(descriptor: font.fontDescriptor.withSymbolicTraits(.traitBold)!, size: font.pointSize)
                attributedText.addAttribute(.font, value: newFont, range: range)
                
            case .italic:
                let font = attributedText.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont ?? UIFont.systemFont(ofSize: 17)
                let newFont = UIFont(descriptor: font.fontDescriptor.withSymbolicTraits(.traitItalic)!, size: font.pointSize)
                attributedText.addAttribute(.font, value: newFont, range: range)
                
            case .underline:
                attributedText.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                
            case .strikethrough:
                attributedText.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
        }
        
        // 获取格式样式对应的文本属性
        func getAttributes(baseFont: UIFont = UIFont.systemFont(ofSize: 17)) -> [NSAttributedString.Key: Any] {
            switch self {
            case .bold:
                let newFont = UIFont(descriptor: baseFont.fontDescriptor.withSymbolicTraits(.traitBold)!, size: baseFont.pointSize)
                return [.font: newFont]
                
            case .italic:
                let newFont = UIFont(descriptor: baseFont.fontDescriptor.withSymbolicTraits(.traitItalic)!, size: baseFont.pointSize)
                return [.font: newFont]
                
            case .underline:
                return [.underlineStyle: NSUnderlineStyle.single.rawValue]
                
            case .strikethrough:
                return [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
            }
        }
    }
    
    // 用于存储和应用组合格式
    struct TextAttributes {
        var headerStyle: HeaderStyle?
        var formatStyles: Set<FormatStyle> = []
        var isBlockquote: Bool = false
        
        // 切换标题样式（如果已选中则取消选中）
        mutating func toggleHeaderStyle(_ style: HeaderStyle) {
            if headerStyle == style {
                headerStyle = nil
            } else {
                headerStyle = style
            }
        }
        
        // 切换引用块样式
        mutating func toggleBlockquote() {
            isBlockquote = !isBlockquote
        }
        
        // 获取引用块样式
        func getBlockquoteAttributes() -> [NSAttributedString.Key: Any] {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.headIndent = 20
            paragraphStyle.firstLineHeadIndent = 0
            paragraphStyle.tailIndent = -20
            paragraphStyle.paragraphSpacing = 10
            paragraphStyle.paragraphSpacingBefore = 10
            
            return [
                .paragraphStyle: paragraphStyle,
                .foregroundColor: UIColor.darkGray,
                .backgroundColor: UIColor.systemGray6
            ]
        }
        
        // 获取当前组合的属性字典
        func getAttributes() -> [NSAttributedString.Key: Any] {
            var attributes: [NSAttributedString.Key: Any] = [:]
            
            // 首先应用引用块样式（如果启用）
            if isBlockquote {
                attributes.merge(getBlockquoteAttributes()) { (current, _) in current }
            }
            
            // 应用标题样式作为基础字体
            if let headerStyle = headerStyle {
                attributes.merge(headerStyle.getAttributes()) { (current, _) in current }
            }
            
            // 获取当前的基础字体
            let baseFont = attributes[.font] as? UIFont ?? UIFont.systemFont(ofSize: 17)
            
            // 应用格式样式
            for style in formatStyles {
                switch style {
                case .bold, .italic:
                    // 对于粗体和斜体，需要考虑现有字体
                    var fontDescriptor = baseFont.fontDescriptor
                    if style == .bold {
                        fontDescriptor = fontDescriptor.withSymbolicTraits(.traitBold)!
                    }
                    if style == .italic {
                        fontDescriptor = fontDescriptor.withSymbolicTraits(.traitItalic)!
                    }
                    attributes[.font] = UIFont(descriptor: fontDescriptor, size: baseFont.pointSize)
                    
                case .underline:
                    attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
                    
                case .strikethrough:
                    attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                }
            }
            
            return attributes
        }
    }
} 