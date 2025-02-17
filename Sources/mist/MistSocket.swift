import Vapor
import Fluent
import Leaf
import LeafKit

extension Mist
{
    static func registerMistSocket(on app: Application)
    {
        app.webSocket("mist", "ws")
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
