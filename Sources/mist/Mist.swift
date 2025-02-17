import Vapor

extension Application
{
    func useMist()
    {
        Mist.registerComponents(on: self)
        Mist.registerMistSocket(on: self)
    }
}
