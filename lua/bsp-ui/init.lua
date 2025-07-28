local bsp = require("bsp")

local buf = -1

---@class TestRunResult
---@field test_case_results bsp.TestFinish[]
---@field test_report bsp.TestReport

---@type table<string,TestRunResult>
local test_run_results = {}

local function display_in_popup(lines)

  if buf == -1 then
    buf = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_buf_set_name(buf, "[BSP test results]")
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)

  local opts = {
    title = "Test Report",
    title_pos = "center",
    relative = "editor",
    width = 80, height = 30,
    col = 50, row = 10,
    anchor = "NW",
    border = "single",
    style = "minimal"
  }

  local win = vim.api.nvim_open_win(buf, true, opts)
  -- optional: change highlight, otherwise Pmenu is used
  vim.api.nvim_set_option_value('winhl', 'Normal:MyHighlight', {win=win})
end

local function render_test_results(token_id)
  local test_run_result = test_run_results[token_id]

  local lines = {}

  local test_report = test_run_result.test_report

  table.insert(lines, "Target: " .. vim.uri_to_fname(test_report.target.uri))
  table.insert(lines, "")

  for _, test_case_result in ipairs(test_run_result.test_case_results) do
    table.insert(lines, "TestCase: " .. test_case_result.displayName)
    table.insert(lines, "Output: ")
    local m = vim.split(test_case_result.message, "\n", {plain=true})
    for _, v in pairs(m) do
      table.insert(lines, " " .. v)
    end
  end

  table.insert(lines, "")
  table.insert(lines, "Total: " .. test_report.time .. " ms")
  table.insert(lines, "")
  table.insert(lines, "Passed: " .. test_report.passed .. " " ..
                      "Failed: " .. test_report.failed .. " " ..
                      "Ignored: " .. test_report.ignored .. " " ..
                      "Cancelled: " .. test_report.cancelled .. " " ..
                      "Skipped: " .. test_report.skipped)
  display_in_popup(lines)
end

vim.api.nvim_create_autocmd("User",
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
          local tokenId = data.client_id .. ":" .. result.originId
          test_run_results = {}
          test_run_results[tokenId] = {
            test_case_results = {},
            test_report = nil
          }
          if client.test_cases[test_task_data.target.uri] then
          end
        end
      end
    end
  })

vim.api.nvim_create_autocmd("User",
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
          local token_id = data.client_id .. ":" .. result.originId
          ---@type bsp.TestFinish
          local test_finish = result.data
          table.insert(test_run_results[token_id].test_case_results, test_finish)
        elseif result.dataKind == bsp.protocol.Constants.TaskFinishDataKind.TestReport then
          local token_id = data.client_id .. ":" .. result.originId
          ---@type bsp.TestReport
          local test_report = result.data
          test_run_results[token_id].test_report = test_report
          render_test_results(token_id)
        end
      end
    end
  })
