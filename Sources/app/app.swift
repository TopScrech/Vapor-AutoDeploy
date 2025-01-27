import Vapor
import Fluent
import FluentSQLiteDriver
import Leaf

@main
struct mottzi
{
    static func main() async throws
    {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)

        let app = try await Application.make(env)
        
        app.databases.use(.sqlite(.file("deploy/github/deployments.db")), as: .sqlite)
        app.migrations.add(CreateDeploymentTask())
        try await app.autoMigrate()
        
        app.views.use(.leaf)
        app.useRoutes()
        
        try await app.execute()
        try await app.asyncShutdown()
    }
}

extension Application
{
    // handle valid push event
    func handlePushEvent(_ request: Request) async
    {
        let task = DeploymentTask(status: "running")
        try? await task.save(on: request.db)
        
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
            process.waitUntilExit()
            
            task.status = process.terminationStatus == 0 ? "success" : "failed"
            task.finishedAt = Date()
            request.logger.debug("try to update sqllite Succes/Failure for #\(task.id?.uuidString ?? "unknown")")
            try await task.save(on: request.db)
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
            
            task.status = "failed"
            task.finishedAt = Date()
            try? await task.save(on: request.db)
        }
    }
}
