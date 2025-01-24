import Vapor
import Leaf

@main
struct mottzi
{
    static func main() async throws
    {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)

        let app = try await Application.make(env)
        app.views.use(.leaf)
        app.useRoutes()
        
        try await app.execute()
        try await app.asyncShutdown()
    }
}

extension Application
{
    func handlePushEvent(_ request: Request) async
    {
        let process = Process()
        process.currentDirectoryURL = URL(fileURLWithPath: "/var/www/mottzi")
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/testscript")
        process.arguments = ["deploy"]
        
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = "/var/www/mottzi"
        process.environment = environment
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        // log the initial message
        log("deploy/github/push.log", "Auto deploy:\n\n")
        
        // read the output as an async stream
        pipe.fileHandleForReading.readabilityHandler =
        { stream in
            // load chunk of output data
            let data = stream.availableData
            
            // stop reading when end of file is reached
            if data.isEmpty
            {
                stream.readabilityHandler = nil
                return
            }
            
            // log data chunk to file
            if let chunk = String(data: data, encoding: .utf8)
            {
                log("deploy/github/push.log", chunk)
            }
        }
        
        do
        {
            // run the processs
            try process.run()
        }
        catch
        {
            log("deploy/github/push.log",
            """
            \n=======================
            :::::::::::::::::::::::::
            Deployment process failed
            Error: \(error.localizedDescription)
            :::::::::::::::::::::::::
            =========================\n\n
            """)
        }
    }
}
