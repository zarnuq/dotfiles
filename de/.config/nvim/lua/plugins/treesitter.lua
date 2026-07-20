return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
    config = function()
      local install = require("nvim-treesitter.install")
      local installed = require("nvim-treesitter.config").get_installed()
      for _, lang in ipairs({ "markdown", "markdown_inline" }) do
        if not vim.list_contains(installed, lang) then
          install.install({ lang })
        end
      end

      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
          if lang then
            if not pcall(vim.treesitter.start, args.buf, lang) then
              install.install({ lang })
            end
          end
        end,
      })
    end,
  }
}
