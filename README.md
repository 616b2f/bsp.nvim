# bsp.nvim
Build Server Protocol  (BSP) client for Neovim. BSP is designed to allow your editor to communicate with different build tools to compile, run, test, debug your code and more. For more info see the [Official BSP specification](https://build-server-protocol.github.io/docs/specification).

This is currently in active development and is not stable. You are welcome to contibute and make PRs.

# Installation

min supported neovim version is 0.10

## [Packer](https://github.com/wbthomason/packer.nvim)

```lua
use {
    "616b2f/bsp.nvim"
}
```

## [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "616b2f/bsp.nvim"
}
```

## [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug '616b2f/bsp.nvim'
```

# Setup

```lua
require("bsp").setup()
```

## Setup BSP Server
you can use my fork of mason-registry to install bsp-servers (if there is enough interest I will create PRs for them upsream). For that you have to clone it first, e.g.:

```sh
$ cd ~/my-folder
$ git clone https://github.com/616b2f/mason-registry.git
```

Add the fork as additional registry, this will first look in the official repository and after that in my fork.
```lua
require("mason").setup({
  registries = {
    "github:mason-org/mason-registry",
    "file:~/my-folder/mason-registry", -- directory of the cloned fork
  }
})
```
## Create config
After the setup you have to create a config file for your BSP Server, that is located in the root of your project. To create the config file run `BspCreateConfig <bsp_server_name>` you can use TAB to select between available server configurations. A config file `.bsp/<bsp_server_name.json` will be created for you. The server has to be installed for it to work.

# Available commands

```sh
BspCleanCache
BspCompile
BspConsole
BspCreateConfig <bsp_server_name> # requires "mason-registry" package to be installed
BspInfo
BspLog
BspRestart
BspRun
BspTest
```

# Configuration Recipes

## Define keybindings on BspAttach
```lua
vim.api.nvim_create_autocmd("User",
{
  group = 'bsp',
  pattern = 'BspAttach',
  callback = function()
    local opts = {}
    vim.keymap.set('n', '<leader>bb', require('bsp').compile_build_target, opts)
    vim.keymap.set('n', '<leader>bt', require('bsp').test_build_target, opts)
    vim.keymap.set('n', '<leader>bc', require('bsp').cleancache_build_target, opts)
  end
})
```
## Notifications via Fidget
Plugin (fidget.nvim)[https://github.com/j-hui/fidget.nvim] has to be installed.
```lua
local bsp = require("bsp")
local progress = require("fidget.progress")
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
        local title = result.dataKind or "BSP-Task"
        local fallback_message = "started: " .. tostring(result.taskId.id)

        local tokenId = data.client_id .. ":" .. result.taskId.id
        handles[tokenId] = progress.handle.create({
          token = tokenId,
          title = title,
          message = result.message or fallback_message,
          lsp_client = { name = client.name }
        })
      end
    end
  })

vim.api.nvim_create_autocmd("User",
  {
    group = 'bsp',
    pattern = 'BspProgress:progress',
    callback = function(ev)
      local data = ev.data
      local percentage = nil
      ---@type bsp.TaskProgressParams
      local result = ev.data.result
      if data.result and data.result.message then
        local message =
          (data.result.originId and ( data.result.originId .. ': ') .. data.result.message)
          or data.result.message
        if data.result.total and data.result.progress then
          percentage = math.max(percentage or 0, (data.result.progress / data.result.total * 100))
        end

        local tokenId = data.client_id .. ":" .. result.taskId.id
        local handle = handles[tokenId]
        if handle then
            local progressMessage = {
              token = tokenId,
              message = message,
              percentage = percentage
            }
            handle:report(progressMessage)
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
      ---@type bsp.TaskFinishParams
      local result = ev.data.result
      local tokenId = data.client_id .. ":" .. result.taskId.id
      local handle = handles[tokenId]
      if handle then
        handle:finish()
      end
    end
  })
```


# Credits
Thanks to the following projects that helped me to build this project.

- https://github.com/neovim/neovim I borrowed most of the implementation from the LSP implementation there.
- https://github.com/JetBrains/intellij-bsp To get an idea how the implementation could look like and how some of the methods are used to collect information about the workspace.
- https://github.com/microsoft/vscode-gradle Also for implementation details
