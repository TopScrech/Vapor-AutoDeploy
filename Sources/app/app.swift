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
        //try LoggingSystem.bootstrap(from: &env)
        LoggingSystem.bootstrap(fragment: customLoggerFragment(), console: Terminal(), level: try Logger.Level.detect(from: &env))
        func customLoggerFragment() -> some LoggerFragment {
            LabelFragment().maxLevel(.trace)
                .and(LevelFragment().separated(" ").and(MessageFragment().separated(" ")))
                .and(MetadataFragment().separated(" "))
                .and(SourceLocationFragment().separated(" ").maxLevel(.info))
        }
        
        let app = try await Application.make(env)
        app.environment.useVariables()
        app.databases.use(.sqlite(.file("deploy/github/deployments.db")), as: .sqlite)
        app.databases.middleware.use(DeploymentListener(), on: .sqlite)
        app.migrations.add(Deployment.Table())
        try await app.autoMigrate()
        
        app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
        app.views.use(.leaf)
        app.useRoutes()
        app.usePushDeploy()
        app.useDeployPanel()
        
        try await app.execute()
        try await app.asyncShutdown()
    }
}
