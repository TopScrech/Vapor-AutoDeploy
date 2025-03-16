import Vapor
import Fluent

extension Mist
{
    struct Configuration: Sendable
    {
        // database configuration
        let db: DatabaseID?
        
        // reference to application
        let app: Application
        
        // initialize with application
        init(on app: Application, db: DatabaseID? = nil)
        {
            self.app = app
            self.db = db
        }
    }
}
