// Message types for WebSocket communication
extension Mist
{
    enum Message: Codable
    {
        case subscribe(environment: String)
        case unsubscribe(environment: String)
        case modelUpdate(environment: String, modelName: String, action: String, id: String?)
        
        private enum CodingKeys: String, CodingKey
        {
            case type
            case environment
            case modelName
            case action
            case id
        }
        
        // Custom encoding to properly format the message
        func encode(to encoder: Encoder) throws
        {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            switch self
            {
                case .subscribe(let environment):
                    try container.encode("subscribe", forKey: .type)
                    try container.encode(environment, forKey: .environment)
                    
                case .unsubscribe(let environment):
                    try container.encode("unsubscribe", forKey: .type)
                    try container.encode(environment, forKey: .environment)
                    
                case .modelUpdate(let environment, let modelName, let action, let id):
                    try container.encode("modelUpdate", forKey: .type)
                    try container.encode(environment, forKey: .environment)
                    try container.encode(modelName, forKey: .modelName)
                    try container.encode(action, forKey: .action)
                    try container.encode(id, forKey: .id)
            }
        }
        
        // Custom decoding to handle the message format
        init(from decoder: Decoder) throws
        {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            
            switch type
            {
                case "subscribe":
                    let environment = try container.decode(String.self, forKey: .environment)
                    self = .subscribe(environment: environment)
                    
                case "unsubscribe":
                    let environment = try container.decode(String.self, forKey: .environment)
                    self = .unsubscribe(environment: environment)
                    
                case "modelUpdate":
                    let environment = try container.decode(String.self, forKey: .environment)
                    let modelName = try container.decode(String.self, forKey: .modelName)
                    let action = try container.decode(String.self, forKey: .action)
                    let id = try container.decodeIfPresent(String.self, forKey: .id)
                    self = .modelUpdate(environment: environment, modelName: modelName, action: action, id: id)
                    
                default:
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: container.codingPath,
                            debugDescription: "Invalid message type"
                        )
                    )
            }
        }
    }
}
