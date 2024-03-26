local api = vim.api
local cmd = api.nvim_create_user_command

cmd('BspCompile', function() require('bsp').compile_build_target() end, { nargs = 0 })
cmd('BspTest', function() require('bsp').test_build_target() end, { nargs = 0 })
cmd('BspRun', function() require('bsp').run_build_target() end, { nargs = 0 })

cmd('BspLog', function() vim.cmd(string.format('tabnew %s', require('bsp').get_log_path())) end, { nargs = 0 })
cmd('BspConsole', function () require('bsp.bsp-console').open() end, { nargs = 0 })
cmd('BspCleanCache', function() require('bsp').cleancache_build_target() end, { nargs = 0 })

local get_clients_from_cmd_args = function(arg)
  local bsp = require('bsp')
  local result = {}
  for id in (arg or ''):gmatch '(%d+)' do
    result[id] = bsp.get_client_by_id(tonumber(id))
  end
  if vim.tbl_isempty(result) then
    return require('bsp').get_clients()
  end
  return vim.tbl_values(result)
end

local bsp_get_active_client_ids = function(arg)
  local bsp = require('bsp')
  local clients = vim.tbl_map(function(client)
    return ('%d (%s)'):format(client.id, client.name)
  end, bsp.get_clients())

  local items = vim.tbl_filter(
    function(s)
      return s:sub(1, #arg) == arg
    end,
    clients)
  table.sort(items)
  return items
end

cmd('BspRestart', function(info)
  local detach_clients = {}
  for _, client in ipairs(get_clients_from_cmd_args(info.args)) do
    client.stop()
    detach_clients[client.name] = client
  end
  local timer = vim.loop.new_timer()
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
end, {
  desc = 'Manually restart the given build server client(s)',
  nargs = '?',
  complete = bsp_get_active_client_ids,
})

cmd('BspInfo', function()
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
end, { nargs = 0 })


cmd('BspCreateConfig', function(info)
  local working_dir = vim.uv.cwd()
  require("bsp-config").create_config(info.args, working_dir);
end, {
  desc = 'Create new configuration for specified BSP server in current directory',
  nargs = '?',
  complete = function ()
    return { "dotnet-bsp", "cargo-bsp", "gradle-bsp" }
  end
})

