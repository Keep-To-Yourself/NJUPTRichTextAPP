import SwiftUI
import UIKit

// 标题选择器控制器 - 将SwiftUI视图嵌入UIKit
class HeaderStylePickerController: UIViewController {
    // 关闭回调
    var onDismiss: (() -> Void)?
    
    // SwiftUI托管控制器
    private var hostingController: UIHostingController<HeaderPicker>?
    
    // 背景视图
    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        view.alpha = 0
        
        // 添加点击手势以关闭选择器
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissPicker))
        view.addGestureRecognizer(tapGesture)
        
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }
    
    // 显示选择器
    func showPicker(above anchorView: UIView, attributedText: Binding<NSAttributedString>, currentAttributes: Binding<RichTextFormatting.TextAttributes>, textView: UITextView) {
        // 添加背景视图
        backgroundView.frame = view.bounds
        view.addSubview(backgroundView)
        
        // 创建HeaderPicker SwiftUI视图
        let headerPicker = HeaderPicker(
            attributedText: attributedText,
            currentAttributes: currentAttributes,
            textView: textView,
            onDismiss: { [weak self] in
                self?.dismissPicker()
            }
        )
        
        // 创建托管控制器
        let hostingController = UIHostingController(rootView: headerPicker)
        self.hostingController = hostingController
        
        // 配置托管控制器视图
        hostingController.view.backgroundColor = .systemBackground
        hostingController.view.layer.cornerRadius = 12
        hostingController.view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        hostingController.view.clipsToBounds = true
        
        // 添加托管控制器
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        // 获取anchorView在屏幕中的位置
        let anchorRect = anchorView.convert(anchorView.bounds, to: nil)
        
        // 设置选择器的高度 - 减小高度以适应横向布局
        let pickerHeight: CGFloat = 160
        
        // 确保选择器宽度与屏幕宽度一致
        let pickerWidth = view.bounds.width
        
        // 获取anchorView的顶部位置
        let anchorTopY = anchorRect.minY
        
        // 初始位置（在屏幕下方）
        hostingController.view.frame = CGRect(
            x: 0,
            y: view.bounds.height,
            width: pickerWidth,
            height: pickerHeight
        )
        
        // 使用动画显示选择器
        UIView.animate(withDuration: 0.3) {
            // 移动选择器到工具栏正上方
            hostingController.view.frame.origin.y = anchorTopY - pickerHeight
            
            // 显示背景
            self.backgroundView.alpha = 1
        }
        
        // 调试信息
        print("Anchor top position: \(anchorTopY)")
        print("Picker position: \(anchorTopY - pickerHeight)")
    }
    
    // 关闭选择器
    @objc func dismissPicker() {
        guard let hostingController = self.hostingController else { return }
        
        UIView.animate(withDuration: 0.3, animations: {
            // 移动选择器到屏幕外
            hostingController.view.frame.origin.y = self.view.bounds.height
            
            // 隐藏背景
            self.backgroundView.alpha = 0
        }) { _ in
            // 移除视图控制器
            hostingController.willMove(toParent: nil)
            hostingController.view.removeFromSuperview()
            hostingController.removeFromParent()
            self.hostingController = nil
            
            // 移除背景
            self.backgroundView.removeFromSuperview()
            
            // 移除自己
            self.willMove(toParent: nil)
            self.view.removeFromSuperview()
            self.removeFromParent()
            
            // 调用关闭回调
            self.onDismiss?()
        }
    }
} 