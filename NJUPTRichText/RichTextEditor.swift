import SwiftUI
import UIKit

struct RichTextEditor: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    var isEditable: Bool
    // 当前输入的文本属性
    @Binding var currentAttributes: RichTextFormatting.TextAttributes
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isEditable = isEditable
        textView.font = .systemFont(ofSize: 16)
        textView.backgroundColor = .clear
        
        // 设置初始输入属性
        textView.typingAttributes = currentAttributes.getAttributes()
        
        // 设置自动滚动以保持光标可见
        textView.scrollRangeToVisible(textView.selectedRange)
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // 保存当前光标位置
        let currentRange = uiView.selectedRange
        
        uiView.attributedText = attributedText
        uiView.isEditable = isEditable
        
        // 更新当前输入属性
        uiView.typingAttributes = currentAttributes.getAttributes()
        
        // 恢复保存的光标位置
        if currentRange.location <= attributedText.length {
            uiView.selectedRange = currentRange
        }
        
        // 确保光标位置可见
        uiView.scrollRangeToVisible(uiView.selectedRange)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        var lastTextLength: Int = 0
        var lastSelectedRange: NSRange?
        // 用于跟踪自定义光标位置的标志
        var shouldMaintainCustomCursor: Bool = false
        var customCursorPosition: Int = 0
        // 跟踪空行状态
        var isOnEmptyLine: Bool = false
        var emptyLineLocation: Int = 0
        // 防止光标跳转到末尾
        var preventJumpToEnd: Bool = false
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
            self.lastTextLength = parent.attributedText.length
        }
        
        func textViewDidChange(_ textView: UITextView) {
            // 如果设置了防止跳转标记，先记录当前光标位置
            let cursorPosition = preventJumpToEnd ? textView.selectedRange.location : -1
            
            // 更新父视图的属性文本
            parent.attributedText = textView.attributedText
            
            // 如果需要维持自定义光标位置
            if shouldMaintainCustomCursor {
                // 确保自定义位置在有效范围内
                let safePosition = min(max(0, customCursorPosition), textView.text.count)
                textView.selectedRange = NSRange(location: safePosition, length: 0)
                shouldMaintainCustomCursor = false
            } else if preventJumpToEnd && cursorPosition >= 0 && cursorPosition <= textView.text.count {
                // 恢复记录的光标位置，防止跳转到末尾
                textView.selectedRange = NSRange(location: cursorPosition, length: 0)
                preventJumpToEnd = false
            }
            
            // 更新上次文本长度
            lastTextLength = textView.text.count
            // 保存上次选择范围
            lastSelectedRange = textView.selectedRange
            
            // 确保每次文本变化后光标位置都可见
            textView.scrollRangeToVisible(textView.selectedRange)
        }
        
        // 当选择改变时，更新工具栏状态并确保光标可见
        func textViewDidChangeSelection(_ textView: UITextView) {
            // 保存上次选择的范围，除非我们正在自定义处理光标
            if !shouldMaintainCustomCursor {
                lastSelectedRange = textView.selectedRange
            }
            
            // 如果有选择文本，检查其属性
            if textView.selectedRange.length > 0 {
                // 这里可以添加选择文本属性检测逻辑
            }
            
            // 确保光标始终可见
            textView.scrollRangeToVisible(textView.selectedRange)
        }
        
        // 处理文本变化，主要用于处理列表的回车
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // 检查是否按下回车键
            if text == "\n" {
                // 如果不是列表项的回车，需要自己处理光标位置
                if !isLineAListItem(textView: textView, range: range) && !isLineABlockquote(textView: textView, range: range) {
                    // 计算回车后光标应该的位置
                    customCursorPosition = range.location + 1
                    shouldMaintainCustomCursor = true
                }
                // 先检查是否需要处理引用块的回车
                if isLineABlockquote(textView: textView, range: range) {
                    return handleBlockquoteNewLine(textView: textView, range: range)
                }
                // 重置空行状态
                isOnEmptyLine = false
                return handleListNewLine(textView: textView, range: range)
            }
            
            // 检查是否是删除操作（text为空且range长度为1）
            if text.isEmpty && range.length == 1 {
                // 设置防止跳转标志
                preventJumpToEnd = true
                
                // 获取文本
                let nsText = textView.text as NSString
                
                // 检查当前行是否是列表项
                let isListItem = isLineAListItem(textView: textView, range: range)
                
                // 检查是否在删除列表项的前缀（如"1. "或"• "）
                if isListItem && isCursorAtListPrefix(textView: textView, position: range.location) {
                    // 让系统正常删除列表前缀，不做特殊处理
                    customCursorPosition = range.location
                    shouldMaintainCustomCursor = true
                    // 重置空行状态
                    isOnEmptyLine = false
                    return true
                }
                
                // 计算删除后光标应该的位置
                customCursorPosition = range.location
                shouldMaintainCustomCursor = true
                
                // 如果已经在空行上且再次按下删除键
                if isOnEmptyLine && range.location == emptyLineLocation {
                    // 找到上一行的末尾
                    if emptyLineLocation > 0 {
                        let lineStartRange = nsText.lineRange(for: NSRange(location: emptyLineLocation - 1, length: 0))
                        // 设置光标应该在上一行的末尾
                        customCursorPosition = lineStartRange.location + lineStartRange.length - 1
                        shouldMaintainCustomCursor = true
                    }
                    // 重置空行状态
                    isOnEmptyLine = false
                    return true
                }
                
                // 检查是否在删除行尾的换行符（会导致光标跳转）
                if range.location < nsText.length && range.location > 0 {
                    // 检查当前删除的字符是否是换行符
                    let charToDelete = nsText.substring(with: NSRange(location: range.location, length: 1))
                    if charToDelete == "\n" {
                        // 如果删除的是换行符，我们标记这是一个空行
                        let lineRange = nsText.lineRange(for: NSRange(location: range.location, length: 0))
                        let lineContent = nsText.substring(with: NSRange(location: lineRange.location, length: lineRange.length - 1))
                        if lineContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            isOnEmptyLine = true
                            emptyLineLocation = range.location
                        } else {
                            isOnEmptyLine = false
                        }
                    }
                    
                    // 检查是否在删除行的最后一个字符（且下一个是换行符）
                    if range.location + 1 < nsText.length {
                        let nextChar = nsText.substring(with: NSRange(location: range.location + 1, length: 1))
                        if nextChar == "\n" && isLastCharacterInLine(textView: textView, position: range.location) {
                            // 如果是列表项，我们不特殊处理
                            if isListItem {
                                isOnEmptyLine = false
                                return true
                            }
                            
                            // 检查当前行是否为空（除了当前删除的字符）
                            let lineRange = nsText.lineRange(for: NSRange(location: range.location, length: 0))
                            let lineWithoutLastChar = nsText.substring(with: NSRange(location: lineRange.location, length: range.location - lineRange.location))
                            
                            if lineWithoutLastChar.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                // 标记为空行，记录位置
                                isOnEmptyLine = true
                                emptyLineLocation = range.location
                            } else {
                                isOnEmptyLine = false
                            }
                        }
                    }
                }
            } else {
                // 如果不是删除操作，重置空行状态
                isOnEmptyLine = false
            }
            
            return true
        }
        
        // 判断当前行是否为列表项
        private func isLineAListItem(textView: UITextView, range: NSRange) -> Bool {
            let text = textView.text as NSString
            
            // 找到当前行的范围
            let lineRange = text.lineRange(for: NSRange(location: range.location, length: 0))
            let currentLine = text.substring(with: lineRange)
            
            // 检查是否是有序列表行
            let orderedPattern = "^(\\s*)(\\d+)\\.(\\s+)(.*)$"
            if let regex = try? NSRegularExpression(pattern: orderedPattern, options: []),
               regex.firstMatch(in: currentLine, options: [], range: NSRange(location: 0, length: currentLine.count)) != nil {
                return true
            }
            
            // 检查是否是无序列表行
            let unorderedPattern = "^(\\s*)([•\\-\\*])(\\s+)(.*)$"
            if let regex = try? NSRegularExpression(pattern: unorderedPattern, options: []),
               regex.firstMatch(in: currentLine, options: [], range: NSRange(location: 0, length: currentLine.count)) != nil {
                return true
            }
            
            return false
        }
        
        // 判断当前行是否为引用块
        private func isLineABlockquote(textView: UITextView, range: NSRange) -> Bool {
            let nsText = textView.text as NSString
            
            // 找到当前行的范围
            let lineRange = nsText.lineRange(for: NSRange(location: range.location, length: 0))
            let currentLine = nsText.substring(with: lineRange)
            
            // 检查是否是引用块行
            return currentLine.hasPrefix("> ")
        }
        
        // 处理列表的新行
        private func handleListNewLine(textView: UITextView, range: NSRange) -> Bool {
            let attributedText = textView.attributedText!
            let text = attributedText.string
            let nsText = text as NSString // 使用NSString处理
            
            // 找到当前行的范围 - 使用NSString的lineRange方法
            let lineRange = nsText.lineRange(for: NSRange(location: range.location, length: 0))
            
            // 获取当前行的文本
            let currentLine = nsText.substring(with: lineRange)
            
            // 检查是否是有序列表行
            let orderedPattern = "^(\\s*)(\\d+)\\.(\\s+)(.*)$"
            if let regex = try? NSRegularExpression(pattern: orderedPattern, options: []) {
                let matches = regex.matches(in: currentLine, options: [], range: NSRange(location: 0, length: currentLine.count))
                
                if let match = matches.first {
                    // 提取各个部分
                    let whitespace = (currentLine as NSString).substring(with: match.range(at: 1))
                    let number = (currentLine as NSString).substring(with: match.range(at: 2))
                    let postNumberSpace = (currentLine as NSString).substring(with: match.range(at: 3))
                    let content = (currentLine as NSString).substring(with: match.range(at: 4))
                    
                    if let numberInt = Int(number) {
                        // 获取光标在内容中的位置
                        let contentStart = match.range(at: 1).length + match.range(at: 2).length + match.range(at: 3).length + 1 // +1 是因为"."
                        let cursorPositionInContent = max(0, range.location - lineRange.location - contentStart)
                        
                        if cursorPositionInContent == 0 && content.isEmpty {
                            // 如果内容为空且光标在内容开始处，并且不是第一项，则退出列表
                            if number != "1" {
                                // 简单地插入换行加缩进
                                let newText = "\n\(whitespace)"
                                let mutableAttrText = NSMutableAttributedString(attributedString: textView.attributedText!)
                                mutableAttrText.replaceCharacters(in: range, with: newText)
                                textView.attributedText = mutableAttrText
                                
                                // 更新光标位置
                                let newPosition = range.location + newText.count
                                textView.selectedRange = NSRange(location: newPosition, length: 0)
                                
                                // 确保光标可见
                                textView.scrollRangeToVisible(textView.selectedRange)
                                
                                // 通知父视图更新
                                parent.attributedText = textView.attributedText
                                
                                return false
                            }
                        }
                        
                        // 决定如何处理回车
                        if cursorPositionInContent < content.count {
                            // 如果光标在内容中间，则分割当前行，保持当前行的格式
                            let safePosition = min(max(0, cursorPositionInContent), content.count)
                            let beforeCursor = content.prefix(safePosition)
                            let afterCursor = content.suffix(content.count - safePosition)
                            
                            // 创建新行，保持同样格式
                            let newText = "\n\(whitespace)\(numberInt).\(postNumberSpace)\(afterCursor)"
                            
                            // 更新当前行
                            let mutableAttrText = NSMutableAttributedString(attributedString: textView.attributedText!)
                            // 首先删除光标后的内容
                            let afterCursorRange = NSRange(location: range.location, length: afterCursor.count)
                            mutableAttrText.deleteCharacters(in: afterCursorRange)
                            // 然后插入带有新行和格式的文本
                            mutableAttrText.insert(NSAttributedString(string: newText), at: range.location)
                            textView.attributedText = mutableAttrText
                            
                            // 更新光标位置到新行的内容起始处
                            let newPosition = range.location + newText.count - afterCursor.count
                            textView.selectedRange = NSRange(location: newPosition, length: 0)
                            
                            // 确保光标可见
                            textView.scrollRangeToVisible(textView.selectedRange)
                            
                            // 通知父视图更新
                            parent.attributedText = textView.attributedText
                            
                            return false
                        } else {
                            // 如果光标在内容末尾，创建新的递增列表项
                            let newPrefix = "\n\(whitespace)\(numberInt + 1).\(postNumberSpace)"
                            
                            // 插入新的列表项
                            let mutableAttrText = NSMutableAttributedString(attributedString: textView.attributedText!)
                            mutableAttrText.replaceCharacters(in: range, with: newPrefix)
                            textView.attributedText = mutableAttrText
                            
                            // 更新光标位置
                            let newPosition = range.location + newPrefix.count
                            textView.selectedRange = NSRange(location: newPosition, length: 0)
                            
                            // 确保光标可见
                            textView.scrollRangeToVisible(textView.selectedRange)
                            
                            // 通知父视图更新
                            parent.attributedText = textView.attributedText
                            
                            return false
                        }
                    }
                }
            }
            
            // 检查是否是无序列表行
            let unorderedPattern = "^(\\s*)([•\\-\\*])(\\s+)(.*)$"
            if let regex = try? NSRegularExpression(pattern: unorderedPattern, options: []) {
                let matches = regex.matches(in: currentLine, options: [], range: NSRange(location: 0, length: currentLine.count))
                
                if let match = matches.first {
                    // 提取各个部分
                    let whitespace = (currentLine as NSString).substring(with: match.range(at: 1))
                    let bullet = (currentLine as NSString).substring(with: match.range(at: 2))
                    let postBulletSpace = (currentLine as NSString).substring(with: match.range(at: 3))
                    let content = (currentLine as NSString).substring(with: match.range(at: 4))
                    
                    // 获取光标在内容中的位置
                    let contentStart = match.range(at: 1).length + match.range(at: 2).length + match.range(at: 3).length
                    let cursorPositionInContent = max(0, range.location - lineRange.location - contentStart)
                    
                    if cursorPositionInContent == 0 && content.isEmpty {
                        // 如果内容为空且光标在内容开始处，则退出列表
                        // 简单地插入换行加缩进
                        let newText = "\n\(whitespace)"
                        let mutableAttrText = NSMutableAttributedString(attributedString: textView.attributedText!)
                        mutableAttrText.replaceCharacters(in: range, with: newText)
                        textView.attributedText = mutableAttrText
                        
                        // 更新光标位置
                        let newPosition = range.location + newText.count
                        textView.selectedRange = NSRange(location: newPosition, length: 0)
                        
                        // 确保光标可见
                        textView.scrollRangeToVisible(textView.selectedRange)
                        
                        // 通知父视图更新
                        parent.attributedText = textView.attributedText
                        
                        return false
                    }
                    
                    // 决定如何处理回车
                    if cursorPositionInContent < content.count {
                        // 如果光标在内容中间，则分割当前行，保持当前行的格式
                        let safePosition = min(max(0, cursorPositionInContent), content.count)
                        let beforeCursor = content.prefix(safePosition)
                        let afterCursor = content.suffix(content.count - safePosition)
                        
                        // 创建新行，保持同样格式
                        let newText = "\n\(whitespace)\(bullet)\(postBulletSpace)\(afterCursor)"
                        
                        // 更新当前行
                        let mutableAttrText = NSMutableAttributedString(attributedString: textView.attributedText!)
                        // 首先删除光标后的内容
                        let afterCursorRange = NSRange(location: range.location, length: afterCursor.count)
                        mutableAttrText.deleteCharacters(in: afterCursorRange)
                        // 然后插入带有新行和格式的文本
                        mutableAttrText.insert(NSAttributedString(string: newText), at: range.location)
                        textView.attributedText = mutableAttrText
                        
                        // 更新光标位置到新行的内容起始处
                        let newPosition = range.location + newText.count - afterCursor.count
                        textView.selectedRange = NSRange(location: newPosition, length: 0)
                        
                        // 确保光标可见
                        textView.scrollRangeToVisible(textView.selectedRange)
                        
                        // 通知父视图更新
                        parent.attributedText = textView.attributedText
                        
                        return false
                    } else {
                        // 如果光标在内容末尾，创建新的列表项
                        let newPrefix = "\n\(whitespace)\(bullet)\(postBulletSpace)"
                        
                        // 插入新的列表项
                        let mutableAttrText = NSMutableAttributedString(attributedString: textView.attributedText!)
                        mutableAttrText.replaceCharacters(in: range, with: newPrefix)
                        textView.attributedText = mutableAttrText
                        
                        // 更新光标位置
                        let newPosition = range.location + newPrefix.count
                        textView.selectedRange = NSRange(location: newPosition, length: 0)
                        
                        // 确保光标可见
                        textView.scrollRangeToVisible(textView.selectedRange)
                        
                        // 通知父视图更新
                        parent.attributedText = textView.attributedText
                        
                        return false
                    }
                }
            }
            
            return true
        }
        
        // 处理引用块的新行
        private func handleBlockquoteNewLine(textView: UITextView, range: NSRange) -> Bool {
            let attributedText = textView.attributedText!
            let text = attributedText.string
            let nsText = text as NSString
            
            // 找到当前行的范围
            let lineRange = nsText.lineRange(for: NSRange(location: range.location, length: 0))
            
            // 获取当前行的文本
            let currentLine = nsText.substring(with: lineRange)
            
            // 检查是否是引用块行
            if currentLine.hasPrefix("> ") {
                // 提取引用块后的内容
                let content = currentLine.replacingOccurrences(of: "^> ", with: "", options: .regularExpression)
                
                // 获取光标在内容中的位置
                let contentStart = 2 // "> " 的长度
                let cursorPositionInContent = range.location - lineRange.location - contentStart
                
                // 如果内容为空且光标在内容开始处，则退出引用块
                if cursorPositionInContent <= 0 && content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // 简单地插入换行，不带引用前缀
                    let newText = "\n"
                    let mutableAttrText = NSMutableAttributedString(attributedString: textView.attributedText!)
                    mutableAttrText.replaceCharacters(in: range, with: newText)
                    textView.attributedText = mutableAttrText
                    
                    // 更新光标位置
                    let newPosition = range.location + newText.count
                    textView.selectedRange = NSRange(location: newPosition, length: 0)
                    
                    // 通知父视图更新
                    parent.attributedText = textView.attributedText
                    
                    return false
                }
                
                // 决定如何处理回车
                if cursorPositionInContent < content.count {
                    // 如果光标在内容中间，则分割当前行，保持当前行的引用块格式
                    let safePosition = min(max(0, cursorPositionInContent), content.count)
                    let beforeCursor = content.prefix(safePosition)
                    let afterCursor = content.suffix(content.count - safePosition)
                    
                    // 创建新行，保持引用块格式
                    let newText = "\n> \(afterCursor)"
                    
                    // 更新当前行
                    let mutableAttrText = NSMutableAttributedString(attributedString: textView.attributedText!)
                    
                    // 首先删除光标后的内容
                    let afterCursorRange = NSRange(location: range.location, length: afterCursor.count)
                    mutableAttrText.deleteCharacters(in: afterCursorRange)
                    
                    // 然后插入带有新行和引用块格式的文本
                    let insertAttr = NSMutableAttributedString(string: newText)
                    
                    // 获取当前行的段落样式和颜色
                    if let paragraphStyle = textView.attributedText.attribute(.paragraphStyle, at: lineRange.location, effectiveRange: nil) as? NSParagraphStyle,
                       let foregroundColor = textView.attributedText.attribute(.foregroundColor, at: lineRange.location, effectiveRange: nil) as? UIColor {
                        
                        // 应用相同的段落样式和颜色到新行
                        insertAttr.addAttributes([
                            .paragraphStyle: paragraphStyle,
                            .foregroundColor: foregroundColor
                        ], range: NSRange(location: 0, length: insertAttr.length))
                    }
                    
                    mutableAttrText.insert(insertAttr, at: range.location)
                    textView.attributedText = mutableAttrText
                    
                    // 更新光标位置到新行的内容起始处
                    let newPosition = range.location + newText.count - afterCursor.count
                    textView.selectedRange = NSRange(location: newPosition, length: 0)
                    
                    // 通知父视图更新
                    parent.attributedText = textView.attributedText
                    
                    return false
                } else {
                    // 如果光标在内容末尾，创建新的引用块行
                    let newPrefix = "\n> "
                    
                    // 插入新的引用块行
                    let mutableAttrText = NSMutableAttributedString(attributedString: textView.attributedText!)
                    let insertAttr = NSMutableAttributedString(string: newPrefix)
                    
                    // 获取当前行的段落样式和颜色
                    if let paragraphStyle = textView.attributedText.attribute(.paragraphStyle, at: lineRange.location, effectiveRange: nil) as? NSParagraphStyle,
                       let foregroundColor = textView.attributedText.attribute(.foregroundColor, at: lineRange.location, effectiveRange: nil) as? UIColor {
                        
                        // 应用相同的段落样式和颜色到新行
                        insertAttr.addAttributes([
                            .paragraphStyle: paragraphStyle,
                            .foregroundColor: foregroundColor
                        ], range: NSRange(location: 0, length: insertAttr.length))
                    }
                    
                    mutableAttrText.replaceCharacters(in: range, with: insertAttr)
                    textView.attributedText = mutableAttrText
                    
                    // 更新光标位置
                    let newPosition = range.location + newPrefix.count
                    textView.selectedRange = NSRange(location: newPosition, length: 0)
                    
                    // 通知父视图更新
                    parent.attributedText = textView.attributedText
                    
                    return false
                }
            }
            
            return true
        }
        
        // 判断当前位置是否是行内最后一个字符
        private func isLastCharacterInLine(textView: UITextView, position: Int) -> Bool {
            let nsText = textView.text as NSString
            let lineRange = nsText.lineRange(for: NSRange(location: position, length: 0))
            
            // 当前行的内容（排除换行符）
            let lineContent = nsText.substring(with: NSRange(location: lineRange.location, length: lineRange.length - 1))
            
            // 检查position是否在行的最后一个可见字符位置
            return position == lineRange.location + lineContent.count - 1
        }
        
        // 判断当前位置是否在列表前缀内
        private func isCursorAtListPrefix(textView: UITextView, position: Int) -> Bool {
            let nsText = textView.text as NSString
            let lineRange = nsText.lineRange(for: NSRange(location: position, length: 0))
            let currentLine = nsText.substring(with: lineRange)
            
            // 检查是否是有序列表行
            let orderedPattern = "^(\\s*)(\\d+)\\.(\\s+)(.*)$"
            if let regex = try? NSRegularExpression(pattern: orderedPattern, options: []),
               let match = regex.firstMatch(in: currentLine, options: [], range: NSRange(location: 0, length: currentLine.count)) {
                
                // 计算前缀结束位置
                let prefixEnd = match.range(at: 1).length + match.range(at: 2).length + 1 + match.range(at: 3).length // 1 是"."的长度
                // 检查光标是否在前缀范围内
                return position - lineRange.location < prefixEnd
            }
            
            // 检查是否是无序列表行
            let unorderedPattern = "^(\\s*)([•\\-\\*])(\\s+)(.*)$"
            if let regex = try? NSRegularExpression(pattern: unorderedPattern, options: []),
               let match = regex.firstMatch(in: currentLine, options: [], range: NSRange(location: 0, length: currentLine.count)) {
                
                // 计算前缀结束位置
                let prefixEnd = match.range(at: 1).length + match.range(at: 2).length + match.range(at: 3).length
                // 检查光标是否在前缀范围内
                return position - lineRange.location < prefixEnd
            }
            
            return false
        }
    }
}

