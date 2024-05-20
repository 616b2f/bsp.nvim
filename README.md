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
After that go to the root of your project and run `BspCreateConfig <bsp_server_name>` you can use TAB to select between available server configurations. A config file `.bsp/<bsp_server_name.json` will be created for you. The server has to be installed for it to work.

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
        local title = "BSP-Task"
        if result.dataKind then
        title = result.dataKind
        end
        local message = "started: " .. tostring(result.taskId.id)

        handles[result.taskId.id] = progress.handle.create({
        token = result.taskId.id,
        title = title,
        message = (result.message or message),
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
    local percentage = 0
    ---@type bsp.TaskStartParams
    local result = ev.data.result
    if data.result and data.result.message then
        local message =
        data.result.message
        and (data.result.originId and ( data.result.originId .. ': ') .. data.result.message)
        or data.result.title
        if data.result.total and data.result.progress then
        percentage = math.max(percentage or 0, (data.result.progress / data.result.total * 100))
        end
        local handle = handles[result.taskId.id]
        if handle then
            local progressMessage = {
            token = result.taskId.id,
            message = message,
            percentage = percentage
            }
            -- print(vim.inspect(progressMessage))
            -- print(vim.inspect(result))
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
    ---@type bsp.TaskStartParams
    local result = ev.data.result
    local handle = handles[result.taskId.id]
    -- You can also cancel the task (errors if not cancellable)
    -- handle:cancel()
    -- Or mark it as complete (updates percentage to 100 automatically)
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
