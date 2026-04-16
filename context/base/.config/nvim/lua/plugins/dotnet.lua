return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}

      local wanted = {
        "omnisharp",
        "csharpier",
        "netcoredbg",
      }

      for _, pkg in ipairs(wanted) do
        if not vim.tbl_contains(opts.ensure_installed, pkg) then
          table.insert(opts.ensure_installed, pkg)
        end
      end
    end,
  },

  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}

      opts.servers.omnisharp = vim.tbl_deep_extend("force", opts.servers.omnisharp or {}, {
        enable_roslyn_analyzers = true,
        organize_imports_on_format = true,
        enable_import_completion = true,
      })
    end,
  },
}
