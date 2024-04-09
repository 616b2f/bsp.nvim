return {
  on_create_config = function (server_install_dir, workspace_dir)

      local connection_details = {
        name = 'gradle',
        languages = { 'java' },
        argv = {
          'java',
          '--add-opens=java.base/java.lang=ALL-UNNAMED',
          '--add-opens=java.base/java.io=ALL-UNNAMED',
          '--add-opens=java.base/java.util=ALL-UNNAMED',
          '-Dplugin.dir=' .. server_install_dir .. '/server/build/libs/plugins/',
          '-cp',
          server_install_dir .. '/server/build/libs/server.jar:' .. server_install_dir .. '/server/build/libs/runtime/*',
          'com.microsoft.java.bs.core.Launcher'
        }
      }

      local bsp_dir_path = workspace_dir .. "/.bsp"
      vim.fn.mkdir(bsp_dir_path, "p")
      require("bsp").writeConnectionDetails(connection_details, bsp_dir_path .. "/gradle-bsp.json")
    end
}
