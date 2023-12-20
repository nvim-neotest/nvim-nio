local nio = require("nio")

nio.run(function()

  local client = nio.lsp.get_clients({ name = "lua_ls" })[1]

  local err, response = client.request.textDocument_semanticTokens_full({
    textDocument = { uri = vim.uri_from_bufnr(0) },
  })

  assert(not err, err)

  for _, i in pairs(response and response.data or {}) do
    print(i)
  end
end)
