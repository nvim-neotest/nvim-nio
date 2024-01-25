local tasks = require("nio.tasks")
local control = require("nio.control")
local uv = require("nio.uv")

local nio = {}

---@toc_entry nio.streams
---@class nio.streams
nio.streams = {}

---@class nio.streams.Stream
---@field close async fun(): nil Close the stream

---@class nio.streams.Reader : nio.streams.Stream
---@field read async fun(n?: integer): string Read data from the stream,
--- optionally up to n bytes otherwise until EOF is reached

---@class nio.streams.Writer : nio.streams.Stream
---@field write async fun(data: string): nil Write data to the stream

---@class nio.streams.OSStream : nio.streams.Stream
---@field fd integer The file descriptor of the stream

---@class nio.streams.StreamReader : nio.streams.Reader, nio.streams.Stream
---@class nio.streams.StreamWriter : nio.streams.Writer, nio.streams.Stream

---@class nio.streams.OSStreamReader : nio.streams.StreamReader, nio.streams.OSStream
---@class nio.streams.OSStreamWriter : nio.streams.StreamWriter, nio.streams.OSStream

---@param input integer|uv.uv_pipe_t|uv_pipe_t|nio.streams.OSStream
---@return uv_pipe_t
---@nodoc
local function create_pipe(input)
  if type(input) == "userdata" then
    -- Existing pipe
    return input
  end

  local pipe, err = vim.loop.new_pipe()
  assert(not err and pipe, err)

  local fd = type(input) == "number" and input or input and input.fd
  if fd then
    -- File descriptor
    pipe:open(fd)
  end

  return pipe
end

---@param input integer|nio.streams.OSStreamReader|uv.uv_pipe_t|uv_pipe_t
---@private
function nio.streams.reader(input)
  local pipe = create_pipe(input)

  local buffer = ""
  local ready = control.event()
  local complete = control.event()
  local started = false

  local stop_reading = function()
    if not started or complete.is_set() then
      return
    end
    vim.loop.read_stop(pipe)
    complete.set()
    ready.set()
  end

  local start = function()
    started = true
    pipe:read_start(function(err, data)
      assert(not err, err)
      if not data then
        tasks.run(stop_reading)
        return
      end
      buffer = buffer .. data
      ready.set()
    end)
  end

  return {
    pipe = pipe,
    close = function()
      stop_reading()
      uv.close(pipe)
    end,
    read = function(n)
      if not started then
        start()
      end
      if n == 0 then
        return ""
      end

      while not complete.is_set() and (not n or #buffer < n) do
        ready.wait()
        ready.clear()
      end

      local data = n and buffer:sub(1, n) or buffer
      buffer = buffer:sub(#data + 1)
      return data
    end,
  }
end

---@param input integer|nio.streams.OSStreamWriter|uv.uv_pipe_t|uv_pipe_t
---@private
function nio.streams.writer(input)
  local pipe = create_pipe(input)

  return {
    pipe = pipe,
    write = function(data)
      uv.write(pipe, data)
    end,
    close = function()
      uv.shutdown(pipe)
    end,
  }
end

return nio.streams
