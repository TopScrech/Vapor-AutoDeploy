import Vapor

extension Environment
{
    enum Variables: String, CaseIterable
    {
        case GITHUB_WEBHOOK_SECRET
        
        var value: String { Environment.get(self.rawValue)! }
    }
    
    func useVariables()
    {
        for variable in Variables.allCases
        {
            if Environment.get(variable.rawValue) == nil
            {
                fatalError("\(variable.rawValue): Environment variable not found.")
            }
        }
    }
}
