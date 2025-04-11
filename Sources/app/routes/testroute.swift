import Vapor
import Leaf
import LeafKit

extension Application
{
    // registers test route for demo purposes: www.mottzi.de/test
    public func useRoutes()
    {
        self.get("test") { _ in "Test response string: 2" }
    }
}
