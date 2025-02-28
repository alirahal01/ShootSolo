import Foundation

struct FileNameGenerator {
    static func generateVideoFileName(takeNumber: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: Date())
        
        // Generate a short unique identifier (first 5 characters of UUID)
        let uniqueID = UUID().uuidString.prefix(5)
        
        // Format: VID_YYYYMMDD_XXXXX_TAKE1.mp4
        return "VID_\(dateString)_\(uniqueID)_TAKE\(takeNumber).mp4"
    }
    
    static func generateThumbnailFileName(videoFileName: String) -> String {
        // Replace .mp4 with .jpg for thumbnail
        return videoFileName.replacingOccurrences(of: ".mp4", with: ".jpg")
    }
} 