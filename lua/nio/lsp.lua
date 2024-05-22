local tasks = require("nio.tasks")
local control = require("nio.control")
local logger = require("nio.logger")

local nio = {}

---@toc_entry nio.lsp
---@class nio.lsp
nio.lsp = {}

---@class nio.lsp.Client
---@field request nio.lsp.RequestClient Interface to all requests that can be sent by the client
---@field notify nio.lsp.NotifyClient Interface to all notifications that can be sent by the client
---@field server_capabilities nio.lsp.types.ServerCapabilities

local async_request = tasks.wrap(function(client, method, params, bufnr, request_id_future, cb)
  local success, req_id = client.request(method, params, cb, bufnr)
  if not success then
    if request_id_future then
      request_id_future.set_error("Request failed")
    end
    error(("Failed to send request. Client %s has shut down"):format(client.id))
  end
  if request_id_future then
    request_id_future.set(req_id)
  end
end, 6)

--- Get active clients, optionally matching the given filters
--- Equivalent to |vim.lsp.get_clients|
---@param filters? nio.lsp.GetClientsFilters
---@return nio.lsp.Client[]
function nio.lsp.get_clients(filters)
  local clients = {}
  for _, client in pairs((vim.lsp.get_clients or vim.lsp.get_active_clients)(filters)) do
    clients[#clients + 1] = nio.lsp.convert_client(client)
  end
  return clients
end

---@class nio.lsp.GetClientsFilters
---@field id? integer
---@field name? string
---@field bufnr? integer
---@field method? string

--- Gets a client by id, or nil if the id is invalid. The returned client may
--- not yet be fully initialized.
--- Equivalent to |vim.lsp.get_client_by_id|
---@param id integer
---@return nio.lsp.Client | nil
function nio.lsp.get_client_by_id(id)
  local client = vim.lsp.get_client_by_id(id)
  if not client then
    return
  end
  return nio.lsp.convert_client(client)
end

--- Create an async client for the given client
---@param client table Neovim core LSP client object
---@return nio.lsp.Client
function nio.lsp.convert_client(client)
  local n = require("nio")

  ---@param name string
  local convert_method = function(name)
    return name:gsub("__", "$/"):gsub("_", "/")
  end

  return {
    server_capabilities = client.server_capabilities,
    notify = setmetatable({}, {
      __index = function(_, method)
        method = convert_method(method)
        return function(params)
          return client.notify(method, params)
        end
      end,
    }),
    request = setmetatable({}, {
      __index = function(_, method)
        method = convert_method(method)
        ---@param opts? nio.lsp.RequestOpts
        return function(params, bufnr, opts)
          -- No params for this request
          if type(params) ~= "table" then
            opts = bufnr
            bufnr = params
          end
          opts = opts or {}
          local err, result

          local start = vim.loop.now()
          if opts.timeout then
            local req_future = control.future()
            err, result = n.first({
              function()
                n.sleep(opts.timeout)
                local req_id = req_future.wait()
                n.run(function()
                  async_request(client, "$/cancelRequest", { requestId = req_id }, bufnr)
                end)
                return { code = -1, message = "Request timed out" }
              end,
              function()
                return async_request(client, method, params, bufnr, req_future)
              end,
            })
          else
            err, result = async_request(client, method, params, bufnr)
          end
          local elapsed = vim.loop.now() - start
          logger.trace("Request", method, "took", elapsed, "ms")

          return err, result
        end
      end,
    }),
  }
end

return nio.lsp
