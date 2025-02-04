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
        
//        let fragment = LabelFragment().maxLevel(.trace)
//            .and(LevelFragment().separated(" ")
//            .and(MessageFragment().separated(" ")))
//            .and(MetadataFragment().separated(" "))
//            .and(SourceLocationFragment().separated(" ").maxLevel(.info))
//        
//        LoggingSystem.bootstrap(fragment: fragment, console: Terminal(), level: try Logger.Level.detect(from: &env))
        
        let app = try await Application.make(env)
        
        try LoggingSystem.bootstrap(from: &env)
        
        let fragment = LabelFragment().maxLevel(.trace)
            .and(LevelFragment().separated(" ")
            .and(MessageFragment().separated(" ")))
            .and(MetadataFragment().separated(" "))
            .and(SourceLocationFragment().separated(" ").maxLevel(.info))
        
        app.logger = .init(label: "app")
        {
            ConsoleFragmentLogger(fragment: fragment, label: $0, console: Terminal())
        }
        
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
