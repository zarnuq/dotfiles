return {
  {
    "catppuccin/nvim",
    lazy = false,
    name = "catppuccin",
    priority = 1000,
    config = function()
      -- theme-set's live palette, in Catppuccin's own key names: plain Mocha,
      -- or the wallpaper's colours. Missing or unreadable = stock Mocha.
      local path = (vim.env.XDG_STATE_HOME or vim.fn.expand("~/.local/state")) .. "/theme/palette.json"
      local ok, palette = pcall(function()
        return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
      end)
      require("catppuccin").setup({
        flavour = "mocha",
        color_overrides = { mocha = ok and palette or {} },
      })
      vim.cmd.colorscheme "catppuccin-mocha"
    end
  }
}
