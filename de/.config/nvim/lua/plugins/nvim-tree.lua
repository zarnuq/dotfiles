return {
  {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    lazy = false,
    dependencies = {
      "nvim-tree/nvim-web-devicons"
    },
    config = function()
      local nvim_tree = require("nvim-tree")
      local api = require("nvim-tree.api")

      local function on_attach(bufnr)
        -- Load default mappings first
        api.config.mappings.default_on_attach(bufnr)

        -- Custom keymap for "+"
        vim.keymap.set('n', '+', function()
          local node = api.tree.get_node_under_cursor()
          if node and node.type == "directory" then
            api.tree.change_root_to_node(node)
            vim.cmd("cd " .. node.absolute_path)
          end
        end, { buffer = bufnr, desc = "Enter directory and cd into it" })
      end

      nvim_tree.setup({
        update_focused_file = {
          enable = true,
          update_cwd = true,
        },
        view = {
          side = "right",
          width = 35,
        },
        on_attach = on_attach,
      })

      vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle NvimTree" })
      vim.keymap.set("n", "<leader><tab>", "<C-w>p", { desc = "Switch between file and tree" })
    end,
  }
}

