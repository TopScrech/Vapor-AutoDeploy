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

    struct Component<Model: Fluent.Model>
    {
        // unique identifier
        let name: String
        // leaf template
        let template: String
        // environment this component belongs to
        let environments: String
        
        func render(request: Request) async -> String?
        {
            var view: View
            var body: String?
            
            do
            {
                view = try await request.view.render(self.template, ["hi":"hi"])
                body = try await view.encodeResponse(status: .accepted, for: request).body.string
            }
            catch
            {
                return nil
            }
            
            return body
        }
    }
    
    actor Clients
    {
        static let shared = Mist.Clients()
        
        // MARK: - Properties
        
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
