return {
  {
    "akinsho/toggleterm.nvim",
    config = true,
    cmd = "ToggleTerm",
    keys = {
      { "<F7>", "<cmd>ToggleTerm<cr>", desc = "Toggle floating terminal" },
      { "<leader>ft", false },
      { "<leader>fT", false },
      { "<c-/>", false },
    },
    opts = {
      open_mapping = [[<F7>]],
      direction = "float",
      shade_filetypes = {},
      hide_numbers = true,
      insert_mappings = true,
      terminal_mappings = true,
      start_in_insert = true,
      close_on_exit = true,
    },
  },
}
