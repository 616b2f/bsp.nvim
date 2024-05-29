local protocol = {}

  --- Gets a new BuildClientCapabilities object describing the LSP client
  --- capabilities.
  --- @return bsp.BuildClientCapabilities
  function protocol.make_client_capabilities()
    return {
      languageIds = {
        'java',
        'csharp',
        'rust',
      }
    }
  end

local constants = {

  BuildTargetDataKinds = {
    -- `data` field must contain a CargoBuildTarget object. */
    Cargo = "cargo",
    -- `data` field must contain a CppBuildTarget object. */
    Cpp = "cpp",
    -- `data` field must contain a JvmBuildTarget object. */
    Jvm = "jvm",
    -- `data` field must contain a PythonBuildTarget object. */
    Python = "python",
    -- `data` field must contain a SbtBuildTarget object. */
    Sbt = "sbt",
    -- `data` field must contain a ScalaBuildTarget object. */
    Scala = "scala",
  },

  BuildTargetTags = {
    -- Target contains source code for producing any kind of application, may have
    -- but does not require the `canRun` capability. */
    Application = "application",
    -- Target contains source code to measure performance of a program, may have
    -- but does not require the `canRun` build target capability. */
    Benchmark = "benchmark",
    -- Target contains source code for integration testing purposes, may have
    -- but does not require the `canTest` capability.
    -- The difference between "test" and "integration-test" is that
    -- integration tests traditionally run slower compared to normal tests
    -- and require more computing resources to execute. */
    IntegrationTest = "integration-test",
    -- Target contains re-usable functionality for downstream targets. May have any
    -- combination of capabilities. */
    Library = "library",
    -- Actions on the target such as build and test should only be invoked manually
    -- and explicitly. For example, triggering a build on all targets in the workspace
    -- should by default not include this target.
    -- The original motivation to add the "manual" tag comes from a similar functionality
    -- that exists in Bazel, where targets with this tag have to be specified explicitly
    -- on the command line. */
    Manual = "manual",
    -- Target should be ignored by IDEs. */
    NoIde = "no-ide",
    -- Target contains source code for testing purposes, may have but does not
    -- require the `canTest` capability. */
    Test = "test",
  },

  TaskStartDataKind = {
    ---`data` field must contain a CompileTask object.
    CompileTask = "compile-task",
    ---`data` field must contain a TestStart object.
    TestStart = "test-start",
    ---`data` field must contain a TestTask object.
    TestTask = "test-task",
  },

  TaskFinishDataKind = {
    ---`data` field must contain a CompileReport object.
    CompileReport = "compile-report",
    ---`data` field must contain a TestFinish object.
    TestFinish = "test-finish",
    ---`data` field must contain a TestReport object.
    TestReport = "test-report",
  },

  ---@class bsp.TestStatus
  TestStatus = {
    ---The test passed successfully.
    Passed = 1,
    ---The test failed.
    Failed = 2,
    ---The test was marked as ignored.
    Ignored = 3,
    ---The test execution was cancelled.
    Cancelled = 4,
    ---The was not included in execution.
    Skipped = 5,
  },

  ---The diagnostic's severity.
  ---@enum bsp.StatusCode
  ---| 1 # Ok
  ---| 2 # Error
  ---| 3 # Canceled
  StatusCode = {
    Ok = 1,
    Error = 2,
    Cancelled = 3
  },

  ---@enum bsp.BuildTargetEventKind
  BuildTargetEventKind = {
    Created = 1,
    Changed = 2,
    Deleted = 3
  },

  ---@enum bsp.SourceItemKind
  SourceItemKind  = {
    --- The source item references a normal file.
    File = 1,
    --- The source item references a directory.
    Directory = 2,
  },

  ---@enum bsp.OutputPathItemKind
  OutputPathItemKind = {
    ---The output path item references a normal file.
    File = 1,
    ---The output path item references a directory.
    Directory = 2,
  }
}

for k, v in pairs(constants) do
  local tbl = vim.deepcopy(v)

  if vim.version().minor >= 11 then
    for kt, vt in pairs(tbl) do
      tbl[vt] = kt
    end
  else
    vim.tbl_add_reverse_lookup(tbl)
  end
  protocol[k] = tbl
end

protocol.Methods = {

  build_initialize = "build/initialize",

  build_initialized = "build/initialized",
  build_shutdown = "build/shutdown",
  build_exit = "build/exit",
  workspace_buildTargets = "workspace/buildTargets",
  workspace_reload = "workspace/reload",
  buildTarget_sources = "buildTarget/sources",
  buildTarget_inverseSources = "buildTarget/inverseSources",
  buildTarget_dependencySources = "buildTarget/dependencySources",
  buildTarget_dependencyModules = "buildTarget/dependencyModules",
  buildTarget_resources = "buildTarget/resources",
  buildTarget_outputPaths = "buildTarget/outputPaths",
  buildTarget_compile = "buildTarget/compile",
  buildTarget_run = "buildTarget/run",
  buildTarget_test = "buildTarget/test",
  buildTarget_cleanCache = "buildTarget/cleanCache",
  debugSession_start = "debugSession/start",
  run_readStdin = "run/readStdin",

  build_showMessage = "build/showMessage",
  build_logMessage = "build/logMessage",
  build_publishDiagnostics = "build/publishDiagnostics",
  buildTarget_didChange = "buildTarget/didChange",
  build_taskStart = "build/taskStart",
  build_taskProgress = "build/taskProgress",
  build_taskFinish = "build/taskFinish",
  run_printStdout = "run/printStdout",
  run_printStderr = "run/printStderr",
}

return protocol
