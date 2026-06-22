return {
  on_create_config = function (server_install_dir, workspace_dir)
      local connection_details = {
        name = 'swift-bsp',
        bspVersion = '2.2.0',
        languages = { 'swift' },
        argv = {
            "swift-bsp"
        }
      }

      require("bsp").writeConnectionDetails(connection_details, workspace_dir .. "/buildServer.json")
    end
}

