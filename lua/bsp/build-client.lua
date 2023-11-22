local BuildClient = {}

function BuildClient:OnBuildLogMessage(logMessageParams)
end
function BuildClient:OnBuildPublishDiagnostics(publishDiagnosticsParams)
end
function BuildClient:OnBuildShowMessage(showMessageParams)
end
function BuildClient:OnBuildTargetDidChange(didChangeBuildTarget)
end
function BuildClient:OnBuildTaskFinish(taskFinishParams)
end
function BuildClient:OnBuildTaskProgress(taskProgressParams)
end
function BuildClient:OnBuildTaskStart(taskStartParams)
end

return BuildClient
