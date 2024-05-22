local process = require("nio.process")

local nio = {}

---@class nio.curl
nio.curl = {}

---@class nio.curl.RequestOpts
---@field method string The HTTP method to use
---@field url string The URL to request
---@field headers table<string, string> The headers to send
---@field body string The body to send

function nio.curl.request(opts) end
