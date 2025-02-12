import Vapor
import Fluent

extension Mist.Clients
{
    // MARK: - Environment Management
    
    // add env to actor dictionary
    func registerEnvironment(_ environment: Mist.Environment)
    {
        environments[environment.name] = environment
    }
    
    // remove env from actor dictionary
    func unregisterEnvironment(name: String)
    {
        environments.removeValue(forKey: name)
    }
    
    // get env from name
    func getEnvironment(name: String) -> Mist.Environment?
    {
        return environments[name]
    }
}
    
extension Mist.Clients
{
    // MARK: - Connection Management
    
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
    
extension Mist.Clients
{
    // MARK: - Subscription Management
    
    // add subscription to connection
    func addSubscription(_ environment: String, for id: UUID)
    {
        // find connection by id
        guard let index = connections.firstIndex(where: { $0.id == id }) else { return }
        // abort if env is not registered
        guard environments[environment] != nil else { return } 
        // add env to connection's subscriptions
        connections[index].subscriptions.insert(environment)
    }
    
    // remove subscription from connection
    func removeSubscription(_ environment: String, for id: UUID)
    {
        // find connection by id
        guard let index = connections.firstIndex(where: { $0.id == id }) else { return }
        // remove env from connection's subscriptions
        connections[index].subscriptions.remove(environment)
    }
}
    
extension Mist.Clients
{
    // MARK: - Messaging
    
    // server send message to all subscribed clients
    func broadcast(_ message: Mist.Message) async
    {
        guard let jsonData = try? JSONEncoder().encode(message) else { return }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        switch message
        {
            // update messages go to subscribers
            case .modelUpdate(let environment, _, _, _): do
            {
                // get clients that are subscribed to env
                let subscribers = connections.filter { $0.subscriptions.contains(environment) }
                // send them the update message
                for subscriber in subscribers { Task { try? await subscriber.socket.send(jsonString) } }
            }
        
            // server cant send other mist messages
            default: break
        }
    }
}
