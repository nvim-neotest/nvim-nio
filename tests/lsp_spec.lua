local nio = require("nio")
local a = nio.tests

describe("lsp client", function()
  a.it("sends request and returns result", function()
    local expected_result = { "test" }
    local expected_params = { a = "b" }
    vim.lsp.get_client_by_id = function(id)
      return {
        request = function(method, params, callback, bufnr)
          assert.equals("textDocument/diagnostic", method)
          assert.equals(0, bufnr)
          assert.same(params, params)
          callback(nil, expected_result)
          return true, 1
        end,
      }
    end

    local client = nio.lsp.get_client_by_id(1)

    local err, result =
      client.request.textDocument_diagnostic(expected_params, 0, { timeout = 1000 })
    assert.same(expected_result, result)
  end)

  a.it("returns error for request", function()
    local params = { a = "b" }
    vim.lsp.get_client_by_id = function(id)
      return {
        request = function(method, params, callback, bufnr)
          callback({ message = "error" }, nil)
          return true, 1
        end,
      }
    end

    local client = nio.lsp.get_client_by_id(1)

    local err, result = client.request.textDocument_diagnostic(0, params)
    assert.same(err.message, "error")
    assert.Nil(result)
  end)

  a.it("raises error on timeout", function()
    vim.lsp.get_client_by_id = function(id)
      return {
        request = function(method, params, callback, bufnr)
          return true, 1
        end,
      }
    end

    local client = nio.lsp.get_client_by_id(1)

    local err, result = client.request.textDocument_diagnostic({}, 0, { timeout = 10 })
    assert.same(err.message, "Request timed out")
    assert.Nil(result)
  end)

  a.it("cancels request on timeout", function()
    local cancel_received = false
    vim.lsp.get_client_by_id = function(id)
      return {
        request = function(method, params, callback, bufnr)
          if method == "$/cancelRequest" then
            cancel_received = true
          end
          return true, 1
        end,
      }
    end

    local client = nio.lsp.get_client_by_id(1)

    client.request.textDocument_diagnostic({}, 0, { timeout = 10 })
    assert.True(cancel_received)
  end)

  a.it("raises errors on client shutdown", function()
    vim.lsp.get_client_by_id = function(id)
      return {
        id = id,
        request = function(method, params, callback, bufnr)
          return false
        end,
      }
    end

    local client = nio.lsp.get_client_by_id(1)

    local success, err = pcall(client.request.textDocument_diagnostic, {}, 0, { timeout = 10 })
    assert.False(success)
    assert.Not.Nil(string.find(err, "Client 1 has shut down"))
  end)

  a.it("returns a response for whether a method is supported", function()
    local expected_result = false
    local expected_method = "textDocument/diagnostic"
    local expected_opts = { a = "b" }
    vim.lsp.get_client_by_id = function(id)
      return {
        supports_method = function(method, opts)
          assert.equals(expected_method, method)
          assert.same(expected_opts, opts)
          return expected_result
        end,
      }
    end
    local client = nio.lsp.get_client_by_id(1)
    local result = client.supports_method.textDocument_diagnostic(expected_opts)
    assert.equals(expected_result, result)
  end)
end)
