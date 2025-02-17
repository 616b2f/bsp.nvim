---@meta
error('Cannot require a meta file')

---@class bsp.BspConnectionDetails
---The name of the build tool.
---@field name string
---The version of the build tool.
---@field version string
---The bsp version of the build tool.
---@field bspVersion string
---A collection of languages supported by this BSP server.
---@field languages string[]
---Command arguments runnable via system processes to start a BSP server
---@field argv string[]

---@class bsp.InitializeBuildParams
---Name of the client
---@field displayName string
---The version of the client
---@field version string
---The BSP version that the client speaks
---@field bspVersion string
---The rootUri of the workspace
---@field rootUri URI
---The capabilities of the client
---@field capabilities bsp.BuildClientCapabilities
---Kind of data to expect in the `data` field. If this field is not set, the kind of data is not specified.
---@field dataKind? bsp.InitializeBuildParamsDataKind
---Additional metadata about the client
---@field data? bsp.InitializeBuildParamsData

---@alias bsp.InitializeBuildParamsDataKind string

---@alias bsp.InitializeBuildParamsData any

---@class bsp.InitializeBuildResult
---Name of the server
---@field displayName string
---The version of the server
---@field version string
---The BSP version that the server speaks
---@field bspVersion string
---The capabilities of the build server
---@field capabilities bsp.BuildServerCapabilities
---Kind of data to expect in the `data` field. If this field is not set, the kind of data is not specified.
---@field dataKind? bsp.InitializeBuildResultDataKind
---Additional metadata about the server
---@field data? bsp.InitializeBuildResultData

---@alias bsp.InitializeBuildResultDataKind string

---@alias bsp.InitializeBuildResultData any

---@alias bsp-handler fun(err: bp.ResponseError|nil, result: any, context: bsp.HandlerContext, config: table|nil): any?

---@class bsp.HandlerContext
---@field method string
---@field client_id integer
---@field bufnr? integer
---@field params? any

