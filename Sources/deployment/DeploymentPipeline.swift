import Vapor
import Fluent

extension Deployment
{
    /// Handles deployment process execution (pull, build, queue check, restart).
    /// Ensures chronological execution by re-running latest canceled commit after successfull deployments.
    struct Pipeline
    {
        /// Creates and processes a new `Deployment`. After successfull deployment, this will check for previously
        /// cancelled deployments and re-runs the latest one found.
        ///
        /// - Parameter message: The commit message of this deployment
        /// - Note: This is called when a valid GitHub pushevent is received.
        public static func initiateDeployment(message: String?, on database: Database) async
        {
            await internalDeployment(existingDeployment: nil, message: message, on: database)
        }
        
        /// Re-runs an existing `Deployment`.
        ///
        /// - Parameter deployment: Deployment to re-run
        /// - Note: This is called on the latest cancelled deployment whenever any deployment finishes successfully.
        private static func rerunDeployment(deployment: Deployment, on database: Database) async
        {
            await internalDeployment(existingDeployment: deployment, message: nil, on: database)
        }
        
        /// Internal recursive deployment pipeline. It can re-process exisiting deployments or create and process new deployments.
        ///
        /// - Parameters:
        ///   - existingDeployment: Pass a deployment to re-run it.
        ///   - message: Pass a commit message for newly created deployments.
        private static func internalDeployment(existingDeployment: Deployment?, message: String?, on database: Database) async
        {
            // make sure deployment pipeline is not already busy
            let canDeploy = await Deployment.Pipeline.Manager.shared.requestDeployment()
            
            // local deployment
            let deployment: Deployment
            
            // re-run of previously canceled deployment
            if let existingDeployment
            {
                // this function was called at the end of a previous deployment
                deployment = existingDeployment
                
                // reset start time for canceled deployment
                deployment.startedAt = Date.now
                
                // pipline status determines this deployment
                deployment.status = canDeploy ? "running" : "canceled"
            }
            // original deployment triggered by push event
            else
            {
                // create new deployment entry
                deployment = Deployment(status: canDeploy ? "running" : "canceled", message: message ?? "")
            }
            
            // save newly created deployment or update re-running deployment
            try? await deployment.save(on: database)
            
            // abort deployment if pipeline is busy
            guard canDeploy else { return }
            
            //  pipeline:
            do
            {
                // 1: git pull
                try await execute("git pull", step: 1)
                
                // 2: swift build
                try await execute("swift build -c debug", step: 2)
                
                // 3: move executable
                try await moveExecutable()
                
                // success: update deployment entry
                deployment.status = "success"
                deployment.finishedAt = Date()
                try? await deployment.save(on: database)
                
                // unlock deployment pipeline
                await Deployment.Pipeline.Manager.shared.endDeployment()
                
                // check for deployments that were canceled in the meantime
                if let latestCanceled = try await Deployment.query(on: database)
                    .filter(\.$status, .equal, "canceled")
                    .filter(\.$startedAt, .greaterThan, deployment.startedAt)
                    .sort(\.$startedAt, .descending)
                    .first()
                {
                    // re-run latest canceled deployment
                    await rerunDeployment(deployment: latestCanceled, on: database)
                }
                else
                {
                    // set this deployment as current
                    try await deployment.setCurrent(on: database)
                    
                    // restart app with this deployment
                    try await restart()
                }
            }
            catch
            {
                // failure: update deployment entry
                deployment.status = "failed"
                deployment.finishedAt = Date()
                try? await deployment.save(on: database)
                
                // unlock deployment pipeline
                await Deployment.Pipeline.Manager.shared.endDeployment()
            }
        }
    }
}

extension Deployment.Pipeline
{
    // Serializes deployment processes through actor isolation.
    actor Manager
    {
        // singleton instance for deployment coordination
        static let shared = Manager()
        
        // deployment status
        private(set) var isDeploying: Bool = false
        
        // attempt to acquire deployment lock
        func requestDeployment() async -> Bool
        {
            if isDeploying { return false }
            else { isDeploying = true; return true}
        }
        
        // release deployment lock for new operations
        func endDeployment() async { isDeploying = false }
    }
}

// auto deploy commands
extension Deployment.Pipeline
{
    private static func execute(_ command: String, step: Int) async throws
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
        
        if process.terminationStatus != 0
        {
            // why use NSError here specifically? error?
            throw NSError(domain: "DeploymentError", code: step, userInfo: [NSLocalizedDescriptionKey: "Command failed: \(command)"])
        }
    }
    
    private static func restart() async throws
    {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["supervisorctl", "restart", "mottzi"]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0
        {
            throw Abort(.internalServerError, reason: "Failed to restart service")
        }
    }
    
    public static func getCommitMessage(inside request: Request) -> String?
    {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        guard let bodyString = request.body.string,
              let jsonData = bodyString.data(using: .utf8),
              let payload = try? decoder.decode(DeploymentWebhook.Payload.self, from: jsonData)
        else { return nil }
        
        return payload.headCommit.message
    }
    
    private static func moveExecutable() async throws
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
        }
        catch
        {
            throw error
        }
    }
}
