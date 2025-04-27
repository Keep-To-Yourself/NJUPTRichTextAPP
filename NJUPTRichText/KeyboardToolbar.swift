import SwiftUI
import UIKit

// 工具栏的SwiftUI包装器
struct KeyboardToolbar: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    @Binding var currentAttributes: RichTextFormatting.TextAttributes
    let textView: UITextView
    
    func makeUIView(context: Context) -> ToolbarContainerView {
        let toolbar = ToolbarContainerView()
        toolbar.setup(attributedText: $attributedText, currentAttributes: $currentAttributes, textView: textView)
        return toolbar
    }
    
    func updateUIView(_ uiView: ToolbarContainerView, context: Context) {
        uiView.update(attributedText: attributedText)
    }
}

// 工具栏容器视图
class ToolbarContainerView: UIView {
    private var attributedTextBinding: Binding<NSAttributedString>?
    private var currentAttributesBinding: Binding<RichTextFormatting.TextAttributes>?
    private var textView: UITextView?
    private var headerPickerController: HeaderStylePickerController?
    private var formatPickerController: FormatStylePickerController?
    private var keyWindow: UIWindow? {
        return UIApplication.shared.windows.first(where: { $0.isKeyWindow })
    }
    
    private lazy var toolbarView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // 标题样式按钮
    private lazy var headingButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("标题样式", for: .normal)
        button.setImage(UIImage(systemName: "chevron.up"), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.semanticContentAttribute = .forceRightToLeft
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 0)
        button.tintColor = .systemBlue
        button.addTarget(self, action: #selector(showHeaderPicker), for: .touchUpInside)
        return button
    }()
    
    // BIUS格式按钮
    private lazy var formatButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("BIUS", for: .normal)
        button.setImage(UIImage(systemName: "chevron.up"), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.semanticContentAttribute = .forceRightToLeft
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 0)
        button.tintColor = .systemBlue
        button.addTarget(self, action: #selector(showFormatPicker), for: .touchUpInside)
        return button
    }()
    