---@class bsp.TaskStartParams {
---Unique id of the task with optional reference to parent task id
---@field taskId bsp.TaskId
---A unique identifier generated by the client to identify this request.
---@field originId? bsp.Identifier
---Timestamp of when the event started in milliseconds since Epoch.
---@field eventTime? integer
---Message describing the task.
---@field message? string
---Kind of data to expect in the `data` field. If this field is not set, the kind of data is not specified.
---@field dataKind? bsp.TaskStartDataKind
---Optional metadata about the task.
---Objects for specific tasks like compile, test, etc are specified in the protocol.
---@field data? bsp.TaskStartData

---@alias bsp.TaskStartData any

---@alias bsp.TaskStartDataKind string

---@class bsp.TaskProgressParams
---Unique id of the task with optional reference to parent task id
---@field taskId bsp.TaskId
---A unique identifier generated by the client to identify this request.
---@field originId? bsp.Identifier
---Timestamp of when the event started in milliseconds since Epoch.
---@field eventTime? integer
---Message describing the task.
---@field message? string
---If known, total amount of work units in this task.
---@field total? integer
---If known, completed amount of work units in this task.
---@field progress? integer
---Name of a work unit. For example, "files" or "tests". May be empty.
---@field unit? string
---Kind of data to expect in the `data` field. If this field is not set, the kind of data is not specified.
---@field dataKind? bsp.TaskProgressDataKind
---Optional metadata about the task.
---Objects for specific tasks like compile, test, etc are specified in the protocol.
---@field data? bsp.TaskProgressData

---@alias bsp.TaskProgressDataKind string

---@alias bsp.TaskProgressData any

---@class bsp.TestCaseDiscoveredParams
---A sequence of build targets to find test cases for.
---@field targets bsp.BuildTargetIdentifier[]
---A unique identifier generated by the client to identify this request.
---@field originId? bsp.Identifier

---@class bsp.TestCaseDiscoveredResult
---A unique identifier generated by the client to identify this request.
---@field originId? bsp.Identifier
---Test case discovery completion status.
---@field statusCode bsp.StatusCode

---@class bsp.TestCaseDiscoveredData
---Unique id of the test case
---@field id string
---Build Target to which the test belongs
---@field buildTarget bsp.BuildTargetIdentifier
---Display name that can be used in the IDE UI
---@field displayName string
---Binary from which the test case information was extractet
---@field source string
---A document in which the test case is discovered
---@field filePath string
---fullyQualifiedName of the test case
---@field fullyQualifiedName string
---Line number where the test case is located inside the source document
---@field line integer

---@class bsp.TaskFinishParams
---Unique id of the task with optional reference to parent task id
---@field taskId bsp.TaskId
---A unique identifier generated by the client to identify this request.
---@field originId? bsp.Identifier
---Timestamp of when the event started in milliseconds since Epoch.
---@field eventTime? integer
---Message describing the task.
---@field message? string
---Task completion status.
---@field status bsp.StatusCode
---Kind of data to expect in the `data` field. If this field is not set, the kind of data is not specified.
---@field dataKind? bsp.TaskFinishDataKind
---Optional metadata about the task.
---Objects for specific tasks like compile, test, etc are specified in the protocol.
---@field data? bsp.TaskFinishData

---@alias bsp.TaskFinishDataKind string

---@alias bsp.TaskFinishData any

---@class bsp.PrintParams
---The id of the request. */
---@field originId bsp.Identifier
---Relevant only for test tasks.
---Allows to tell the client from which task the output is coming from. */
---@field task? bsp.TaskId
---Message content can contain arbitrary bytes.
---They should be escaped as per [javascript encoding](https//developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Grammar_and_types#using_special_characters_in_strings) */
---@field message string

---@class bsp.CompileTask {
---@field target bsp.BuildTargetIdentifier

---@class bsp.CompileReport {
---The build target that was compiled.
---@field target bsp.BuildTargetIdentifier
---An optional request id to know the origin of this report.
---Deprecated Use the field in TaskFinishParams instead
---@field originId? bsp.Identifier
---The total number of reported errors compiling this target.
---@field errors integer
---The total number of reported warnings compiling the target.
---@field warnings integer
---The total number of milliseconds it took to compile the target.
---@field time? integer
---The compilation was a noOp compilation.
---@field noOp? boolean

---@class bsp.CompileResult
---An optional request id to know the origin of this report.
---@field originId? bsp.Identifier
---A status code for the execution.
---@field statusCode bsp.StatusCode
---Kind of data to expect in the `data` field. If this field is not set, the kind of data is not specified.
---@field dataKind? bsp.CompileResultDataKind
---A field containing language-specific information, like products
---of compilation or compiler-specific metadata the client needs to know.
---@field data? bsp.CompileResultData

---@alias bsp.CompileResultDataKind string

---@alias bsp.CompileResultData any

---@class bsp.TestParams
---A sequence of build targets to test.
---@field targets bsp.BuildTargetIdentifier[]
---A unique identifier generated by the client to identify this request.
---The server may include this id in triggered notifications or responses.
---@field originId? bsp.Identifier
---Optional arguments to the test execution engine.
---@field arguments? string[]
---Optional environment variables to set before running the tests.
---@field environmentVariables? table<string, string>
---Optional working directory
---@field workingDirectory? URI
---Kind of data to expect in the `data` field. If this field is not set, the kind of data is not specified.
---@field dataKind? bsp.TestParamsDataKind
---Language-specific metadata about for this test execution.
---See ScalaTestParams as an example.
---@field data? bsp.TestParamsData

---@alias bsp.TestParamsDataKind string

---@alias bsp.TestParamsData any

---@class bsp.TestResult
---An optional request id to know the origin of this report.
---@field originId? bsp.Identifier
---A status code for the execution.
---@field statusCode bsp.StatusCode
---Kind of data to expect in the `data` field. If this field is not set, the kind of data is not specified.
---@field dataKind? bsp.TestResultDataKind
---Language-specific metadata about the test result.
---See ScalaTestParams as an example.
---@field data? bsp.TestResultData

---@alias bsp.TestResultDataKind string

---@alias bsp.TestResultData any

---@class bsp.TestStart
---Name or description of the test.
---@field displayName string
---Source location of the test, as LSP location.
---@field location? bsp.Location

---@class bsp.TestFinish
---Unique test case ID
---@field id string
---Build target to which the test case result belongs to
---@field buildTarget bsp.BuildTargetIdentifier
---FullyQualifiedName of the test case to which the result belongs to
---@field fullyQualifiedName string
---Name or description of the test.
---@field displayName string
---Information about completion of the test, for example an error message.
---@field message? string
---Completion status of the test.
---@field status bsp.TestStatus
---Source location of the test, as LSP location.
---@field location? bsp.Location
---Kind of data to expect in the `data` field. If this field is not set, the kind of data is not specified.
---@field dataKind? bsp.TestFinishDataKind
---Optionally, structured metadata about the test completion.
---For example stack traces, expected/actual values.
---@field data? bsp.TestFinishData

---@class bsp.TestReport
---The build target that was compiled.
---@field target bsp.BuildTargetIdentifier
---The total number of successful tests.
---@field passed integer
---The total number of failed tests.
---@field failed integer
---The total number of ignored tests.
---@field ignored integer
---The total number of cancelled tests.
---@field cancelled integer
---The total number of skipped tests.
---@field skipped integer
---The total number of milliseconds tests take to run (e.g. doesn't include compile times).
---@field time? integer

---@alias bsp.TestFinishDataKind string

---@alias bsp.TestFinishData any

---@class bsp.Location
---@field uri URI
---@field range bsp.Range

---@class bsp.Range
---The range's start position.
---@field start bsp.Position
---The range's end position.
---@field end bsp.Position

---@class bsp.Position
---Line position in a document (zero-based).
---@field line integer
---Character offset on a line in a document (zero-based)
---If the character value is greater than the line length it defaults back
---to the line length.
---@field character integer

---@class bsp.BuildTargetIdentifier
---The target’s Uri
---@field uri URI

---@alias URI string A resource identifier that is a valid URI according to rfc3986: https://tools.ietf.org/html/rfc3986

---@class bsp.TaskId
---A unique identifier
---@field id bsp.Identifier
---The parent task ids, if any. A non-empty parents field means
---this task is a sub-task of every parent task id. The child-parent
---relationship of tasks makes it possible to render tasks in
---a tree-like user interface or inspect what caused a certain task execution
---OriginId should not be included in the parents field, there is a separate field for that.
---@field parents? bsp.Identifier[]

---@alias bsp.Identifier string The unique Id of a task

---@class bsp.BuildClientCapabilities
---The languages that this client supports.
---The ID strings for each language is defined in the LSP.
---The server must never respond with build targets for other
---languages than those that appear in this list.
---@field languageIds LanguageId[]

---@alias LanguageId string Language IDs are defined here https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocumentItem

---@class bsp.BuildServerCapabilities
---The languages the server supports compilation via method buildTarget/compile.
---@field compileProvider? CompileProvider
---The languages the server supports test execution via method buildTarget/test.
---@field testProvider? TestProvider
---The languages the server supports test case discovery via method buildTarget/testCaseDiscovery.
---@field testCaseDiscoveryProvider? TestCaseDiscoveryProvider
---testCaseDiscoveryProvider
---The languages the server supports run via method buildTarget/run.
---@field runProvider? RunProvider
---The languages the server supports debugging via method debugSession/start.
---@field debugProvider? DebugProvider
---The server can provide a list of targets that contain a
---single text document via the method buildTarget/inverseSources
---@field inverseSourcesProvider? boolean
---The server provides sources for library dependencies
---via method buildTarget/dependencySources
---@field dependencySourcesProvider? boolean
---The server can provide a list of dependency modules (libraries with meta information)
---via method buildTarget/dependencyModules
---@field dependencyModulesProvider? boolean
---The server provides all the resource dependencies
---via method buildTarget/resources
---@field resourcesProvider? boolean
---The server provides all output paths
---via method buildTarget/outputPaths
---@field outputPathsProvider? boolean
---The server sends notifications to the client on build
---target change events via buildTarget/didChange
---@field buildTargetChangedProvider? boolean
---The server can respond to `buildTarget/jvmRunEnvironment` requests with the
---necessary information required to launch a Java process to run a main class.
---@field jvmRunEnvironmentProvider? boolean
---The server can respond to `buildTarget/jvmTestEnvironment` requests with the
---necessary information required to launch a Java process for testing or
---debugging.
---@field jvmTestEnvironmentProvider? boolean
---The server can respond to `workspace/cargoFeaturesState` and
---`setCargoFeatures` requests. In other words, supports Cargo Features extension.
---@field cargoFeaturesProvider? boolean
---Reloading the build state through workspace/reload is supported
---@field canReload? boolean

---@class CompileProvider
---@field languageIds LanguageId[]

---@class TestProvider
---@field languageIds LanguageId[]

---@class TestCaseDiscoveryProvider
---@field languageIds LanguageId[]

---@class RunProvider
---@field languageIds LanguageId[]

---@class DebugProvider
---@field languageIds LanguageId[]

---@class bsp.CompileParams
---A sequence of build targets to compile.
---@field targets bsp.BuildTargetIdentifier[]
---A unique identifier generated by the client to identify this request.
---The server may include this id in triggered notifications or responses.
---@field originId? bsp.Identifier
---Optional arguments to the compilation process.
---@field arguments? string[]

---@class bsp.RunParams
---The build target to run.
---@field target bsp.BuildTargetIdentifier
---A unique identifier generated by the client to identify this request.
---The server may include this id in triggered notifications or responses.
---@field originId? bsp.Identifier
---Optional arguments to the executed application.
---@field arguments? string[]
---Optional environment variables to set before running the application.
---@field environmentVariables? table<string, string>
---Optional working directory
---@field workingDirectory? URI
---Kind of data to expect in the `data` field. If this field is not set, the kind of data is not specified.
---@field dataKind? bsp.RunParamsDataKind
---Language-specific metadata for this execution.
---See ScalaMainClass as an example.
---@field data? bsp.RunParamsData

---@alias bsp.RunParamsDataKind string

---@alias bsp.RunParamsData any

---@class bsp.RunResult
---An optional request id to know the origin of this report.
---@field originId? bsp.Identifier
---A status code for the execution.
---@field statusCode bsp.StatusCode

---@class bsp.CleanCacheParams
---@field targets bsp.BuildTargetIdentifier[]

---@class bsp.CleanCacheResult
---Optional message to display to the user.
---@field message? string
---Indicates whether the clean cache request was performed or not.
---@field cleaned boolean

---@class bsp.WorkspaceBuildTargetsResult
---@field targets bsp.BuildTarget[]

---@class bsp.ResourcesParams
---@field targets bsp.BuildTargetIdentifier[]

---@class bsp.ResourcesResult
---@field items bsp.ResourcesItem[]

---@class bsp.DependencySourcesParams
---@field targets bsp.BuildTargetIdentifier[]

---@class bsp.DependencySourcesResult
---@field items bsp.DependencySourcesItem[]

---@class bsp.OutputPathsResult
---@field items bsp.OutputPathsItem[]

---@class bsp.OutputPathsItem
---A build target to which output paths item belongs.
---@field target bsp.BuildTargetIdentifier
---Output paths.
---@field outputPaths bsp.OutputPathItem[]

---@class bsp.OutputPathItem
---Either a file or a directory. A directory entry must end with a forward
---slash "/" and a directory entry implies that every nested path within the
---directory belongs to this output item. */
---@field uri URI
---Type of file of the output item, such as whether it is file or directory. */
---@field kind bsp.OutputPathItemKind

---@class bsp.OutputPathsParams
---@field targets bsp.BuildTargetIdentifier[]

---@class bsp.DependencySourcesItem
---@field target bsp.BuildTargetIdentifier
---List of resources containing source files of the
---target's dependencies.
---Can be source files, jar files, zip files, or directories.
---@field sources URI[]

---@class bsp.ResourcesItem
---@field target bsp.BuildTargetIdentifier
---List of resource files.
---@field resources URI[]

---@class bsp.SourcesParams
---@field targets bsp.BuildTargetIdentifier[]

---@class bsp.SourcesResult
---@field items bsp.SourcesItem[]

---@class bsp.SourcesItem
---@field target bsp.BuildTargetIdentifier
---The text documents or and directories that belong to this build target.
---@field sources bsp.SourceItem[]
---The root directories from where source files should be relativized.
---Example ["file:///Users/name/dev/metals/src/main/scala"]
---@field roots? URI[]

---@class bsp.SourceItem
---Either a text document or a directory. A directory entry must end with a forward
---slash "/" and a directory entry implies that every nested text document within the
---directory belongs to this source item. */
---@field uri URI
---Type of file of the source item, such as whether it is file or directory. */
---@field kind bsp.SourceItemKind
---Indicates if this source is automatically generated by the build and is not
---intended to be manually edited by the user. */
---@field generated boolean

---@class bsp.BuildTarget
---The target’s unique identifier
---@field id bsp.BuildTargetIdentifier
---A human readable name for this target.
---May be presented in the user interface.
---Should be unique if possible.
---The id.uri is used if None.
---@field displayName? string
---The directory where this target belongs to. Multiple build targets are allowed to map
---to the same base directory, and a build target is not required to have a base directory.
---A base directory does not determine the sources of a target, see buildTarget/sources.
---@field baseDirectory? URI
---Free-form string tags to categorize or label this build target.
---For example, can be used by the client to
---- customize how the target should be translated into the client's project model.
---- group together different but related targets in the user interface.
---- display icons or colors in the user interface.
---Pre-defined tags are listed in `BuildTargetTag` but clients and servers
---are free to define new tags for custom purposes.
---@field tags bsp.BuildTargetTag[]
---The set of languages that this target contains.
---The ID string for each language is defined in the LSP.
---@field languageIds LanguageId[]
---The direct upstream build target dependencies of this build target
---@field dependencies bsp.BuildTargetIdentifier[]
---The capabilities of this build target.
---@field capabilities bsp.BuildTargetCapabilities
---Kind of data to expect in the `data` field. If this field is not set, the kind of data is not specified.
---@field dataKind? bsp.BuildTargetDataKind
---Language-specific metadata about this target.
---See ScalaBuildTarget as an example.
---@field data? bsp.BuildTargetData

---@alias bsp.BuildTargetTag string

---@alias bsp.BuildTargetDataKind string

---@alias bsp.BuildTargetData any

---@class bsp.DidChangeBuildTarget
---@field changes bsp.BuildTargetEvent[]

---@class bsp.BuildTargetEvent
---The identifier for the changed build target
---@field target bsp.BuildTargetIdentifier
---The kind of change for this build target
---@field kind? bsp.BuildTargetEventKind
---Kind of data to expect in the `data` field. If this field is not set, the kind of data is not specified.
---@field dataKind? bsp.BuildTargetEventDataKind
---Any additional metadata about what information changed.
---@field data? bsp.BuildTargetEventData

---@alias bsp.BuildTargetEventDataKind string

---@alias bsp.BuildTargetEventData any

---@class bsp.PublishDiagnosticsParams
---The document where the diagnostics are published.
---@field textDocument bsp.TextDocumentIdentifier
---The build target where the diagnostics origin.
---It is valid for one text document to belong to multiple
---build targets, for example sources that are compiled against multiple
---platforms (JVM, JavaScript).
---@field buildTarget bsp.BuildTargetIdentifier
---The request id that originated this notification.
---@field originId? bsp.OriginId
---The diagnostics to be published by the client.
---@field diagnostics lsp.Diagnostic[]
---Whether the client should clear the previous diagnostics
---mapped to the same `textDocument` and `buildTarget`.
---@field reset boolean

---@alias bsp.OriginId string

---@class bsp.TextDocumentIdentifier
---The text document's URI.
---@field uri URI

---@class bsp.LogMessageParams
---the message type.
---@field type bp.MessageType
---The task id if any.
---@field task? bsp.TaskId
---The request id that originated this notification.
---The originId field helps clients know which request originated a notification in case several requests are handled by the
---client at the same time. It will only be populated if the client defined it in the request that triggered this notification.
---@field originId? bsp.OriginId
---The actual message.
---@field message string

---@class bsp.ShowMessageParams {
---the message type.
---@field type bp.MessageType
---The task id if any.
---@field task? bsp.TaskId
---The request id that originated this notification.
---The originId field helps clients know which request originated a notification in case several requests are handled by the
---client at the same time. It will only be populated if the client defined it in the request that triggered this notification.
---@field originId? bsp.OriginId
---The actual message.
---@field message string

---@class bsp.BuildTargetCapabilities
---This target can be compiled by the BSP server.
---@field canCompile? boolean
---This target can be tested by the BSP server.
---@field canTest? boolean
---This target can be run by the BSP server.
---@field canRun? boolean
---This target can be debugged by the BSP server.
---@field canDebug? boolean
