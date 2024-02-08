local tasks = require("nio.tasks")

local nio = {}

---@toc_entry nio.uv
---@text
--- Provides asynchronous versions of vim.loop functions.
--- See corresponding function documentation for parameter and return
--- information.
--- ```lua
---  local file_path = "README.md"
---
---  local open_err, file_fd = nio.uv.fs_open(file_path, "r", 438)
---  assert(not open_err, open_err)
---
---  local stat_err, stat = nio.uv.fs_fstat(file_fd)
---  assert(not stat_err, stat_err)
---
---  local read_err, data = nio.uv.fs_read(file_fd, stat.size, 0)
---  assert(not read_err, read_err)
---
---  local close_err = nio.uv.fs_close(file_fd)
---  assert(not close_err, close_err)
---
---  print(data)
--- ```
---
---@class nio.uv
---@field close async fun(handle: uv_handle_t)
---@field fs_open async fun(path: any, flags: uv.aliases.fs_access_flags|integer, mode: any): (string|nil,integer|nil)
---@field fs_read async fun(fd: integer, size: integer, offset?: integer): (string|nil,string|nil)
---@field fs_close async fun(fd: integer): (string|nil,boolean|nil)
---@field fs_unlink async fun(path: string): (string|nil,boolean|nil)
---@field fs_write async fun(fd: any, data: any, offset?: any): (string|nil,integer|nil)
---@field fs_mkdir async fun(path: string, mode: integer): (string|nil,boolean|nil)
---@field fs_mkdtemp async fun(template: string): (string|nil,string|nil)
---@field fs_rmdir async fun(path: string): (string|nil,boolean|nil)
---@field fs_stat async fun(path: string): (string|nil,uv.aliases.fs_stat_table|nil)
---@field fs_fstat async fun(fd: integer): (string|nil,uv.aliases.fs_stat_table|nil)
---@field fs_lstat async fun(path: string): (string|nil,uv.aliases.fs_stat_table|nil)
---@field fs_statfs async fun(path: string): (string|nil,uv.aliases.fs_statfs_stats|nil)
---@field fs_rename async fun(old_path: string, new_path: string): (string|nil,boolean|nil)
---@field fs_fsync async fun(fd: integer): (string|nil,boolean|nil)
---@field fs_fdatasync async fun(fd: integer): (string|nil,boolean|nil)
---@field fs_ftruncate async fun(fd: integer, offset: integer): (string|nil,boolean|nil)
---@field fs_sendfile async fun(out_fd: integer, in_fd: integer, in_offset: integer, length: integer): (string|nil,integer|nil)
---@field fs_access async fun(path: string, mode: integer): (string|nil,boolean|nil)
---@field fs_chmod async fun(path: string, mode: integer): (string|nil,boolean|nil)
---@field fs_fchmod async fun(fd: integer, mode: integer): (string|nil,boolean|nil)
---@field fs_utime async fun(path: string, atime: number, mtime: number): (string|nil,boolean|nil)
---@field fs_futime async fun(fd: integer, atime: number, mtime: number): (string|nil,boolean|nil)
---@field fs_link async fun(path: string, new_path: string): (string|nil,boolean|nil)
---@field fs_symlink async fun(path: string, new_path: string, flags?: integer): (string|nil,boolean|nil)
---@field fs_readlink async fun(path: string): (string|nil,string|nil)
---@field fs_realpath async fun(path: string): (string|nil,string|nil)
---@field fs_chown async fun(path: string, uid: integer, gid: integer): (string|nil,boolean|nil)
---@field fs_fchown async fun(fd: integer, uid: integer, gid: integer): (string|nil,boolean|nil)
---@field fs_lchown async fun(path: string, uid: integer, gid: integer): (string|nil,boolean|nil)
---@field fs_copyfile async fun(path: any, new_path: any, flags?: any): (string|nil,boolean|nil)
---@field fs_opendir async fun(path: string, entries?: integer): (string|nil,luv_dir_t|nil)
---@field fs_readdir async fun(dir: luv_dir_t): (string|nil,uv.aliases.fs_readdir_entries[]|nil)
---@field fs_closedir async fun(dir: luv_dir_t): (string|nil,boolean|nil)
---@field fs_scandir async fun(path: string): (string|nil,uv_fs_t|nil)
---@field shutdown async fun(stream: uv_stream_t): string|nil
---@field listen async fun(stream: uv_stream_t): string|nil
---@field write async fun(stream: uv_stream_t, data: string|string[]): uv.uv_write_t|nil
---@field write2 async fun(stream: uv_stream_t, data: string|string[], send_handle: uv_stream_t): string|nil
nio.uv = {}

---@nodoc
local function add(name, argc)
  local success, ret = pcall(tasks.wrap, vim.loop[name], argc)

  if not success then
    error("Failed to add function with name " .. name)
  end

  nio.uv[name] = ret
end

add("close", 2) -- close a handle
-- filesystem operations
add("fs_open", 4)
add("fs_read", 4)
add("fs_close", 2)
add("fs_unlink", 2)
add("fs_write", 4)
add("fs_mkdir", 3)
add("fs_mkdtemp", 2)
-- 'fs_mkstemp',
add("fs_rmdir", 2)
add("fs_scandir", 2)
add("fs_stat", 2)
add("fs_fstat", 2)
add("fs_lstat", 2)
add("fs_rename", 3)
add("fs_fsync", 2)
add("fs_fdatasync", 2)
add("fs_ftruncate", 3)
add("fs_sendfile", 5)
add("fs_access", 3)
add("fs_chmod", 3)
add("fs_fchmod", 3)
add("fs_utime", 4)
add("fs_futime", 4)
-- 'fs_lutime',
add("fs_link", 3)
add("fs_symlink", 4)
add("fs_readlink", 2)
add("fs_realpath", 2)
add("fs_chown", 4)
add("fs_fchown", 4)
-- 'fs_lchown',
add("fs_copyfile", 4)
nio.uv.fs_opendir = tasks.wrap(function(path, entries, cb)
  vim.loop.fs_opendir(path, cb, entries)
end, 3)
add("fs_readdir", 2)
add("fs_closedir", 2)
add("fs_statfs", 2)
-- stream
add("shutdown", 2)
add("listen", 3)
-- add('read_start', 2) -- do not do this one, the callback is made multiple times
add("write", 3)
add("write2", 4)
add("shutdown", 2)

return nio.uv