    // 图片上传按钮
    private lazy var imageButton: UIButton = {
        let button = UIButton(type: .system)
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        button.setImage(UIImage(systemName: "photo", withConfiguration: imageConfig), for: .normal)
        button.tintColor = .systemBlue
        button.addTarget(self, action: #selector(showImagePicker), for: .touchUpInside)
        return button
    }()
    
    // 有序列表按钮
    private lazy var orderedListButton: UIButton = {
        let button = UIButton(type: .system)
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        button.setImage(UIImage(systemName: "list.number", withConfiguration: imageConfig), for: .normal)
        button.tintColor = .systemBlue
        button.addTarget(self, action: #selector(insertOrderedList), for: .touchUpInside)
        return button
    }()
    
    // 无序列表按钮
    private lazy var unorderedListButton: UIButton = {
        let button = UIButton(type: .system)
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        button.setImage(UIImage(systemName: "list.bullet", withConfiguration: imageConfig), for: .normal)
        button.tintColor = .systemBlue
        button.addTarget(self, action: #selector(insertUnorderedList), for: .touchUpInside)
        return button
    }()
    
    // 引用块按钮
    private lazy var blockquoteButton: UIButton = {
        let button = UIButton(type: .system)
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        button.setImage(UIImage(systemName: "text.quote", withConfiguration: imageConfig), for: .normal)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        button.layer.cornerRadius = 6
        button.tintColor = .systemBlue
        button.addTarget(self, action: #selector(insertBlockquote), for: .touchUpInside)
        return button
    }()
    
    private var containerView: UIView?
    private var imagePicker: UIImagePickerController?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup(attributedText: Binding<NSAttributedString>, currentAttributes: Binding<RichTextFormatting.TextAttributes>, textView: UITextView) {
        self.attributedTextBinding = attributedText
        self.currentAttributesBinding = currentAttributes
        self.textView = textView
        
        // 创建工具栏
        let containerHeight: CGFloat = 50
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: containerHeight))
        containerView.backgroundColor = .systemBackground
        self.containerView = containerView
        
        // 添加分割线
        let topSeparator = UIView(frame: CGRect(x: 0, y: 0, width: containerView.bounds.width, height: 0.5))
        topSeparator.backgroundColor = .systemGray4
        containerView.addSubview(topSeparator)
        
        // 创建滚动视图
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0.5, width: containerView.bounds.width, height: containerHeight - 0.5))
        scrollView.showsHorizontalScrollIndicator = false
        containerView.addSubview(scrollView)
        
        // 计算布局参数
        let margin: CGFloat = 16 // 左右边距
        let buttonSpacing: CGFloat = 12 // 按钮之间的间距
        let buttonHeight: CGFloat = 30
        let verticalCenter: CGFloat = 10 // 垂直位置
        
        // 标题按钮宽度（较宽）
        let headingButtonWidth: CGFloat = 105
        // BIUS按钮宽度（中等）
        let formatButtonWidth: CGFloat = 90
        // 图标按钮宽度（窄）
        let iconButtonWidth: CGFloat = 40
        
        // 当前x坐标位置
        var xPosition = margin
        
        // 添加标题样式按钮
        headingButton.frame = CGRect(x: xPosition, y: verticalCenter, width: headingButtonWidth, height: buttonHeight)
        scrollView.addSubview(headingButton)
        xPosition += headingButtonWidth + buttonSpacing
        
        // 添加BIUS格式按钮
        formatButton.frame = CGRect(x: xPosition, y: verticalCenter, width: formatButtonWidth, height: buttonHeight)
        scrollView.addSubview(formatButton)
        xPosition += formatButtonWidth + buttonSpacing
        
        // 添加图片上传按钮
        imageButton.frame = CGRect(x: xPosition, y: verticalCenter, width: iconButtonWidth, height: buttonHeight)
        scrollView.addSubview(imageButton)
        xPosition += iconButtonWidth + buttonSpacing
        
        // 添加有序列表按钮
        orderedListButton.frame = CGRect(x: xPosition, y: verticalCenter, width: iconButtonWidth, height: buttonHeight)
        scrollView.addSubview(orderedListButton)
        xPosition += iconButtonWidth + buttonSpacing
        
        // 添加无序列表按钮
        unorderedListButton.frame = CGRect(x: xPosition, y: verticalCenter, width: iconButtonWidth, height: buttonHeight)
        scrollView.addSubview(unorderedListButton)
        xPosition += iconButtonWidth + buttonSpacing
        
        // 添加引用块按钮
        blockquoteButton.frame = CGRect(x: xPosition, y: verticalCenter, width: iconButtonWidth, height: buttonHeight)
        scrollView.addSubview(blockquoteButton)
        xPosition += iconButtonWidth + buttonSpacing
        
        // 设置滚动视图内容大小
        scrollView.contentSize = CGSize(width: xPosition, height: containerHeight - 0.5)
        
        // 设置为输入附件视图
        textView.inputAccessoryView = containerView
        textView.reloadInputViews()
    }
    
    func update(attributedText: NSAttributedString) {
        // 更新状态如果需要
    }
    
    // 显示标题样式选择器
    @objc private func showHeaderPicker() {
        guard let textView = self.textView,
              let attributedTextBinding = self.attributedTextBinding,
              let currentAttributesBinding = self.currentAttributesBinding,
              let containerView = self.containerView else { return }
        
        // 如果已经显示了格式选择器，先关闭它
        if formatPickerController != nil {
            dismissFormatPicker()
        }
        
        // 如果已经显示了选择器，则关闭它
        if headerPickerController != nil {
            dismissHeaderPicker()
            return
        }
        
        // 创建选择器
        let headerPickerController = HeaderStylePickerController()
        self.headerPickerController = headerPickerController
        
        // 设置关闭回调
        headerPickerController.onDismiss = { [weak self] in
            self?.dismissHeaderPicker()
        }
        
        // 获取根视图控制器
        guard let rootViewController = getParentViewController() else { return }
        
        // 设置选择器控制器的视图大小和位置
        headerPickerController.view.frame = rootViewController.view.bounds
        
        // 添加选择器控制器
        rootViewController.addChild(headerPickerController)
        rootViewController.view.addSubview(headerPickerController.view)
        headerPickerController.didMove(toParent: rootViewController)
        
        // 打印调试信息
        print("工具栏位置: \(containerView.frame)")
        
        // 显示选择器 - 传递toolbarView作为锚点
        headerPickerController.showPicker(
            above: containerView,
            attributedText: attributedTextBinding,
            currentAttributes: currentAttributesBinding,
            textView: textView
        )
        
        // 反转箭头图标
        UIView.animate(withDuration: 0.3) {
            self.headingButton.imageView?.transform = CGAffineTransform(rotationAngle: .pi)
        }
    }
    
