import Vapor

extension Application
{
    func usePushDeploy()
    {
        // github webhook push event route
        self.push("pushevent")
        { request async in
            // valid request leads to execution of deployment process
            let commitMessage = Deployment.Pipeline.getCommitMessage(inside: request)
            await Deployment.Pipeline.initiateDeployment(message: commitMessage, on: request.db)
        }
    }
}
