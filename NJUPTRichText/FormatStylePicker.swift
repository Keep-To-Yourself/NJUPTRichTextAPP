import SwiftUI
import UIKit

// BIUS样式选择器的SwiftUI视图
struct FormatStylePicker: View {
    @Binding var attributedText: NSAttributedString
    @Binding var currentAttributes: RichTextFormatting.TextAttributes
    var textView: UITextView
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("文本格式")
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
            HStack(spacing: 20) {
                ForEach(RichTextFormatting.FormatStyle.allCases, id: \.self) { style in
                    Button(action: {
                        applyStyle(style)
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: style.icon)
                                .font(.system(size: 24))
                            
                            Text(style.description)
                                .font(.caption)
                        }
                        .frame(width: 60, height: 60)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(currentAttributes.formatStyles.contains(style) ? Color.blue : Color.clear, lineWidth: 2)
                        )
                    }
                    .foregroundColor(.primary)
                }
            }
            .padding(.vertical, 15)
            .padding(.horizontal, 16)
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12, corners: [.topLeft, .topRight])
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: -2)
    }
    
    private func applyStyle(_ style: RichTextFormatting.FormatStyle) {
        let range = textView.selectedRange
        
        // 如果没有选择文本，则设置当前输入状态
        if range.length == 0 {
            // 切换当前格式状态
            if currentAttributes.formatStyles.contains(style) {
                currentAttributes.formatStyles.remove(style)
            } else {
                currentAttributes.formatStyles.insert(style)
            }
            
            // 更新文本视图的输入属性
            textView.typingAttributes = currentAttributes.getAttributes()
            return
        }
        
        // 如果有选择文本，则应用样式到选中文本
        let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
        
        // 应用样式
        style.apply(to: mutableAttrText, range: range)
        attributedText = mutableAttrText
        
        // 完成后关闭
        onDismiss()
    }
} 