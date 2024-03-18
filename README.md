# nvim-nio

A library for asynchronous IO in Neovim, inspired by the asyncio library in Python. The library focuses on providing
both common asynchronous primitives and asynchronous APIs for Neovim's core.

- [Motivation](#motivation)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
  - [`nio.control`](#niocontrol): Primitives for flow control in async functions
  - [`nio.lsp`](#niolsp): A fully typed and documented async LSP client library, generated from the LSP specification.
  - [`nio.file`](#niofile): Open and operate on files asynchronously
  - [`nio.process`](#nioprocess): Run and control subprocesses asynchronously
  - [`nio.uv`](#niouv): Async versions of `vim.loop` functions
  - [`nio.ui`](#nioui): Async versions of vim.ui functions
  - [`nio.tests`](#niotests): Async versions of plenary.nvim's test functions
  - [Third Party Integration](#third-party-integration)
- [Used By](#used-by)

## Motivation

Work has been ongoing around async libraries in Neovim for years, with a lot of discussion around a [Neovim core
implementation](https://github.com/neovim/neovim/issues/19624). Much of the motivation behind this library can be seen
in that discussion.

nvim-nio aims to provide a simple interface to Lua coroutines that doesn't feel like it gets in the way of your actual
logic. You won't even know you're using them. An example of this is error handling. With other libraries, a custom
`pcall` or some other custom handling must be used to catch errors. With nvim-nio, Lua's built-in `pcall` works exactly
as you'd expect.

nvim-nio is focused on providing a great developer experience. The API is well documented with examples and full type
annotations, which can all be used by the Lua LSP. It's recommended to use
[neodev.nvim](https://github.com/folke/neodev.nvim) to get LSP support.

![image](https://github.com/nvim-lua/plenary.nvim/assets/24252670/0dda462c-0b5c-4300-8e65-b7218e3d2c1e)

Credit to the async library in [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) and
[async.nvim](https://github.com/lewis6991/async.nvim) for inspiring nvim-nio and its implementation.
If Neovim core integrates an async library, nvim-nio will aim to maintain compatibility with it if possible.

## Installation

Install with your favourite package manager

[lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{ "nvim-neotest/nvim-nio" }
```

[dein](https://github.com/Shougo/dein.vim):

```vim
call dein#add("nvim-neotest/nvim-nio")
```

[vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'nvim-neotest/nvim-nio'
```

[packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use { "nvim-neotest/nvim-nio" }
```

## Configuration

There are no configuration options currently available.

## Usage

nvim-nio is based on the concept of tasks. These tasks represent a series of asynchronous actions that run in a single
context. Under the hood, each task is running on a separate lua coroutine.

Tasks are created by providing an async function to `nio.run`. All async
functions must be called from a task.

```lua
local nio = require("nio")

local task = nio.run(function()
  nio.sleep(10)
  print("Hello world")
end)
```

For simple use cases tasks won't be too important but they support features such as cancelling and retrieving stack traces.

nvim-nio comes with built-in modules to help with writing async code. See `:help nvim-nio` for extensive documentation.

### `nio.control`

Primitives for flow control in async functions

```lua
local event = nio.control.event()

local worker = nio.run(function()
  nio.sleep(1000)
  event.set()
end)

local listeners = {
  nio.run(function()
    event.wait()
    print("First listener notified")
  end),
  nio.run(function()
    event.wait()
    print("Second listener notified")
  end),
}
```

### `nio.lsp`

A fully typed and documented async LSP client library, generated from the LSP specification.

```lua
local client = nio.lsp.get_clients({ name = "lua_ls" })[1]

local err, response = client.request.textDocument_semanticTokens_full({
  textDocument = { uri = vim.uri_from_bufnr(0) },
})

assert(not err, err)

for _, token in pairs(response.data) do
  print(token)
end
```

### `nio.file`

Open and operate on files asynchronously

```lua
local file = nio.file.open("test.txt", "w+")

file.write("Hello, World!\n")

local content = file.read(nil, 0)
print(content)
```

### `nio.process`

Run and control subprocesses asynchronously

```lua
local first = nio.process.run({
  cmd = "printf", args = { "hello" }
})

local second = nio.process.run({
  cmd = "cat", stdin = first.stdout
})

local output = second.stdout.read()
print(output)
```

### `nio.uv`

Async versions of `vim.loop` functions

```lua
local file_path = "README.md"

local open_err, file_fd = nio.uv.fs_open(file_path, "r", 438)
assert(not open_err, open_err)

local stat_err, stat = nio.uv.fs_fstat(file_fd)
assert(not stat_err, stat_err)

local read_err, data = nio.uv.fs_read(file_fd, stat.size, 0)
assert(not read_err, read_err)

local close_err = nio.uv.fs_close(file_fd)
assert(not close_err, close_err)

print(data)
```

### `nio.ui`

Async versions of vim.ui functions

```lua
local value = nio.ui.input({ prompt = "Enter something: " })
print(("You entered: %s"):format(value))
```

### `nio.tests`

Async versions of plenary.nvim's test functions

```lua
nio.tests.it("notifies listeners", function()
  local event = nio.control.event()
  local notified = 0
  for _ = 1, 10 do
    nio.run(function()
      event.wait()
      notified = notified + 1
    end)
  end

  event.set()
  nio.sleep(10)
  assert.equals(10, notified)
end)
```

### Third Party Integration

It is also easy to wrap callback style functions to make them asynchronous using `nio.wrap`, which allows easily
integrating third-party APIs with nvim-nio.

```lua
local nio = require("nio")

local sleep = nio.wrap(function(ms, cb)
  vim.defer_fn(cb, ms)
end, 2)

nio.run(function()
  sleep(10)
  print("Slept for 10ms")
end)
```

## Used By

Here are some of the plugins using nvim-nio:
- [neotest](https://github.com/nvim-neotest/neotest)
- [nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui)
- [rest.nvim](https://github.com/rest-nvim/rest.nvim)
- [rocks.nvim](https://github.com/nvim-neorocks/rocks.nvim)
- [pathlib.nvim](https://github.com/pysan3/pathlib.nvim)

Please open an issue to add any missing entries!
