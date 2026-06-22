local api = vim.api
local cmd = api.nvim_create_user_command

local get_bsp_info = function()
  local bsp = require('bsp')
  local lines = {}
  table.insert(lines, "Log file: " .. bsp.get_log_path())
  table.insert(lines, "")
  local clients = bsp.get_clients()
  for _, client in ipairs(clients) do
    table.insert(lines, "Client ID: " .. tostring(client.id))
    table.insert(lines, "Server Name: " .. client.name)
    table.insert(lines, "Build Tagets: ")
    for _, btarget in pairs(client.build_targets) do
      table.insert(lines, "\t" .. btarget.id.uri)
    end
    table.insert(lines, "Server Capabilities: ")
    local caps = vim.inspect(client.server_capabilities)
    for _, line in pairs(vim.split(caps, '\n', {plain=true})) do
      table.insert(lines, line)
    end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
  local opts = {
    relative = "editor",
    width = 40, height = 20,
    col = 0, row = 1,
    anchor = "NW",
    border = "single",
    style = "minimal"
  }
  local win = vim.api.nvim_open_win(buf, true, opts)
  -- optional: change highlight, otherwise Pmenu is used
  vim.api.nvim_set_option_value('winhl', 'Normal:MyHighlight', {win=win})
end

local get_clients_from_cmd_args = function(arg)
  local bsp = require('bsp')
  local result = {}
  for id in (arg or ''):gmatch '(%d+)' do
    local client_id = tonumber(id)
    assert(client_id, 'client_id is not a number')
    result[client_id] = bsp.get_client_by_id(client_id)
  end
  if vim.tbl_isempty(result) then
    return require('bsp').get_clients()
  end
  return vim.tbl_values(result)
end

local bsp_server_restart = function(args)
  local detach_clients = {}
  for _, client in ipairs(get_clients_from_cmd_args(args)) do
    client.stop()
    detach_clients[client.name] = client
  end
  local timer = vim.loop.new_timer()
  assert(timer, "timer could not be created")
  timer:start(
    500,
    100,
    vim.schedule_wrap(function()
      for client_name, client in pairs(detach_clients) do
        if client.is_stopped() then
          require('bsp').start_client(client.config)
          detach_clients[client_name] = nil
        end
      end

      if next(detach_clients) == nil and not timer:is_closing() then
        timer:close()
      end
    end)
  )
end

cmd('BspCreateConfig',
  ---@param info { name: string, args: string }
  function(info)
    local working_dir = vim.uv.cwd()
    assert(working_dir, 'could not get current working directory')

    if info and not info.args or info.args == '' then
      print('Specify server name: ' .. info.name .. ' <server_name>')
      return
    end

    require("bsp-config").create_config(info.args, working_dir)
  end,
  {
    desc = 'Create new configuration for specified BSP server in current directory',
    nargs = '?',
    complete = function ()
      return { "dotnet-bsp", "cargo-bsp", "gradle-bsp", "swift-bsp" }
    end
  }
)

local commands = {
  ['compile'] = function() require('bsp').compile_build_target() end,
  ['info'] = get_bsp_info,
  ['log'] = function() vim.cmd(string.format('tabnew %s', require('bsp').get_log_path())) end,
  ['restart'] = bsp_server_restart,
  ['console'] = function () require('bsp.bsp-console').open('[BSP console]') end,
  ['clean-cache'] = function() require('bsp').cleancache_build_target() end,
  ['run'] = function() require('bsp').run_build_target() end,
  ['cancel-run'] = function() require('bsp').cancel_run_build_target() end,
  ['test'] = function() require('bsp').test_build_target() end,
  ['test-file'] = function () require('bsp').test_file_target() end,
  ['test-case'] = function () require('bsp').test_case_target() end,
}

cmd('Bsp',
  ---@param info { name: string, args: string }
  function(info)

    local req_command = info.args
    local command = commands[req_command]

    if not command then
      print('Not a valid command: ' .. req_command)
      return
    end

    command()
  end,
  {
    desc = 'Run a BSP command',
    nargs = '?',
    complete = function ()
      return vim.iter(commands)
        :map(function(k, _)
          return k
        end)
        :totable()
    end
  }
)