    // 显示BIUS格式选择器
    @objc private func showFormatPicker() {
        guard let textView = self.textView,
              let attributedTextBinding = self.attributedTextBinding,
              let currentAttributesBinding = self.currentAttributesBinding,
              let containerView = self.containerView else { return }
        
        // 如果已经显示了标题选择器，先关闭它
        if headerPickerController != nil {
            dismissHeaderPicker()
        }
        
        // 如果已经显示了格式选择器，则关闭它
        if formatPickerController != nil {
            dismissFormatPicker()
            return
        }
        
        // 创建选择器
        let formatPickerController = FormatStylePickerController()
        self.formatPickerController = formatPickerController
        
        // 设置关闭回调
        formatPickerController.onDismiss = { [weak self] in
            self?.dismissFormatPicker()
        }
        
        // 获取根视图控制器
        guard let rootViewController = getParentViewController() else { return }
        
        // 设置选择器控制器的视图大小和位置
        formatPickerController.view.frame = rootViewController.view.bounds
        
        // 添加选择器控制器
        rootViewController.addChild(formatPickerController)
        rootViewController.view.addSubview(formatPickerController.view)
        formatPickerController.didMove(toParent: rootViewController)
        
        // 显示选择器
        formatPickerController.showPicker(
            above: containerView,
            attributedText: attributedTextBinding,
            currentAttributes: currentAttributesBinding,
            textView: textView
        )
        
        // 反转箭头图标
        UIView.animate(withDuration: 0.3) {
            self.formatButton.imageView?.transform = CGAffineTransform(rotationAngle: .pi)
        }
    }
    
    // 显示图片选择器
    @objc private func showImagePicker() {
        guard let viewController = getParentViewController() else { return }
        
        let picker = UIImagePickerController()
        self.imagePicker = picker
        picker.delegate = self
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        
        viewController.present(picker, animated: true)
    }
    
    private func dismissHeaderPicker() {
        headerPickerController?.dismissPicker()
        headerPickerController = nil
        
        // 恢复箭头图标
        UIView.animate(withDuration: 0.3) {
            self.headingButton.imageView?.transform = .identity
        }
    }
    
    private func dismissFormatPicker() {
        formatPickerController?.dismissPicker()
        formatPickerController = nil
        
        // 恢复箭头图标
        UIView.animate(withDuration: 0.3) {
            self.formatButton.imageView?.transform = .identity
        }
    }
    
