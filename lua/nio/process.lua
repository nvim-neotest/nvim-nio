local streams = require("nio.streams")
local control = require("nio.control")

local nio = {}
---@toc_entry nio.process
---@class nio.process
nio.process = {}

--- Wrapper for a running process, providing access to its stdio streams and
--- methods to interact with it.
---@class nio.process.Process
---@field pid integer ID of the invoked process
---@field signal fun(signal: integer|uv.aliases.signals) Send a signal to the process
---@field result async fun(close: boolean): number,(string|nil)[] Wait for the process to exit and return the exit code, optionally closing all streams.
---@field stdin nio.streams.OSStreamWriter Stream to write to the process stdin.
---@field stdout nio.streams.OSStreamReader Stream to read from the process stdout.
---@field stderr nio.streams.OSStreamReader Stream to read from the process stderr.
---@field close async fun():(string|nil)[] Close all streams, returning any errors that occurred.

--- Run a process asynchronously.
--- ```lua
---  local process = nio.process.run({
---    cmd = "printf", args = { "hello" }
---  })
---
---  local output = second.stdout.read()
---  print(output)
---
---  process.close()
--- ```
---
--- Processes can be chained together, passing output of one process as input to
--- another.
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
---
---  first.close()
---  second.close()
--- ```
---
--- The stdio fields can also be file objects.
--- ```lua
---  local path = nio.fn.tempname()
---
---  local file = nio.file.open(path, "w+")
---
---  local process = nio.process.run({
---    cmd = "printf",
---    args = { "hello" },
---    stdout = file,
---  })
---  process.result()
---
---  local output = file.read(nil, 0)
---  print(output)
---
---  process.close() -- Closes the file
--- ```
---@param opts nio.process.RunOpts
---@return nio.process.Process? Process object for the running process
---@return string? Error message if an error occurred
function nio.process.run(opts)
  opts = vim.tbl_extend("force", { hide = true }, opts)

  local cmd = opts.cmd
  local args = opts.args

  local exit_code_future = control.future()

  local stdout, stdout_err = streams._socket_reader(opts.stdout)
  if not stdout then
    return nil, stdout_err
  end
  local stderr, stderr_err = streams._socket_reader(opts.stderr)
  if not stderr then
    return nil, stderr_err
  end
  local stdin, stdin_err = streams._writer(opts.stdin)
  if not stdin then
    return nil, stdin_err
  end

  local stdio = { stdin.pipe, stdout.pipe, stderr.pipe }

  local handle, pid_or_error = vim.loop.spawn(cmd, {
    args = args,
    stdio = stdio,
    env = opts.env,
    cwd = opts.cwd,
    uid = opts.uid,
    gid = opts.gid,
    verbatim = opts.verbatim,
    detached = opts.detached,
    hide = opts.hide,
  }, function(code, _)
    exit_code_future.set(code)
  end)

  if not handle then
    return nil, pid_or_error
  end
  local stdin_fd, stdin_fd_err = stdin.pipe:fileno()
  if not stdin_fd then
    return nil, stdin_fd_err
  end
  local stdout_fd, stdout_fd_err = stdout.pipe:fileno()
  if not stdout_fd then
    return nil, stdout_fd_err
  end
  local stderr_fd, stderr_fd_err = stderr.pipe:fileno()
  if not stderr_fd then
    return nil, stderr_fd_err
  end

  ---@type nio.process.Process
  local process
  process = {
    pid = pid_or_error,
    signal = function(signal)
      vim.loop.process_kill(handle, signal)
    end,
    stdin = {
      write = stdin.write,
      fd = stdin_fd,
      close = stdin.close,
    },
    stdout = {
      read = stdout.read,
      fd = stdout_fd,
      close = stdout.close,
    },
    stderr = {
      read = stderr.read,
      fd = stderr_fd,
      close = stderr.close,
    },
    result = function(close)
      local result = exit_code_future.wait()
      local errors = {}
      if close then
        errors = process.close()
      end
      return result, errors
    end,
    close = function()
      return { stdin.close(), stdout.close(), stderr.close() }
    end,
  }
  return process
end

---@class nio.process.RunOpts
---@field cmd string Command to run
---@field args? string[] Arguments to pass to the command
---@field stdin? integer|nio.streams.OSStream|uv_pipe_t Stream, pipe or file
---descriptor to use as stdin.
---@field stdout? integer|nio.streams.OSStream|uv_pipe_t Stream, pipe or file
---descriptor to use as stdout.
---@field stderr? integer|nio.streams.OSStream|uv_pipe_t Stream, pipe or file
---descriptor to use as stderr.
---@field env? table<string, string> Environment variables to pass to the
--- process
---@field cwd? string Current working directory of the process
---@field uid? integer User ID of the process
---@field gid? integer Group ID of the process

return nio.process
