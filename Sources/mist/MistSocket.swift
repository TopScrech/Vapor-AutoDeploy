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
        
        // mottzi.de/test
        self.get("test")
        { request async throws -> View in
            let entries = try await DummyModel.all(on: request.db)
            
            struct Context: Encodable
            {
                let entries: [DummyModel]
            }
                        
            return try await request.view.render("test", Context(entries: entries))
        }
        
        self.post("dummy", "create")
        { req async throws -> DummyModel in
            
            let words = [
                "swift", "vapor", "fluent", "leaf", "websocket", "async",
                "database", "server", "client", "model", "view", "controller",
                "route", "middleware", "protocol", "actor", "request", "response"
            ]
            
            let randomWords = (0..<8).map() { _ in words.randomElement() ?? "default" }
            let randomText = randomWords.joined(separator: " ")
            
            // Create and save new dummy model
            let dummy = DummyModel(text: randomText)
            try await dummy.save(on: req.db)
            return dummy
        }
        
        // Dynamic route to create dummy entry with specific text
        self.get("dummy", "create", ":text")
        { req async throws -> DummyModel in
            guard let text = req.parameters.get("text")
            else { throw Abort(.badRequest, reason: "Text parameter is required") }
            
            // Create and save new dummy model with provided text
            let dummy = DummyModel(text: text)
            try await dummy.save(on: req.db)
            
            return dummy
        }
        
        self.webSocket("mist", "ws")
        { request, ws async in
            
            // create new connection on upgrade
            let id = UUID()
            
            // add new connection to actor
            await Mist.Clients.shared.add(connection: id, socket: ws, request: request)
            
            // receive client message
            ws.onText()
            { ws, text async in
                // abort if message is not of type Mist.Message
                guard let data = text.data(using: .utf8) else { return }
                guard let message = try? JSONDecoder().decode(Mist.Message.self, from: data) else { return }
                
                switch message
                {
                    case .subscribe(let model): await Mist.Clients.shared.addSubscription(model, for: id)
                    case .unsubscribe(let model): await Mist.Clients.shared.removeSubscription(model, for: id)
                        
                    // server does not handle other message types
                    default: return
                }
            }
            
            // remove connection from actor on close
            ws.onClose.whenComplete() { _ in Task { await Mist.Clients.shared.remove(connection: id) } }
        }
    }
}
