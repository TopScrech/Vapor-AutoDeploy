import Vapor
import Fluent

protocol MistModel: Model where IDValue == UUID {}

// Extension to Model protocol to provide type-erased finder operations
extension MistModel where IDValue == UUID
{
    // Returns a closure that can find an instance of this model type by ID
    // The type erasure happens by returning a closure that captures the concrete type
    static var typedFinder: (UUID, Database) async throws -> (any Model)?
    {
        return
            { id, db in
                // Use Self to refer to the concrete model type
                return try await Self.find(id, on: db)
            }
    }
    
    // Returns a closure that can fetch all instances of this model type
    static var typedFindAll: (Database) async throws -> [any Model]
    {
        return
            { db in
                // Use Self to refer to the concrete model type
                return try await Self.query(on: db).all()
            }
    }
}

extension Mist
{
    // Simple container to hold model instances for rendering
    struct ModelContainer: Encodable
    {
        // Store models by their lowercase type name
        private var models: [String: Encodable] = [:]
        
        // Add a model instance to the container
        mutating func add<M: Model>(_ model: M?, for key: String)
        {
            if let model = model
            {
                models[key] = model
            }
        }
        
        // Special encoding implementation that flattens the models dictionary
        // This makes model properties directly accessible in Leaf templates
        func encode(to encoder: Encoder) throws
        {
            var container = encoder.container(keyedBy: StringCodingKey.self)
            
            for (key, value) in models
            {
                try container.encode(value, forKey: StringCodingKey(key))
            }
        }
    }
    
    // Helper struct for string-based coding keys
    struct StringCodingKey: CodingKey
    {
        var stringValue: String
        var intValue: Int?
        
        init(_ string: String)
        {
            self.stringValue = string
            self.intValue = nil
        }
        
        init?(stringValue: String)
        {
            self.stringValue = stringValue
            self.intValue = nil
        }
        
        init?(intValue: Int)
        {
            self.stringValue = String(intValue)
            self.intValue = intValue
        }
    }
    
    // Wrapper to maintain compatibility with existing templates
    struct EntryContext: Encodable
    {
        let entry: ModelContainer
    }
    
    // Wrapper for multiple entries
    struct EntriesContext: Encodable
    {
        let entries: [ModelContainer]
    }
}
