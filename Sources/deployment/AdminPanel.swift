import Vapor

extension Application
{
    func useAdminPanel()
    {
        self.webSocket("admin", "ws")
        { req, ws async in
            try? await ws.send("Client-Server-Connection established")
            
            // echo received message back to client
            ws.onText
            { ws, text in
                try? await ws.send("Server received: \(text)")
            }
            
            ws.onClose.whenComplete
            { _ in
                print("Client disconnected")
            }
        }
        
//        self.webSocket("admin", "ws")
//        { req, ws in
//            print("Client connected")
//            ws.send("Client-Server-Connection established")
//            
//            // echo received message back to client
//            ws.onText
//            { ws, text in
//                ws.send("Server received: \(text)")
//            }
//            
//            ws.onClose.whenComplete
//            { _ in
//                print("Client disconnected")
//            }
//        }
        
        // mottzi.de/admin
        self.get("admin")
        { request async throws -> View in
            let deployments = try await Deployment
                .query(on: request.db)
                .sort(\.$startedAt, .descending)
                .all()
            
            return try await request.view.render("deployment/panel", ["tasks": deployments])
        }

        // mottzi.de/admin/deployments
        self.get("admin", "deployments")
        { request async throws -> [Deployment] in
            try await Deployment.query(on: request.db).all()
        }

        // mottzi.de/admin/deployments/UUID....
        self.get("admin", "deployments", ":id")
        { request async throws -> Deployment in
            guard let deployment = try await Deployment.find(request.parameters.get("id"), on: request.db)
            else { throw Abort(.notFound) }
            
            return deployment
        }
    }
}
