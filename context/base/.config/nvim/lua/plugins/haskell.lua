return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}

      local wanted = {
        "haskell",
      }

      for _, parser in ipairs(wanted) do
        if not vim.tbl_contains(opts.ensure_installed, parser) then
          table.insert(opts.ensure_installed, parser)
        end
      end
    end,
  },

  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}

      opts.servers.hls = vim.tbl_deep_extend("force", opts.servers.hls or {}, {
        mason = false,
        filetypes = { "haskell", "lhaskell", "cabal" },
        settings = {
          haskell = {
            checkParents = "CheckOnSave",
            checkProject = true,
            plugin = {
              cabal = { globalOn = true },
              hlint = { globalOn = true },
            },
          },
        },
      })
    end,
  },
}
