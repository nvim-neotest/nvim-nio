local tasks = require("nio.tasks")
local control = require("nio.control")
local uv = require("nio.uv")

local nio = {}

---@toc_entry nio.streams
---@class nio.streams
nio.streams = {}

---@class nio.streams.Stream
---@field close async fun(): string|nil Close the stream. Returns an error message if an error occurred.

---@class nio.streams.Reader : nio.streams.Stream
---@field read async fun(n?: integer): string?,string? Read data from the stream, optionally up to n bytes otherwise until EOF is reached. Returns the data read or error message if an error occurred.

---@class nio.streams.Writer : nio.streams.Stream
---@field write async fun(data: string): string? Write data to the stream. Returns an error message if an error occurred.

---@class nio.streams.OSStream : nio.streams.Stream
---@field fd integer The file descriptor of the stream

---@class nio.streams.StreamReader : nio.streams.Reader, nio.streams.Stream
---@class nio.streams.StreamWriter : nio.streams.Writer, nio.streams.Stream

---@class nio.streams.OSStreamReader : nio.streams.StreamReader, nio.streams.OSStream
---@class nio.streams.OSStreamWriter : nio.streams.StreamWriter, nio.streams.OSStream

---@class nio.streams.OSStreamReaderWriter : nio.streams.OSStreamReader, nio.streams.OSStreamWriter

---@param input integer|uv.uv_pipe_t|uv_pipe_t|nio.streams.OSStream
---@return uv_pipe_t?
---@return string?
---@nodoc
local function create_pipe(input)
  if type(input) == "userdata" then
    -- Existing pipe
    return input
  end

  local pipe, err = vim.loop.new_pipe()
  if not pipe then
    return nil, err
  end

  local fd = type(input) == "number" and input or input and input.fd
  if fd then
    local _, open_err = pipe:open(fd)
    if open_err then
      return nil, open_err
    end
  end

  return pipe
end

---@param input integer|nio.streams.OSStreamReader|uv.uv_pipe_t|uv_pipe_t
---@return {pipe: uv_pipe_t, read: (fun(n?: integer):string,string), close: fun(): string|nil}?
---@return string?
---@nodoc
function nio.streams._socket_reader(input)
  local pipe, create_err = create_pipe(input)
  if not pipe then
    return nil, create_err
  end

  local buffer = ""
  local has_buffer = control.event()
  local complete = control.event()
  local started = false

  local stop_reading = function()
    if not started or complete.is_set() then
      return
    end
    vim.loop.read_stop(pipe)
    complete.set()
    has_buffer.set()
  end
  local read_err = nil

  local start = function()
    started = true
    local fd, fd_err = pipe:fileno()
    if not fd then
      return fd_err
    end
    local stat_err, stat = uv.fs_fstat(fd)
    if stat_err or not stat then
      return stat_err
    end

    if stat.type ~= "socket" then
      return "Invalid pipe type, expected socket, got " .. stat.type
    end

    local _, read_start_err = pipe:read_start(function(err, data)
      if err then
        read_err = err
        has_buffer.set()
        return
      end

      if not data then
        tasks.run(stop_reading)
        return
      end

      buffer = buffer .. data
      has_buffer.set()
    end)
    return read_start_err
  end

  return {
    pipe = pipe,
    close = function()
      stop_reading()
      uv.close(pipe)
    end,
    read = function(n)
      if not started then
        local start_err = start()
        if start_err then
          return "", start_err
        end
      end
      if n == 0 then
        return "", nil
      end
      while not complete.is_set() and (not n or #buffer < n) and not read_err do
        has_buffer.wait()
        has_buffer.clear()
      end

      if read_err then
        return "", read_err
      end

      local data = n and buffer:sub(1, n) or buffer
      buffer = buffer:sub(#data + 1)
      return data
    end,
  }
end

---@param fd integer
---@return {read: (fun(n: integer?, offset: integer?): string?,string?), close: (async fun(): string?), seek: fun(offset: integer, whence: string?)}?
---@nodoc
function nio.streams._file_reader(fd)
  return {
    close = function()
      return uv.fs_close(fd)
    end,
    read = function(n, offset)
      if n == 0 then
        return "", nil
      end
      if not n then
        local stat_err, stat = uv.fs_fstat(fd)
        if stat_err or not stat then
          return nil, stat_err
        end
        n = stat.size
      end

      local read_err, data = uv.fs_read(fd, n, offset)
      return data, read_err
    end,
  }
end

---@param input integer|nio.streams.OSStreamWriter|uv.uv_pipe_t|uv_pipe_t
---@return {pipe: uv_pipe_t, write: (fun(data: string): string|nil), close: fun(): string|nil}|nil
---@return string|nil
---@nodoc
function nio.streams._writer(input)
  local pipe, create_err = create_pipe(input)
  if not pipe then
    return nil, create_err
  end

  return {
    pipe = pipe,
    write = function(data)
      local maybe_err = uv.write(pipe, data)
      if type(maybe_err) == "string" then
        return maybe_err
      end
      return nil
    end,
    close = function()
      uv.close(pipe)
    end,
  }
end

return nio.streams
