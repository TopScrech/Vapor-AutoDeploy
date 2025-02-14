import Vapor

// Message types for WebSocket communication
extension Mist
{
    enum Message: Codable
    {
        case subscribe(model: String)
        case unsubscribe(model: String)
        case modelUpdate(model: String, component: String, action: String, id: UUID?, html: String)

        private enum CodingKeys: String, CodingKey
        {
            case type
            case model
            case component
            case action
            case id
            case html
        }
        
        // Custom encoding to properly format the message
        func encode(to encoder: Encoder) throws
        {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            switch self
            {
                case .subscribe(let model):
                    try container.encode("subscribe", forKey: .type)
                    try container.encode(model, forKey: .model)

                case .unsubscribe(let model):
                    try container.encode("unsubscribe", forKey: .type)
                    try container.encode(model, forKey: .model)

                case .modelUpdate(let model, let component, let action, let id, let payload):
                    try container.encode("modelUpdate", forKey: .type)
                    try container.encode(model, forKey: .model)
                    try container.encode(component, forKey: .component)
                    try container.encode(action, forKey: .action)
                    try container.encode(id, forKey: .id)
                    try container.encode(payload, forKey: .html)
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
                    let model = try container.decode(String.self, forKey: .model)
                    self = .subscribe(model: model)
                    
                case "unsubscribe":
                    let model = try container.decode(String.self, forKey: .model)
                    self = .unsubscribe(model: model)
                    
                case "modelUpdate":
                    let model = try container.decode(String.self, forKey: .model)
                    let action = try container.decode(String.self, forKey: .action)
                    let component = try container.decode(String.self, forKey: .component)
                    let id = try container.decodeIfPresent(UUID.self, forKey: .id)
                    let html = try container.decode(String.self, forKey: .html)
                    self = .modelUpdate(model: model, component: component, action: action, id: id, html: html)
                    
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
