import Vapor
import Fluent

extension Application
{
    func useMist()
    {
        Mist.registerComponents(on: self)
        Mist.registerMistSocket(on: self)
    }
}
