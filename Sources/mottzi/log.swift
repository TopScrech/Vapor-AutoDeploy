import Foundation

// appends content at the end of file
func log(_ filePath: String, _ content: String)
{
    // create log file if it does not exist
    if !FileManager.default.fileExists(atPath: filePath) {
        FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)
    }
    
    // prepare log file
    guard let file = try? FileHandle(forWritingTo: URL(fileURLWithPath: filePath)) else { return }
    guard (try? file.seekToEnd()) != nil else { return }
    guard let data = content.data(using: .utf8) else { return }
    
    // append content
    file.write(data)
    file.closeFile()
}
