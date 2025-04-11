import Vapor

extension Application
{
    // registers test route for demo purposes: www.mottzi.de/test
    public func initTestRoute()
    {
        self.get("test") { _ in "Test response string: Second commit" }
    }
    
    // initializes github webhook handling
    func initPushWebhook()
    {
        // github webhook push event handler
        self.push("pushevent")
        { request async in
            // valid request leads to execution of deployment process
            let commitMessage = Deployment.Pipeline.getCommitMessage(inside: request)
            await Deployment.Pipeline.initiateDeployment(message: commitMessage, on: request.db)
        }
    }
    
    // initializes deployment panel and websocket
    func initDeployPanel()
    {
        // establish websocket for clients to connect to
        self.webSocket("deployment", "ws")
        { request, ws async in
            // make client connection identifiable
            let id = UUID()
            
            // register client in broadcasting registry
            await DeploymentClients.shared.add(client: id, socket: ws)
            
            // send server welcome message
            await Deployment.Message.message("Client connected to Server").send(on: ws)
            
            // send initial full server state to client upon connecting (this is so that re-connecting clients won't operate on stale state)
            if let deployments = try? await Deployment.all(on: request.db)
            { await Deployment.Message.state(deployments).send(on: ws) }
            
            // handle incoming messages
            ws.onText() { ws, text async in await WebSocket.handleDeploymentMessage(ws, text, request) }
            
            // remove client from broadcasting registry when disconnecting
            ws.onClose.whenComplete() { _ in Task { await DeploymentClients.shared.remove(client: id) } }
        }
        
        // deployment panel route
        self.get("deployment")
        { request async throws -> View in
            // get all deployments
            let deployments = try await Deployment.all(on: request.db)
            
            // find current deployment
            let current = try await Deployment.current(on: request.db)
            
            struct Context: Encodable
            {
                let tasks: [Deployment]
                let current: Deployment?
            }
            
            // create encoded data context for templating
            let context = Context(tasks: deployments, current: current)
            
            // render the panel template using data context
            return try await request.view.render("deployment/panel", context)
        }
    }
}
