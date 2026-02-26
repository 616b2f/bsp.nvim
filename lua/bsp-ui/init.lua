local bsp = require('bsp')
local protocol = require('bsp.protocol')

local buf = -1

local ns = vim.api.nvim_create_namespace('bsp-test-run-output')

---@class TestRunResult
---@field test_case_results bsp.TestFinish[]
---@field test_report? bsp.TestReport
---@field workspace_root_dir string

---@type table<string,TestRunResult>
local test_run_results = {}

local function display_popup()

  local opts = {
    title = 'Test Report',
    title_pos = 'center',
    relative = 'editor',
    width = 80, height = 30,
    col = 50, row = 10,
    anchor = 'NW',
    border = 'single',
    style = 'minimal'
  }

  local win = vim.api.nvim_open_win(buf, true, opts)
  -- optional: change highlight, otherwise Pmenu is used
  vim.api.nvim_set_option_value('winhl', 'Normal:MyHighlight', {win=win})
end

--- appends lines to test output buffer
---@param lines string[]
local function append_to_output(lines)
  vim.api.nvim_buf_set_lines(buf, -1, -1, true, lines)
end

local function render_test_results(token_id)

  if buf == -1 then
    buf = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_buf_set_name(buf, '[BSP test results]')
  end

  local test_run_result = test_run_results[token_id]
  local test_report = test_run_result.test_report

  assert(test_report, 'test report is nil')

  local full_target_path = vim.uri_to_fname(test_report.target.uri)
  local short_target_path = vim.fs.relpath(test_run_result.workspace_root_dir, full_target_path)
  append_to_output({
    'Target: ' .. (short_target_path or full_target_path),
  })

  for _, test_case_result in ipairs(test_run_result.test_case_results) do

    local status = test_case_result.status
    local status_prefix = '[' .. protocol.TestStatus[status] .. ']'

    append_to_output({
      '',
      status_prefix .. ' ' .. test_case_result.displayName
    })

    local last_written_line = vim.api.nvim_buf_line_count(buf) - 1
    if status == protocol.Constants.TestStatus.Passed then
      vim.hl.range(buf, ns, 'OkMsg', { last_written_line, 0 },
        { last_written_line, string.len(status_prefix) })
    elseif status == protocol.Constants.TestStatus.Failed then
      vim.hl.range(buf, ns, 'ErrorMsg', { last_written_line, 0 },
        { last_written_line, string.len(status_prefix) })
    end

    append_to_output({
      'Output: '
    })

    local m = vim.split(test_case_result.message, '\n', {plain=true})
    for _, v in pairs(m) do
      append_to_output({
        ' ' .. v
      })
    end
  end

  append_to_output({
    '',
    'Total: ' .. test_report.time .. ' ms',
    '',
    'Passed: ' .. test_report.passed .. ' ' ..
      'Failed: ' .. test_report.failed .. ' ' ..
      'Ignored: ' .. test_report.ignored .. ' ' ..
      'Cancelled: ' .. test_report.cancelled .. ' ' ..
      'Skipped: ' .. test_report.skipped
  })

  display_popup()
end

vim.api.nvim_create_autocmd('User',
  {
    group = 'bsp',
    pattern = 'BspProgress:start',
    callback = function(ev)
      local data = ev.data
      local client = bsp.get_client_by_id(data.client_id)
      if client then
        ---@type bsp.TaskStartParams
        local result = ev.data.result
        if result.dataKind == bsp.protocol.Constants.TaskStartDataKind.TestTask then
          ---@type bsp.TestTask
          local test_task_data = result.data
          local tokenId = data.client_id .. ':' .. result.originId
          test_run_results = {}
          test_run_results[tokenId] = {
            test_case_results = {},
            test_report = nil,
            workspace_root_dir = client.workspace_dir
          }
          if client.test_cases[test_task_data.target.uri] then
          end
        end
      end
    end
  })

vim.api.nvim_create_autocmd('User',
  {
    group = 'bsp',
    pattern = 'BspProgress:finish',
    callback = function(ev)
      local data = ev.data
      local client = bsp.get_client_by_id(data.client_id)
      if client then
        ---@type bsp.TaskFinishParams
        local result = ev.data.result

        if result.dataKind == bsp.protocol.Constants.TaskFinishDataKind.TestFinish then
          local token_id = data.client_id .. ':' .. result.originId
          ---@type bsp.TestFinish
          local test_finish = result.data
          table.insert(test_run_results[token_id].test_case_results, test_finish)
        elseif result.dataKind == bsp.protocol.Constants.TaskFinishDataKind.TestReport then
          local token_id = data.client_id .. ':' .. result.originId
          ---@type bsp.TestReport
          local test_report = result.data
          test_run_results[token_id].test_report = test_report
          render_test_results(token_id)
        end
      end
    end
  })
