import Vapor
import Leaf
import Fluent
import FluentSQLiteDriver

@main
struct App {
    static func main() async throws {
        let env = try Environment.detect()
        let app = try await Application.make(env)
        
        app.environment.useVariables()
        app.views.use(.leaf)
        app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
        
        app.databases.use(.sqlite(.file("deploy/github/deployments.db")), as: .sqlite)
        app.databases.middleware.use(Deployment.Listener(), on: .sqlite)
        app.migrations.add(Deployment.Table())
        try await app.autoMigrate()
        
        app.initTestRoute()
        app.initPushWebhook()
        app.initDeployPanel()
        
        app.http.server.configuration.port = 1984
        app.http.server.configuration.hostname = "0.0.0.0" // 5.83.140.43
        
        try await app.execute()
        try await app.asyncShutdown()
    }
}