// 富文本样式工具栏
struct RichTextToolbar: View {
    @Binding var attributedText: NSAttributedString
    @Binding var currentAttributes: RichTextFormatting.TextAttributes
    let textView: UITextView
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                ForEach(RichTextFormatting.HeaderStyle.allCases, id: \.self) { style in
                    Button(action: {
                        applyHeadingStyle(style)
                    }) {
                        Text(style.rawValue)
                            .font(.system(size: style.fontSize))
                    }
                }
                
                Divider()
                    .frame(height: 20)
                
                // 引用块按钮
                Button(action: {
                    applyBlockquote()
                }) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 18))
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 44)
        .background(Color(UIColor.systemGray6))
    }
    
    private func applyHeadingStyle(_ style: RichTextFormatting.HeaderStyle) {
        let range = textView.selectedRange
        
        // 如果没有选择文本，则设置当前输入状态
        if range.length == 0 {
            // 设置为当前输入的标题样式
            if currentAttributes.headerStyle == style {
                currentAttributes.headerStyle = nil
            } else {
                currentAttributes.headerStyle = style
            }
            // 更新文本视图的输入属性
            textView.typingAttributes = currentAttributes.getAttributes()
            return
        }
        
        // 如果有选择文本，则应用样式到选中文本
        let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
        
        // 应用标题样式
        style.apply(to: mutableAttrText, range: range)
        attributedText = mutableAttrText
    }
    
    // 应用引用块样式
    private func applyBlockquote() {
        let range = textView.selectedRange
        
        // 获取选中的文本范围
        if range.length > 0 {
            // 如果有选择文本，将其转换为引用块
            let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
            let selectedText = attributedText.attributedSubstring(from: range).string
            
            // 分割选中的文本为行
            let lines = selectedText.components(separatedBy: .newlines)
            
            // 创建引用块样式
            var blockquoteText = NSMutableAttributedString()
            
            for (index, line) in lines.enumerated() {
                // 对于每一行，添加引用符号
                let lineWithQuote = "> \(line)"
                let lineAttrString = NSMutableAttributedString(string: lineWithQuote)
                
                // 添加引用块的样式
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.headIndent = 20
                paragraphStyle.firstLineHeadIndent = 0
                paragraphStyle.tailIndent = -20
                
                lineAttrString.addAttributes([
                    .paragraphStyle: paragraphStyle,
                    .foregroundColor: UIColor.darkGray,
                    .backgroundColor: UIColor.systemGray6
                ], range: NSRange(location: 0, length: lineAttrString.length))
                
                blockquoteText.append(lineAttrString)
                
                // 除了最后一行，每行后面添加换行
                if index < lines.count - 1 {
                    blockquoteText.append(NSAttributedString(string: "\n"))
                }
            }
            
            // 替换选中的文本为引用块样式的文本
            mutableAttrText.replaceCharacters(in: range, with: blockquoteText)
            attributedText = mutableAttrText
            
            // 更新选中范围
            textView.selectedRange = NSRange(location: range.location, length: blockquoteText.length)
        } else {
            // 如果没有选择文本，则设置当前输入为引用块样式
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.headIndent = 20
            paragraphStyle.firstLineHeadIndent = 0
            paragraphStyle.tailIndent = -20
            
            // 更新当前输入属性
            currentAttributes.formatStyles = []
            currentAttributes.headerStyle = nil
            
            // 将自定义段落样式添加到当前属性中
            var attributes = currentAttributes.getAttributes()
            attributes[.paragraphStyle] = paragraphStyle
            attributes[.foregroundColor] = UIColor.darkGray
            attributes[.backgroundColor] = UIColor.systemGray6
            
            // 将光标所在行转换为引用块
            let nsText = textView.text as NSString
            let lineRange = nsText.lineRange(for: NSRange(location: range.location, length: 0))
            let currentLine = nsText.substring(with: lineRange)
            
            // 检查当前行是否已经是引用块
            if !currentLine.hasPrefix("> ") {
                let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
                
                // 创建引用块样式的行
                let quotePrefix = "> "
                let quoteLine = "\(quotePrefix)\(currentLine)"
                let lineAttrString = NSMutableAttributedString(string: quoteLine)
                
                // 添加引用块的样式
                lineAttrString.addAttributes([
                    .paragraphStyle: paragraphStyle,
                    .foregroundColor: UIColor.darkGray,
                    .backgroundColor: UIColor.systemGray6
                ], range: NSRange(location: 0, length: lineAttrString.length))
                
                // 替换当前行
                mutableAttrText.replaceCharacters(in: lineRange, with: lineAttrString)
                attributedText = mutableAttrText
                
                // 更新光标位置
                textView.selectedRange = NSRange(location: range.location + quotePrefix.count, length: 0)
            }
            
            // 更新文本视图的输入属性
            textView.typingAttributes = attributes
        }
    }
} 
 