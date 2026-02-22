return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}

      local wanted = {
        "ruff",
        "ty",
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
      opts.setup = opts.setup or {}

      -- LazyVim's python extra enables Ruff + Pyright/BasedPyright by default.
      -- We use Ruff + ty for Python instead.
      opts.servers.pyright = vim.tbl_deep_extend("force", opts.servers.pyright or {}, {
        enabled = false,
      })
      opts.servers.basedpyright = vim.tbl_deep_extend("force", opts.servers.basedpyright or {}, {
        enabled = false,
      })
      opts.servers.ruff_lsp = vim.tbl_deep_extend("force", opts.servers.ruff_lsp or {}, {
        enabled = false,
      })
      opts.servers.ruff = vim.tbl_deep_extend("force", opts.servers.ruff or {}, {
        enabled = true,
        init_options = {
          settings = {
            -- Ruff LSP settings can go here, e.g. logLevel = "debug"
          },
        },
      })
      opts.servers.ty = vim.tbl_deep_extend("force", opts.servers.ty or {}, {
        enabled = true,
      })

      -- Ruff docs recommend disabling hover when using another Python LSP.
      opts.setup.ruff = function(_, server_opts)
        local on_attach = server_opts.on_attach
        server_opts.on_attach = function(client, bufnr)
          client.server_capabilities.hoverProvider = false
          if on_attach then
            on_attach(client, bufnr)
          end
        end
        return false
      end
      opts.setup.ruff_lsp = function()
        return false
      end
    end,
  },
}
