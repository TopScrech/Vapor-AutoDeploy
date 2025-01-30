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
        app.migrations.add(Deployment.Table2())
        try await app.autoMigrate()

        let corsConfiguration = CORSMiddleware.Configuration(
            allowedOrigin: .all,
            allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
            allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
        )
        let cors = CORSMiddleware(configuration: corsConfiguration)
        // cors middleware should come before default error middleware using `at: .beginning`
        app.middleware.use(cors, at: .beginning)
        
        app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
        app.views.use(.leaf)
        app.useRoutes()
        app.usePushEvents()
        app.useAdminPanel()
        
        try await app.execute()
        try await app.asyncShutdown()
    }
}
