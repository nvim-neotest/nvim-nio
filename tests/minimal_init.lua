local lazypath = vim.fn.stdpath("data") .. "/lazy"
vim.notify = print
vim.opt.rtp:append(".")
vim.opt.rtp:append(lazypath .. "/plenary.nvim")
vim.cmd("runtime! plugin/plenary.vim")
vim.opt.swapfile = false
A = function(...)
  print(vim.inspect(...))
end