    // 重命名为不同的名称避免与扩展冲突
    private func getParentViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }
        
        // 如果没有找到，使用根视图控制器
        return keyWindow?.rootViewController
    }
    
    // 插入有序列表
    @objc private func insertOrderedList() {
        guard let textView = self.textView,
              let attributedTextBinding = self.attributedTextBinding else { return }
        
        let currentText = attributedTextBinding.wrappedValue
        let mutableAttrText = NSMutableAttributedString(attributedString: currentText)
        let selectedRange = textView.selectedRange
        
        // 获取当前行的信息
        let text = currentText.string
        let nsText = text as NSString
        let lineRange = nsText.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        let currentLine = nsText.substring(with: lineRange)
        
        // 根据光标所在位置确定插入点
        let insertionIndex = selectedRange.location
        
        // 检测当前行是否已有缩进
        let whitespaceMatch = currentLine.match(regex: "^(\\s*)")
        let indentString = whitespaceMatch?.group(at: 1) ?? ""
        
        // 构建列表项
        let listMarker = "1. "
        let listItemPrefix = "\n\(indentString)\(listMarker)"
        
        // 插入列表
        if selectedRange.length > 0 {
            // 如果有选择的文本，将每行转为列表项
            let startIndex = text.index(text.startIndex, offsetBy: selectedRange.location)
            let endIndex = text.index(text.startIndex, offsetBy: selectedRange.location + selectedRange.length)
            let selectedText = String(text[startIndex..<endIndex])
            
            let lines = selectedText.split(separator: "\n")
            var formattedText = ""
            
            for (index, line) in lines.enumerated() {
                // 第一行不添加换行
                if index == 0 {
                    formattedText += "\(indentString)\(index + 1). \(line.trimmingCharacters(in: .whitespaces))"
                } else {
                    formattedText += "\n\(indentString)\(index + 1). \(line.trimmingCharacters(in: .whitespaces))"
                }
            }
            
            // 替换选中的文本
            mutableAttrText.replaceCharacters(in: selectedRange, with: formattedText)
            attributedTextBinding.wrappedValue = mutableAttrText
            
            // 设置新的选择范围
            textView.selectedRange = NSMakeRange(selectedRange.location, formattedText.count)
        } else {
            // 如果没有选择文本，插入一个列表项
            mutableAttrText.insert(NSAttributedString(string: listItemPrefix), at: insertionIndex)
            attributedTextBinding.wrappedValue = mutableAttrText
            
            // 移动光标到列表项后
            textView.selectedRange = NSMakeRange(insertionIndex + listItemPrefix.count, 0)
        }
    }
    
    // 插入无序列表
    @objc private func insertUnorderedList() {
        guard let textView = self.textView,
              let attributedTextBinding = self.attributedTextBinding else { return }
        
        let currentText = attributedTextBinding.wrappedValue
        let mutableAttrText = NSMutableAttributedString(attributedString: currentText)
        let selectedRange = textView.selectedRange
        
        // 获取当前行的信息
        let text = currentText.string
        let nsText = text as NSString
        let lineRange = nsText.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        let currentLine = nsText.substring(with: lineRange)
        
        // 根据光标所在位置确定插入点
        let insertionIndex = selectedRange.location
        
        // 检测当前行是否已有缩进
        let whitespaceMatch = currentLine.match(regex: "^(\\s*)")
        let indentString = whitespaceMatch?.group(at: 1) ?? ""
        
        // 构建列表项
        let listMarker = "• "
        let listItemPrefix = "\n\(indentString)\(listMarker)"
        
        // 插入列表
        if selectedRange.length > 0 {
            // 如果有选择的文本，将每行转为列表项
            let startIndex = text.index(text.startIndex, offsetBy: selectedRange.location)
            let endIndex = text.index(text.startIndex, offsetBy: selectedRange.location + selectedRange.length)
            let selectedText = String(text[startIndex..<endIndex])
            
            let lines = selectedText.split(separator: "\n")
            var formattedText = ""
            
            for (index, line) in lines.enumerated() {
                // 第一行不添加换行
                if index == 0 {
                    formattedText += "\(indentString)\(listMarker)\(line.trimmingCharacters(in: .whitespaces))"
                } else {
                    formattedText += "\n\(indentString)\(listMarker)\(line.trimmingCharacters(in: .whitespaces))"
                }
            }
            
            // 替换选中的文本
            mutableAttrText.replaceCharacters(in: selectedRange, with: formattedText)
            attributedTextBinding.wrappedValue = mutableAttrText
            
            // 设置新的选择范围
            textView.selectedRange = NSMakeRange(selectedRange.location, formattedText.count)
        } else {
            // 如果没有选择文本，插入一个列表项
            mutableAttrText.insert(NSAttributedString(string: listItemPrefix), at: insertionIndex)
            attributedTextBinding.wrappedValue = mutableAttrText
            
            // 移动光标到列表项后
            textView.selectedRange = NSMakeRange(insertionIndex + listItemPrefix.count, 0)
        }
    }
    
    // 插入引用块
    @objc private func insertBlockquote() {
        guard let textView = self.textView,
              let attributedTextBinding = self.attributedTextBinding,
              let currentAttributesBinding = self.currentAttributesBinding else { return }
        
        let currentText = attributedTextBinding.wrappedValue
        let mutableAttrText = NSMutableAttributedString(attributedString: currentText)
        let selectedRange = textView.selectedRange
        
        // 获取引用块的样式属性
        var updatedAttributes = currentAttributesBinding.wrappedValue
        updatedAttributes.isBlockquote = true
        let blockquoteAttributes = updatedAttributes.getBlockquoteAttributes()
        
        // 创建引用块
        let blockContentPlaceholder = "引用内容"
        let blockPrefix = "\n"
        let blockSuffix = "\n"
        
        // 如果有选中文本，使用选中文本作为引用内容
        let contentText: String
        if selectedRange.length > 0 {
            let startIndex = currentText.string.index(currentText.string.startIndex, offsetBy: selectedRange.location)
            let endIndex = currentText.string.index(startIndex, offsetBy: selectedRange.length)
            contentText = String(currentText.string[startIndex..<endIndex])
        } else {
            contentText = blockContentPlaceholder
        }
        
        // 创建引用块文本
        let blockquoteText = "\(blockPrefix)> \(contentText)\(blockSuffix)"
        let attributedBlockquote = NSMutableAttributedString(string: blockquoteText)
        
        // 为整个引用块应用样式
        attributedBlockquote.addAttributes(blockquoteAttributes, range: NSRange(location: 0, length: blockquoteText.count))
        
        // 在光标位置插入引用块
        mutableAttrText.replaceCharacters(in: selectedRange, with: attributedBlockquote)
        attributedTextBinding.wrappedValue = mutableAttrText
        
        // 更新当前属性以包含引用块样式
        currentAttributesBinding.wrappedValue = updatedAttributes
        
        // 计算选择范围以定位光标到引用内容的位置
        let prefixLength = blockPrefix.count + 2 // "> "的长度为2
        let contentLength = contentText.count
        
        // 如果是默认文本，将光标定位到引用内容处并选中
        if contentText == blockContentPlaceholder {
            let contentRange = NSMakeRange(selectedRange.location + prefixLength, contentLength)
            textView.selectedRange = contentRange
        } else {
            // 如果是用户选择的文本，将光标定位到引用内容后
            let endPosition = selectedRange.location + prefixLength + contentLength
            textView.selectedRange = NSMakeRange(endPosition, 0)
        }
    }
}

