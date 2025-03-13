import Vapor
import Fluent

// mist uses Fluent models that use UUID as row identifier
protocol MistModel: Model where IDValue == UUID {}

// type-erased finder operations
extension MistModel
{
    // closure that can find an instance of this model type by ID
    // The type erasure happens by returning a closure that captures the concrete type
    static var modelByID: (UUID, Database) async -> (any MistModel)?
    {
        return
            { id, db in
                // Use Self to refer to the concrete model type
                return try? await Self.find(id, on: db)
            }
    }
    
    // Returns a closure that can fetch all instances of this model type
    static var modelsAll: (Database) async -> [any MistModel]?
    {
        return
            { db in
                // Use Self to refer to the concrete model type
                return try? await Self.query(on: db).all()
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
        mutating func add<M: Model>(_ model: M, for key: String)
        {
            models[key] = model
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
        
        var isEmpty: Bool { return models.isEmpty }
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
    struct SingleComponentContext: Encodable
    {
        let component: ModelContainer
    }
    
    // Wrapper for multiple entries
    struct MultipleComponentContext: Encodable
    {
        let components: [ModelContainer]
    }
}
