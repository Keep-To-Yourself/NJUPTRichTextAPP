import SwiftUI
import UIKit

struct NoteDetailView: View {
    @ObservedObject var viewModel: NoteViewModel
    @Environment(\.presentationMode) var presentationMode
    let noteIndex: Int
    @State private var editedTitle: String
    @State private var editedContent: String
    @State private var attributedContent: NSAttributedString
    @State private var isEditing: Bool = false
    @State private var textView: UITextView?
    @State private var keyboardToolbarContainer: ToolbarContainerView?
    @State private var currentAttributes = RichTextFormatting.TextAttributes()
    
    init(viewModel: NoteViewModel, noteIndex: Int) {
        self.viewModel = viewModel
        self.noteIndex = noteIndex
        self._editedTitle = State(initialValue: viewModel.notes[noteIndex].title)
        self._editedContent = State(initialValue: viewModel.notes[noteIndex].content)
        
        // 初始化富文本内容
        let initialAttributedContent: NSAttributedString
        if let data = viewModel.notes[noteIndex].attributedContent,
           let decoded = Note.decodeAttributedString(data) {
            initialAttributedContent = decoded
        } else {
            initialAttributedContent = NSAttributedString(string: viewModel.notes[noteIndex].content)
        }
        self._attributedContent = State(initialValue: initialAttributedContent)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题输入框
            TextField("笔记标题", text: $editedTitle)
                .font(.headline)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(isEditing ? Color(UIColor.systemGray6) : Color.clear)
                .cornerRadius(isEditing ? 8 : 0)
                .onTapGesture {
                    if !isEditing {
                        isEditing = true
                    }
                }
            
            // 富文本编辑器
            RichTextEditor(attributedText: $attributedContent, isEditable: true, currentAttributes: $currentAttributes)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        setupToolbar()
                    }
                }
                .onTapGesture {
                    if !isEditing {
                        isEditing = true
                    }
                }
        }
        .navigationBarTitle("", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("完成") {
                        endEditing()
                    }
                }
            }
        }
        .onDisappear {
            if isEditing {
                saveNote()
            }
        }
    }
    
    private func setupToolbar() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        // 查找 UITextView
        func findTextView(in view: UIView) -> UITextView? {
            if let textView = view as? UITextView {
                return textView
            }
            for subview in view.subviews {
                if let found = findTextView(in: subview) {
                    return found
                }
            }
            return nil
        }
        
        // 设置工具栏
        if let textView = findTextView(in: window) {
            self.textView = textView
            
            // 确保移除旧的工具栏
            textView.inputAccessoryView = nil
            
            // 创建工具栏容器
            let toolbarContainer = ToolbarContainerView(frame: .zero)
            self.keyboardToolbarContainer = toolbarContainer
            
            // 设置工具栏
            toolbarContainer.setup(attributedText: $attributedContent, currentAttributes: $currentAttributes, textView: textView)
            
            // 强制重新加载输入视图
            textView.reloadInputViews()
            print("工具栏已设置，宽度: \(textView.inputAccessoryView?.frame.width ?? 0)")
        } else {
            print("未找到TextEditor的UITextView")
        }
    }
    
    private func endEditing() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), 
                                     to: nil, 
                                     from: nil, 
                                     for: nil)
        saveNote()
        isEditing = false
    }
    
    private func saveNote() {
        let plainText = attributedContent.string
        let attributedData = Note.encodeAttributedString(attributedContent)
        
        viewModel.updateNote(
            at: noteIndex,
            title: editedTitle,
            content: plainText,
            attributedContent: attributedData
        )
    }
} 