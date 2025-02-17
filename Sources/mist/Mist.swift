import Vapor

extension Application
{
    func useMist()
    {
        Mist.registerMistSocket(on: self)
    }
}
