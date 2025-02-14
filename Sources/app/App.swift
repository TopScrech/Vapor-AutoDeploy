import Vapor
import Fluent
import FluentSQLiteDriver
import Leaf

@main
struct App
{
    static func main() async throws
    {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)

        let app = try await Application.make(env)
        
        app.logger = Logger(label: "mottzi")
        {
            let format = LevelFragment().separated(" ")
                .and(MessageFragment().separated(" "))
                .and(MetadataFragment().separated(" "))
                .and(SourceLocationFragment().separated(" "))
            
            return ConsoleFragmentLogger(fragment: format, label: $0, console: Terminal(), level: .info)
        }
        
        app.useMist()
                
        app.environment.useVariables()
        app.databases.use(.sqlite(.file("deploy/github/deployments.db")), as: .sqlite)
        app.databases.middleware.use(Deployment.Listener(), on: .sqlite)
//        app.migrations.add(Deployment.Table())
        app.migrations.add(DummyModel.Table2())
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
