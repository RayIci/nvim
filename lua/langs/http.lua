---HTTP client language pack: kulala.nvim (REST-client equivalent) + kulala-fmt.
---Write .http files with standard request syntax and execute them in-place.
---@type LangPack
return {
  treesitter = { "http" },
  formatters = { http = { "kulala-fmt" } },
  mason = { "kulala-fmt" },
  packs = { { src = "mistweaverco/kulala.nvim" } },
  setup = function()
    require("kulala").setup({
      default_env = "dev",
    })

    require("which-key").add({ { "<leader>h", group = "HTTP (Kulala)" } })

    -- Buffer-local request keymaps (vim.pack has no lazy `keys` spec).
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("langs.http.maps", { clear = true }),
      pattern = { "http", "rest" },
      callback = function(ev)
        local function bmap(lhs, rhs, desc)
          vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, desc = desc })
        end
        bmap("<leader>hr", function()
          require("kulala").run()
        end, "Kulala: send request")
        bmap("<leader>ha", function()
          require("kulala").run_all()
        end, "Kulala: send all requests")
        bmap("<leader>hv", function()
          require("kulala").show_stats()
        end, "Kulala: view stats")
        bmap("<leader>hc", function()
          require("kulala").copy()
        end, "Kulala: copy as cURL")
        bmap("<leader>he", function()
          require("kulala").set_selected_env()
        end, "Kulala: set environment")
        bmap("<leader>hp", function()
          require("kulala").jump_prev()
        end, "Kulala: previous request")
        bmap("<leader>hn", function()
          require("kulala").jump_next()
        end, "Kulala: next request")
      end,
    })
  end,
}
