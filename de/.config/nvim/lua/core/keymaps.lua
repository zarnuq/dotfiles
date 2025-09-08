vim.g.mapleader = ' '
vim.g.maplocalleader = ' ' 

vim.wo.number = true
vim.wo.relativenumber = true
vim.opt.termguicolors = true

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.opt.backspace = '2'
vim.opt.showcmd = true
vim.opt.laststatus = 2
vim.opt.autowrite = true
vim.opt.cursorline = true
vim.opt.autoread = true
vim.opt.clipboard = "unnamedplus"

vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.shiftround = true
vim.opt.expandtab = true

vim.keymap.set("n", "gx", function()
  local path = vim.fn.expand("<cfile>")  -- word under cursor
  if vim.fn.filereadable(path) == 1 then
    vim.cmd("edit " .. path)             -- open file in current window
  elseif vim.fn.isdirectory(path) == 1 then
    vim.cmd("Explore " .. path)          -- open dir in netrw (or nvim-tree if you use it)
  else
    print("Not a file: " .. path)
  end
end, { silent = true, noremap = true, desc = "Open file under cursor" })

