return {
  -- 'ggandor/leap.nvim',
  url = 'https://codeberg.org/andyg/leap.nvim',
  config = function()
    local leap = require 'leap'
    -- leap.add_default_mappings() -- Or customize mappings here
    vim.keymap.set({ 'n', 'x', 'o' }, 's', '<Plug>(leap-forward)')
    vim.keymap.set({ 'n', 'x', 'o' }, 'S', '<Plug>(leap-backward)')
    -- Example: Set case sensitivity
    -- leap.opts.case_sensitive = true
  end,
}
