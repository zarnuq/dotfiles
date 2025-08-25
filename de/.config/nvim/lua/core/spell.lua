-- lua/core/spell.lua

-- Enable spellcheck automatically for certain filetypes
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "text" },
  callback = function()
    vim.opt_local.spell = true
    vim.opt_local.spelllang = { "en_us" }  -- or "en_gb", etc.
  end,
})

-- Optional: keymap to auto-correct to first suggestion
vim.keymap.set("n", "<leader>sc", "z=1<CR><CR>", { desc = "Spell correct word" })
