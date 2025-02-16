import Vapor
import Fluent
import Leaf
import LeafKit

// server websocket endpoint
extension Application
{
    func useMist()
    {
        Mist.configureComponents(self)
        
        // mottzi.de/dummy
        self.get("dummies")
        { request async throws -> View in
            
            let entries = try await DummyModel.all(on: request.db)
            
            struct Context: Encodable
            {
                let entries: [DummyModel]
            }
                        
            return try await request.view.render("DummyState", Context(entries: entries))
        }
        
        self.get("dummies", "update", ":id", ":text")
        { req async throws -> HTTPStatus in
            
            guard let idString = req.parameters.get("id"),
                  let id = UUID(uuidString: idString)
            else
            {
                throw Abort(.badRequest, reason: "Valid UUID parameter is required")
            }
            
            guard let text = req.parameters.get("text")
            else
            {
                throw Abort(.badRequest, reason: "Valid text parameter is required")
            }
            
            guard let dummy = try await DummyModel.find(id, on: req.db)
            else
            {
                throw Abort(.notFound, reason: "DummyModel with specified ID not found")
            }
            
            dummy.text = text
            try await dummy.save(on: req.db)
            
            return .ok
        }
        
        self.get("dummies", "delete", ":id")
        { req async throws -> HTTPStatus in
            
            guard let idString = req.parameters.get("id"),
                  let id = UUID(uuidString: idString)
            else
            {
                throw Abort(.badRequest, reason: "Valid UUID parameter is required")
            }
            
            guard let dummy = try await DummyModel.find(id, on: req.db)
            else
            {
                throw Abort(.notFound, reason: "DummyModel with specified ID not found")
            }
            
            try await dummy.delete(on: req.db)
            return .ok
        }
        
        self.get("dummies", "deleteAll")
        { req async throws -> HTTPStatus in
            try await DummyModel.query(on: req.db).delete()
            return .ok
        }
        
        self.get("dummies", "create")
        { req async throws -> DummyModel in
            
            let randomWord =
            [
                "swift", "vapor", "fluent", "leaf", "websocket", "async",
                "database", "server", "client", "model", "view", "controller",
                "route", "middleware", "protocol", "actor", "request", "response"
            ]
            .randomElement() ?? "error"
            
            // create and save new dummy db entry with provided text
            let dummy = DummyModel(text: randomWord)
            try await dummy.save(on: req.db)
            
            // retrun json encoded http response of created db entry
            return dummy
        }
        
        // Dynamic route to create dummy entry with specific text
        self.get("dummies", "create", ":text")
        { req async throws -> DummyModel in
            
            // validate input parameter
            guard let text = req.parameters.get("text") else { throw Abort(.badRequest, reason: "Text parameter is required") }
            
            // create and save new dummy db entry with provided text
            let dummy = DummyModel(text: text)
            try await dummy.save(on: req.db)
            
            // retrun json encoded http response of created db entry
            return dummy
        }
        
        self.webSocket("mist", "ws")
        { request, ws async in
            
            // create new connection on upgrade
            let id = UUID()
            
            // add new connection to actor
            await Mist.Clients.shared.add(connection: id, socket: ws)
            
            try? await ws.send("{ \"msg\": \"Server Welcome Message\" }")
            
            // receive client message
            ws.onText()
            { ws, text async in
                
                // abort if message is not of type Mist.Message
                guard let data = text.data(using: .utf8) else { return }
                guard let message = try? JSONDecoder().decode(Mist.Message.self, from: data) else { return }
                
                switch message
                {
                    case .subscribe(let component): do
                    {
                        await Mist.Clients.shared.addSubscription(component, for: id)
                        
                        try? await ws.send("{ \"msg\": \"Subscribed to \(component)\" }")
                    }
                        
                    case .unsubscribe(let component): do
                    {
                        await Mist.Clients.shared.removeSubscription(component, for: id)
                        
                        try? await ws.send("{ \"msg\": \"Unsubscribed to \(component)\" }")
                    }
                        
                    // server does not handle other message types
                    default: return
                }
            }
            
            // remove connection from actor on close
            ws.onClose.whenComplete() { _ in Task { await Mist.Clients.shared.remove(connection: id) } }
        }
    }
}

extension Mist
{
    static func configureComponents(_ app: Application)
    {
        Task
        {
            await Components.shared.configure(renderer: app.leaf.renderer)
            await Components.shared.register(DummyRow.self)
        }
    }
}
