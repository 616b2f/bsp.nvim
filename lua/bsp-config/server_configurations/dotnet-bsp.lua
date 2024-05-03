return {
  on_create_config = function (server_install_dir, workspace_dir)

      local connection_details = {
        name = 'dotnet-bsp',
        languages = { 'csharp' },
        version = '0.0.1',
        bspVersion = '2.1.1',
        argv = {
          'dotnet',
          'exec',
          server_install_dir .. '/bin/dotnet-bsp.dll',
          '--logLevel=Debug',
          '--extensionLogDirectory',
          '.'
        }
      }

      local bsp_dir_path = workspace_dir .. "/.bsp"
      vim.fn.mkdir(bsp_dir_path, "p")
      require("bsp").writeConnectionDetails(connection_details, bsp_dir_path .. "/dotnet-bsp.json")
  end
}
