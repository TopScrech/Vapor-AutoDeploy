import Vapor
import Leaf

@main
struct mottzi
{
    static func main() async throws
    {
        var env = try Environment.detect()
        
        let app = try await Application.make(env)
        app.views.use(.leaf)
        app.configureRoutes()
        
        try LoggingSystem.bootstrap(from: &env)
        
        try await app.execute()
        try await app.asyncShutdown()
    }
}

// Routes
extension Application
{
    // the web server will respond to these following http requests
    func configureRoutes()
    {
        // set up github push event webhook handler
        self.github("pushevent", event: .push)
        { request async in
            await self.handlePushEvent(request)
        }
                
        // mottzi.de/text
        self.get("text")
        { req throws in
            """
            Speckgürtel
            oöp
            """
        }

        // mottzi.de/dynamic/worldd
        self.get("dynamic", ":property")
        { request async in
            request.logger.error("TestError here")
            return "Hello, \(request.parameters.get("property")!)!"
        }
        
        // mottzi.de/infile
        self.get("infile")
        { request async throws in
            try await request.view.render("htmlFile")
        }
        
        // mottzi.de/inline
        self.get("inline")
        { _ in
            let response = Response(status: .ok)
            response.headers.contentType = .html
            response.body = .init(stringLiteral:
            """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <title>Index Page</title>
            </head>
            <body>
                <h1>inline</h1>
                <p>This html page is defined in the route definition.</p>
            </body>
            </html>
            """)
            
            return response
        }
    }
    
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
        
        // log the initial messagee
        self.log("deploy/github/push.log",
        """
        ====================================
        ::::::::::::::::::::::::::::::::::::
        Attempting to run auto deploy script
        ::::::::::::::::::::::::::::::::::::
        ====================================\n\n
        """)
        
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
                self.log("deploy/github/push.log", chunk)
            }
        }
        
        do
        {
            // run the processs
            try process.run()
        }
        catch
        {
            self.log("deploy/github/push.log",
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
