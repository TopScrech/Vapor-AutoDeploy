import Vapor
import Fluent
    
struct Mist
{
    actor Clients
    {
        static let shared = Mist.Clients()
        
        internal var connections:
        [(
            id: UUID,
            socket: WebSocket,
            subscriptions: Set<String>,
            request: Request
        )] = []
    }
}

// connections
extension Mist.Clients
{
    // add connection to actor
    func add(connection id: UUID, socket: WebSocket, subscriptions: Set<String> = [], request: Request)
    {
        connections.append((id: id, socket: socket, subscriptions: subscriptions, request: request))
    }
    
    // remove connection from actor
    func remove(connection id: UUID)
    {
        connections.removeAll { $0.id == id }
    }
}
    
// subscriptions
extension Mist.Clients
{
    // add subscription to connection
    func addSubscription(_ model: String, for id: UUID)
    {
        // abort if client is not found
        guard let index = connections.firstIndex(where: { $0.id == id }) else { return }

        // add model to client's subscriptions
        connections[index].subscriptions.insert(model)
    }
    
    // remove subscription from connection
    func removeSubscription(_ environment: String, for id: UUID)
    {
        // abort if client is not found
        guard let index = connections.firstIndex(where: { $0.id == id }) else { return }
        
        // remove model from client's subscriptions
        connections[index].subscriptions.remove(environment)
    }
}

// broadcasting
extension Mist.Clients
{
    // send model update message to all subscribed clients
    func broadcast(_ message: Mist.Message) async
    {
        guard let jsonData = try? JSONEncoder().encode(message) else { return }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        switch message
        {
            // update messages go to subscribers
            case .modelUpdate(let model, _, _, _, _): do
            {
                // get clients that are subscribed to env
                let subscribers = connections.filter { $0.subscriptions.contains(model) }
                
                // send them the update message
                for subscriber in subscribers { Task { try? await subscriber.socket.send(jsonString) } }
            }
        
            // server cant send other mist messages
            default: return
        }
    }
}
