import Vapor

extension Application
{
    func usePushDeploy()
    {
        // github webhook push event route
        self.push("pushevent")
        { request async in
            // valid request leads to execution of deployment process
            let commitMessage = DeploymentPipeline.getCommitMessage(request)
            await DeploymentPipeline.initiateDeployment(message: commitMessage, on: request.db)
        }
    }
}
