-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
-- Configure nvterm to use the default options

vim.opt.formatoptions:remove({ "c", "r", "o" }) -- Remove comment continuation

local context_ok, dotfiles_context = pcall(require, "config.dotfiles_context")
local resolved_platform = context_ok and dotfiles_context.platform or nil
local resolved_shell = context_ok and dotfiles_context.shell or "zsh"

if resolved_shell == "zsh" and vim.fn.executable("zsh") == 1 then
  vim.o.shell = vim.fn.exepath("zsh")
elseif resolved_platform == "macos" or resolved_platform == "linux" or resolved_platform == "wsl" then
  vim.o.shell = "/bin/zsh"
elseif vim.fn.executable("pwsh") == 1 then
  vim.o.shell = "pwsh"
else
  vim.o.shell = "powershell"
end
