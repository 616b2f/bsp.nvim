---@meta
error('Cannot require a meta file')

---@class bp.InitializeParams
---The process Id of the parent process that started the server. Is null if
---the process has not been started by another process. If the parent
---process is not alive then the server should exit (see exit notification)
---its process.
---@field processId integer|nil
---Information about the client
---@field clientInfo? bp.clientInfo
---The locale the client is currently showing the user interface
---in. This must not necessarily be the locale of the operating
---system.
---Uses IETF language tags as the value's syntax
---(See https//en.wikipedia.org/wiki/IETF_language_tag)
---@field locale? string
---User provided initialization options.
---@field initializationOptions? any
---The capabilities provided by the client (editor or tool)
---@field capabilities table
---The initial trace setting. If omitted trace is disabled ('off').
---@field trace? bp.TraceValue

---@class bp.clientInfo
---The name of the client as defined by the client.
---@field name string
---The client's version as defined by the client.
---@field version? string

---@class bp.InitializeResult
---The capabilities the server provides.
---@field capabilities table
---Information about the server.
---@field serverInfo bp.ServerInfo

---@class bp.ServerInfo
---The name of the server as defined by the server.
---@field name string
---The server's version as defined by the server.
---@field version? string

---@alias bp.InitializedParams table

---@class bp.RegistrationParams
---@field registrations bp.Registration[]

---General parameters to register for a capability.
---@class bp.Registration
---The id used to register the request. The id can be used to deregister
---the request again.
---@field id string
---The method / capability to register for.
---@field method string
---Options necessary for the registration.
---@field registerOptions? any

---General parameters to unregister a capability.
---@class bp.Unregistration
---The id used to unregister the request or notification. Usually an id
---provided during the register request.
---@field id string
---The method / capability to unregister for.
---@field method string

---@class bp.UnregistrationParams
---@field unregistrations bp.Unregistration[]

---@class bp.ResponseError
---A number indicating the error type that occurred.
---@field code integer
---A string providing a short description of the error.
---@field message string
---A primitive or structured value that contains additional
---information about the error. Can be omitted.
---@field data string|number|boolean|table[]|table|nil

