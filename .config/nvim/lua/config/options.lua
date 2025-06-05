-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
-- Configure nvterm to use the default options

vim.opt.formatoptions:remove({ "c", "r", "o" }) -- Remove comment continuation

local os_name = vim.fn.system("uname"):gsub("\n", "")
if os_name == "Darwin" or os_name == "Linux" then
  vim.o.shell = "/bin/zsh" -- Change to your preferred shell if necessary
elseif vim.fn.executable("pwsh") == 1 then
  vim.o.shell = "pwsh"
else
  vim.o.shell = "powershell"
end
