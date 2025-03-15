import Vapor
import Fluent

extension Mist
{
    struct Configuration: Sendable
    {
        // Database configuration
        let db: DatabaseID?
        
        // Weak reference to application
        let app: Application
        
        // Initialize with application
        init(on app: Application, db: DatabaseID? = nil)
        {
            self.app = app
            self.db = db
        }
        
        func with(app: Application) -> Configuration
        {
            return Configuration(on: app, db: self.db)
        }
    }
}
