local uv = require("nio.uv")
local streams = require("nio.streams")

local nio = {}

---@class nio.file
nio.file = {}

---@class nio.file.File : nio.streams.OSStreamReaderWriter
---@field read async fun(n: integer?, offset: integer?):string?,string? Read data from the stream, optionally up to n bytes otherwise until EOF is reached. Returns the data read or error message if an error occurred. If offset is provided, data will be read from that position in the file, otherwise the current position will be used.

--- Open a file with the given flags and mode
--- ```lua
---  local file = nio.file.open("test.txt", "w+")
---
---  file.write("Hello, World!\n")
---
---  local content = file.read(nil, 0)
---  file.close()
---  print(content)
--- ```
---@param path string The path to the file
---@param flags uv.aliases.fs_access_flags|integer? The flags to open the file with, defaults to "r"
---@param mode number? The mode to open the file with, defaults to 644
---@return nio.file.File? File object
---@return string? Error message if an error occurred while opening
---
---@seealso |uv.fs_open|
function nio.file.open(path, flags, mode)
  local err, fd = uv.fs_open(path, flags or "r", mode or 438)
  if not fd then
    return nil, err
  end

  local reader, reader_err = streams._file_reader(fd)
  if not reader then
    return nil, reader_err
  end
  local writer, writer_err = streams._writer(fd)
  if not writer then
    return nil, writer_err
  end

  local file = {
    fd = fd,
    close = function()
      local close_err = uv.fs_close(fd)
      reader.close()
      writer.close()
      return close_err
    end,
    write = writer.write,
    read = reader.read,
  }

  return file
end

return nio.file
