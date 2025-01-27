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
        let logFilePath = "deploy/github/push.log"
        
        var logContent =
        """
        =====================================================
        :::::::::::::::::::::::::::::::::::::::::::::::::::::
        Valid push event received [\(Date())]
        
        """
        
        if let commitInfo = getCommitInfo(request)
        {
            logContent += commitInfo
        }
        else { logContent += "NO COMMIT INFO" }
        
        logContent += "\n::::::::::::::::::::::::::::::::::::::::::::::::::::::"
        logContent += "\n=====================================================\n\n"
        logContent += "Auto deploy:\n\n"
        log(logFilePath, logContent)
        
        let task = DeploymentTask(status: "running")
        try? await task.save(on: request.db)
        
        do
        {
            // 1. Git Pull
            logContent = "> [1/4] Pulling repository\n\n"
            log(logFilePath, logContent)
            try await execute(command: "git pull", step: 1, logPath: logFilePath, task: task, request: request)
            
            // 2. Swift Build
            logContent = "> [2/4] Building app\n\n"
            log(logFilePath, logContent)
            try await execute(command: "/usr/local/swift/usr/bin/swift build -c debug", step: 2, logPath: logFilePath, task: task, request: request)
            
            // 3. Move Executable
            logContent = "> [3/4] Moving app .build/debug/ -> deploy/\n\n"
            log(logFilePath, logContent)
            try await moveExecutable(logPath: logFilePath, task: task, request: request)
            
            // 4. Finalize
            logContent =
            """
            > [4/4] Deployment complete - restart will be handled by Vapor
            
            ============================
            ::::::::::::::::::::::::::::
            Deployment process completed
            ::::::::::::::::::::::::::::
            ============================
            
            """
            log(logFilePath, logContent)
            
            task.status = "success"
            task.finishedAt = Date()
            try await task.save(on: request.db)
            
            try await restartService(request: request)
            
        } catch {
            let errorMessage = """
        \n=======================
        :::::::::::::::::::::::::
        Deployment process failed
        Error: \(error.localizedDescription)
        :::::::::::::::::::::::::
        =========================\n\n
        """
            log(logFilePath, errorMessage)
            
            task.status = "failed"
            task.log += errorMessage
            task.finishedAt = Date()
            try? await task.save(on: request.db)
            return
        }
    }
    
    private func execute(command: String, step: Int, logPath: String, task: DeploymentTask, request: Request) async throws
    {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["bash", "-c", command]
        process.currentDirectoryURL = URL(fileURLWithPath: "/var/www/mottzi")
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = try outputPipe.fileHandleForReading.readToEnd()
        let output = String(data: outputData ?? Data(), encoding: .utf8) ?? ""
        
        // Update both file log and database
        log(logPath, output)
        task.log += "\n$ \(command)\n\(output)"
        try await task.save(on: request.db)
        
        guard process.terminationStatus == 0 else
        {
            throw NSError(domain: "DeploymentError", code: step, userInfo: [NSLocalizedDescriptionKey: "Command failed: \(command)\n\(output)"])
        }
    }
    
    private func restartService(request: Request) async throws
    {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["supervisorctl", "restart", "mottzi"]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else
        {
            throw Abort(.internalServerError, reason: "Failed to restart service")
        }
    }
    
    private func getCommitInfo(_ request: Request) -> String?
    {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        guard let bodyString = request.body.string,
              let jsonData = bodyString.data(using: .utf8),
              let payload = try? decoder.decode(GitHubEvent.Payload.self, from: jsonData)
        else { return nil }
        
        var commitInfo =
        """
        Commit:  \(payload.headCommit.id)
        Author:  \(payload.headCommit.author.name)
        Message: \(payload.headCommit.message)
        """
        
        if !payload.headCommit.modified.isEmpty
        {
            commitInfo +=
            """
            \n\nChanged (\(payload.headCommit.modified.count)): 
                - \(payload.headCommit.modified.joined(separator: ",\n        - "))
            """
        }
        
        return commitInfo
    }

    private func moveExecutable(logPath: String, task: DeploymentTask, request: Request) async throws
    {
        let fileManager = FileManager.default
        let buildPath = "/var/www/mottzi/.build/debug/App"
        let deployPath = "/var/www/mottzi/deploy/App"
        
        do
        {
            try fileManager.createDirectory(atPath: "/var/www/mottzi/deploy", withIntermediateDirectories: true)
            
            if fileManager.fileExists(atPath: deployPath)
            {
                try fileManager.removeItem(atPath: deployPath)
            }
            
            try fileManager.moveItem(atPath: buildPath, toPath: deployPath)
            
            // Log success
//            let successMessage = "Successfully moved executable to deploy directory\n"
//            log(logPath, successMessage)
//            task.log += successMessage
//            try await task.save(on: request.db)
        }
        catch
        {
            let errorMessage = "Failed to move executable: \(error.localizedDescription)\n"
            log(logPath, errorMessage)
            throw error
        }
    }
}
