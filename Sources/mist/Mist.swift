import Vapor
import Fluent
import Leaf
import LeafKit

struct Mist
{
    // an env is like a chat room the clients can connect to to consume model updates
    struct Environment
    {
        // unique identifier
        let name: String
        
        // array of models this env broadcasts
        let modelTypes: [any Model.Type]
    }
    
    actor Clients
    {
        static let shared = Mist.Clients()
        
        // array of tuples
        internal var connections: [(id: UUID, socket: WebSocket, subscriptions: Set<String>, request: Request)] = []
        
        // dictionary of envs
        internal var environments: [String: Mist.Environment] = [:]
    }
}

// server websocket endpoint
extension Application
{
    func useMist()
    {
        // mottzi.de/template
        self.get("test")
        { request async throws in
            let context = Mist.DummyComponent.Context(
                property1: "lol",
                property2: 123,
                property3: .now,
                child: Mist.DummyComponent.Context.ChildContext(
                    child1: "rofl",
                    child2: 456
                )
            )
            
            return await Mist.DummyComponent().render(request: request, context: context) ?? "error: component render returned nil"
        }
        
        self.webSocket("mist", "ws")
        { request, ws async in
            
            // create new connection on upgrade
            let id = UUID()
            // add new connection to actor
            await Mist.Clients.shared.add(connection: id, socket: ws, request: request)
            
            // respond to client message
            ws.onText()
            { ws, text async in
                // abort if message is not of type Mist.Message
                guard let data = text.data(using: .utf8) else { return }
                guard let message = try? JSONDecoder().decode(Mist.Message.self, from: data) else { return }
                
                switch message
                {
                    case .subscribe(let environment): await Mist.Clients.shared.addSubscription(environment, for: id)
                    case .unsubscribe(let environment): await Mist.Clients.shared.removeSubscription(environment, for: id)
                        
                    // server does not handle other message types
                    default: break
                }
            }
            
            // remove connection from actor on close
            ws.onClose.whenComplete() { _ in Task { await Mist.Clients.shared.remove(connection: id) } }
        }
    }
}
