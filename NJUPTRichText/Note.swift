import Foundation

struct Note: Identifiable, Codable {
    var id: UUID
    var title: String
    var content: String
    var attributedContent: Data? // 存储富文本数据
    var date: Date
    
    init(title: String, content: String, attributedContent: Data? = nil) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.attributedContent = attributedContent
        self.date = Date()
    }
    
    // 将NSAttributedString转换为Data
    static func encodeAttributedString(_ attributedString: NSAttributedString) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: attributedString, requiringSecureCoding: false)
    }
    
    // 将Data转换为NSAttributedString
    static func decodeAttributedString(_ data: Data) -> NSAttributedString? {
        try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? NSAttributedString
    }
} 