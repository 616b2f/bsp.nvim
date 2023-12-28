local protocol = {}

local constants = {
  ErrorCodes = {
    -- Defined by JSON RPC
    ParseError = -32700,
    InvalidRequest = -32600,
    MethodNotFound = -32601,
    InvalidParams = -32602,
    InternalError = -32603,
    serverErrorStart = -32099,
    serverErrorEnd = -32000,
    ServerNotInitialized = -32002,
    UnknownErrorCode = -32001,
    -- Defined by the protocol.
    RequestCancelled = -32800,
    ContentModified = -32801,
    ServerCancelled = -32802,
    RequestFailed = -32803
  },

  ---@enum bp.TraceValue
  TraceValues = {
    Off = 'off',
    Messages = 'messages',
    Verbose = 'verbose',
  },

  ---@enum bp.MessageType
  MessageType = {
    ---An error message.
    Error = 1,
    ---A warning message.
    Warning = 2,
    ---An information message.
    Info = 3,
    ---A log message.
    Log = 4,
    ---A debug message.
    Debug = 5,
  },

}

for k, v in pairs(constants) do
  local tbl = vim.deepcopy(v)
  vim.tbl_add_reverse_lookup(tbl)
  protocol[k] = tbl
end

protocol.Methods = {
  -- client requests
  initialize = "initialize",
  initialized = "initialized",
  client_registerCapability = "client/registerCapability",
  client_unregisterCapability = "client/unregisterCapability",
  setTrace = "$/setTrace",
  logTrace = "$/logTrace",
  shutdown = "shutdown",

  -- client notification requests
  cancelRequest = "$/cancelRequest",

  -- sever requests
  window_showMessageRequest = "window/showMessageRequest",

  -- server notifications
  exit = "exit",
  window_showMessage = "window/showMessage",
  window_logMessage = "window/logMessage",
  telemetry_event = "telemetry/event",
  progress = "$/progress",
}

return protocol
