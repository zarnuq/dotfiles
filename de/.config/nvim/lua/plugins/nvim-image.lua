return {
    {
        "3rd/image.nvim",
        config = function()
            require("image").setup {
                backend = "kitty", -- or "ueberzug", "sixel", "tycat" depending on your setup
                integrations = {
                    markdown = {
                        enabled = true,
                        clear_in_insert_mode = false,
                    },
                    neorg = { enabled = true },
                },
            }
        end,
    }
}