// 扩展ToolbarContainerView实现图片选择器代理
extension ToolbarContainerView: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        guard let textView = self.textView,
              let attributedTextBinding = self.attributedTextBinding,
              let image = info[.originalImage] as? UIImage else { return }
        
        // 调整图片大小，防止过大
        let maxWidth: CGFloat = textView.frame.width - 40
        let scaledImage = scaleImage(image, toMaxWidth: maxWidth)
        
        // 创建图片附件
        let textAttachment = NSTextAttachment()
        textAttachment.image = scaledImage
        let imageString = NSAttributedString(attachment: textAttachment)
        
        // 在当前光标位置插入图片
        let mutableAttributedText = NSMutableAttributedString(attributedString: attributedTextBinding.wrappedValue)
        let selectedRange = textView.selectedRange
        
        // 插入图片
        mutableAttributedText.replaceCharacters(in: selectedRange, with: imageString)
        
        // 添加换行
        let newLine = NSAttributedString(string: "\n")
        mutableAttributedText.insert(newLine, at: selectedRange.location + 1)
        
        // 更新文本
        attributedTextBinding.wrappedValue = mutableAttributedText
        
        // 更新光标位置
        let newPosition = selectedRange.location + 2
        textView.selectedRange = NSMakeRange(newPosition, 0)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    // 缩放图片到指定最大宽度
    private func scaleImage(_ image: UIImage, toMaxWidth maxWidth: CGFloat) -> UIImage {
        let originalSize = image.size
        
        // 如果图片宽度小于最大宽度，直接返回原图
        if originalSize.width <= maxWidth {
            return image
        }
        
        // 计算缩放比例
        let ratio = maxWidth / originalSize.width
        let newSize = CGSize(width: maxWidth, height: originalSize.height * ratio)
        
        // 重绘图片
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return scaledImage ?? image
    }
}

// 扩展UIView以查找其ViewController - 添加@objc标记
extension UIView {
    @objc func findViewController() -> UIViewController? {
        if let nextResponder = self.next as? UIViewController {
            return nextResponder
        } else if let nextResponder = self.next as? UIView {
            return nextResponder.findViewController()
        } else {
            return nil
        }
    }
}

// 为String添加正则表达式匹配扩展
extension String {
    // 匹配正则表达式并返回结果
    func match(regex pattern: String) -> RegexMatch? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        
        let nsString = self as NSString
        let range = NSRange(location: 0, length: nsString.length)
        
        guard let match = regex.firstMatch(in: self, options: [], range: range) else {
            return nil
        }
        
        return RegexMatch(match: match, string: self)
    }
}

// 封装正则表达式匹配结果
class RegexMatch {
    private let match: NSTextCheckingResult
    private let string: String
    
    init(match: NSTextCheckingResult, string: String) {
        self.match = match
        self.string = string
    }
    
    // 获取特定捕获组
    func group(at index: Int) -> String? {
        let range = match.range(at: index)
        if range.location != NSNotFound {
            return (string as NSString).substring(with: range)
        }
        return nil
    }
} 