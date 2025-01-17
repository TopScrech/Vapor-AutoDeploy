import Vapor

// appends content at the end of file
func log(_ filePath: String, _ content: String)
{
    // vapor logger
    let logger = Logger(label: "mottzi")
    
    // create log file if it does not exist
    if !FileManager.default.fileExists(atPath: filePath) {
        FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)
    }
    
    guard let data = content.data(using: .utf8) else { return logger.debug("tried logging empty data") }

    do
    {
        // go to end of log file
        let file = try FileHandle(forWritingTo: URL(fileURLWithPath: filePath))
        try file.seekToEnd()
        
        // write content to log file
        file.write(data)
        file.closeFile()
    }
    catch
    {
        logger.error("\(error.localizedDescription)")
    }
}
