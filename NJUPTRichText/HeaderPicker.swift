import SwiftUI
import UIKit

// 标题选择器的SwiftUI视图
struct HeaderPicker: View {
    @Binding var attributedText: NSAttributedString
    @Binding var currentAttributes: RichTextFormatting.TextAttributes
    var textView: UITextView
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("标题格式")
                    .font(.headline)
                    .padding(.leading, 16)
                
                Spacer()
                
                Button(action: {
                    onDismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
                .padding(.trailing, 16)
            }
            .padding(.vertical, 10)
            .background(Color(UIColor.secondarySystemBackground))
            
            Divider()
            
            // 横向格式按钮列表
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(RichTextFormatting.HeaderStyle.allCases, id: \.self) { style in
                        Button(action: {
                            applyStyle(style)
                        }) {
                            VStack(alignment: .center) {
                                Text(style.rawValue)
                                    .font(style.font)
                            }
                            .frame(width: 70, height: 60)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(UIColor.tertiarySystemBackground))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(currentAttributes.headerStyle == style ? Color.blue : Color.clear, lineWidth: 2)
                            )
                        }
                        .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(height: 100)
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12, corners: [.topLeft, .topRight])
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: -2)
    }
    
    private func applyStyle(_ style: RichTextFormatting.HeaderStyle) {
        let range = textView.selectedRange
        
        // 如果没有选择文本，则设置当前输入状态
        if range.length == 0 {
            // 更新当前属性 - 切换标题样式（如果选中了就取消选中）
            currentAttributes.toggleHeaderStyle(style)
            
            // 更新文本视图的输入属性
            textView.typingAttributes = currentAttributes.getAttributes()
            return
        }
        
        // 如果有选择文本，则应用样式到选中文本
        let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
        
        // 检查选中的文本是否已经应用了这个样式
        let font = mutableAttrText.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont
        
        // 检查是否已经应用了样式（通过比较字体大小和粗细特性）
        var isStyleApplied = false
        if let font = font {
            let hasBoldTrait: Bool
            switch style.fontWeight {
            case .bold:
                hasBoldTrait = font.fontDescriptor.symbolicTraits.contains(.traitBold)
            case .semibold:
                // semibold比较难精确检测，这里简单检查是否包含bold特性
                hasBoldTrait = font.fontDescriptor.symbolicTraits.contains(.traitBold)
            default:
                hasBoldTrait = !font.fontDescriptor.symbolicTraits.contains(.traitBold)
            }
            
            isStyleApplied = font.pointSize == style.fontSize && hasBoldTrait
        }
        
        if isStyleApplied {
            // 如果已应用样式，则移除（恢复默认样式）
            let defaultFont = UIFont.systemFont(ofSize: 17)
            mutableAttrText.addAttribute(.font, value: defaultFont, range: range)
        } else {
            // 应用新样式
            style.apply(to: mutableAttrText, range: range)
        }
        
        attributedText = mutableAttrText
    }
} 