return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}

      local wanted = {
        "vtsls",
        "eslint-lsp",
        "tailwindcss-language-server",
        "emmet-language-server",
        "prettierd",
      }

      for _, pkg in ipairs(wanted) do
        if not vim.tbl_contains(opts.ensure_installed, pkg) then
          table.insert(opts.ensure_installed, pkg)
        end
      end
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}

      local wanted = {
        "javascript",
        "typescript",
        "tsx",
        "html",
        "css",
        "scss",
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

      opts.servers.emmet_language_server = vim.tbl_deep_extend(
        "force",
        opts.servers.emmet_language_server or {},
        {
          enabled = true,
          filetypes = {
            "html",
            "css",
            "scss",
            "sass",
            "less",
            "javascriptreact",
            "typescriptreact",
          },
        }
      )

      opts.servers.tailwindcss = vim.tbl_deep_extend("force", opts.servers.tailwindcss or {}, {
        -- LazyVim's tailwind extra already sets defaults; we make React filetypes explicit.
        filetypes_include = {
          "javascriptreact",
          "typescriptreact",
        },
      })
    end,
  },
}
