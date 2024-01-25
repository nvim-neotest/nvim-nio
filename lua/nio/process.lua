local streams = require("nio.streams")
local control = require("nio.control")

local nio = {}
---@toc_entry nio.process
---@class nio.process
nio.process = {}

---@class nio.process.Process
--- Wrapper for a running process, providing access to its stdio streams and
--- methods to interact with it.
---
---@field pid integer ID of the invoked process
---@field signal fun(signal: integer|uv.aliases.signals) Send a signal to
--- the process
---@field result async fun(): number Wait for the process to exit and return the
--- exit code
---@field stdin nio.streams.OSStreamWriter Stream to write to the process stdin.
---@field stdout nio.streams.OSStreamReader Stream to read from the process
--- stdout.
---@field stderr nio.streams.OSStreamReader Stream to read from the process
--- stderr.

--- Run a process asynchronously.
--- ```lua
---  local first = nio.process.run({
---    cmd = "printf", args = { "hello" }
---  })
---
---  local second = nio.process.run({
---    cmd = "cat", stdin = first.stdout
---  })
---
---  local output = second.stdout.read()
---  print(output)
--- ```
---@param opts nio.process.RunOpts
---@return nio.process.Process
function nio.process.run(opts)
  opts = vim.tbl_extend("force", { hide = true }, opts)

  local cmd = opts.cmd
  local args = opts.args

  local exit_code_future = control.future()

  local stdout = streams.reader(opts.stdout)
  local stderr = streams.reader(opts.stderr)
  local stdin = streams.writer(opts.stdin)

  local stdio = { stdin.pipe, stdout.pipe, stderr.pipe }

  local handle, pid, spawn_err = vim.loop.spawn(cmd, {
    args = args,
    stdio = stdio,
    env = opts.env,
    cwd = opts.cwd,
    uid = opts.uid,
    gid = opts.gid,
    verbatim = opts.verbatim,
    detached = opts.detached,
    hide = opts.hide,
  }, function(_, code)
    exit_code_future.set(code)
  end)

  assert(not spawn_err, spawn_err)

  local process = {
    pid = pid,
    signal = function(signal)
      vim.loop.process_kill(handle, signal)
    end,
    stdin = {
      write = stdin.write,
      fd = stdin.pipe:fileno(),
      close = stdin.close,
    },
    stdout = {
      read = stdout.read,
      fd = stdout.pipe:fileno(),
      close = stdout.close,
    },
    stderr = {
      read = stderr.read,
      fd = stderr.pipe:fileno(),
      close = stderr.close,
    },
    result = exit_code_future.wait,
  }
  return process
end

---@class nio.process.RunOpts
---@field cmd string Command to run
---@field args? string[] Arguments to pass to the command
---@field stdin? integer|nio.streams.OSStreamReader|uv.uv_pipe_t|uv_pipe_t Stream,
--- pipe or file descriptor to use as stdin.
---@field stdout? integer|nio.streams.OSStreamWriter|uv.uv_pipe_t|uv_pipe_t Stream,
--- pipe or file descriptor to use as stdout.
---@field stderr? integer|nio.streams.OSStreamWriter|uv.uv_pipe_t|uv_pipe_t Stream,
--- pipe or file descriptor to use as stderr.
---@field env? table<string, string> Environment variables to pass to the
--- process
---@field cwd? string Current working directory of the process
---@field uid? integer User ID of the process
---@field gid? integer Group ID of the process

return nio.process
