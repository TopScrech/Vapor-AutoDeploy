import Vapor

extension Application
{
    func useDummy()
    {
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
    }
}

