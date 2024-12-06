local bsp = require("bsp")

local handles = {}
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
          local tokenId = data.client_id .. ":" .. result.originId
          handles = {}
          handles[tokenId] = {}
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

        local tokenId = data.client_id .. ":" .. result.originId

        if result.dataKind == bsp.protocol.Constants.TaskFinishDataKind.TestReport then

          ---@type bsp.TestReport
          local test_report = result.data
          local lines = {}
          table.insert(lines, "Target: " .. vim.uri_to_fname(test_report.target.uri))
          table.insert(lines, "")

          for _, value in pairs(handles[tokenId]) do
            table.insert(lines, value)
          end
          table.insert(lines, "")
          table.insert(lines, "Total: " .. test_report.time .. " ms")
          table.insert(lines, "")
          table.insert(lines, "Passed: " .. test_report.passed .. " " ..
                              "Failed: " .. test_report.failed .. " " ..
                              "Ignored: " .. test_report.ignored .. " " ..
                              "Cancelled: " .. test_report.cancelled .. " " ..
                              "Skipped: " .. test_report.skipped)

          local buf = vim.api.nvim_create_buf(false, true)
          vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
          local opts = {
            title = "Test Report",
            title_pos = "center",
            relative = "editor",
            width = 80, height = 30,
            col = 60, row = 10,
            anchor = "NW",
            border = "single",
            style = "minimal"
          }
          local win = vim.api.nvim_open_win(buf, true, opts)
          -- optional: change highlight, otherwise Pmenu is used
          vim.api.nvim_set_option_value('winhl', 'Normal:MyHighlight', {win=win})
        elseif result.dataKind == bsp.protocol.Constants.TaskFinishDataKind.TestFinish then

          ---@type bsp.TestFinish
          local test_finish = result.data

          local lines = handles[tokenId]

          table.insert(lines, "TestCase: " .. test_finish.displayName)
          table.insert(lines, "Output: ")
          local m = vim.split(test_finish.message, "\n", {plain=true})
          for _, v in pairs(m) do
            table.insert(lines, " " .. v)
          end
        end
      end
    end
  })
