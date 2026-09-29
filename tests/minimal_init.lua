local plenary_dir = os.getenv("PLENARY_DIR") or "/tmp/plenary.nvim"
local is_not_a_directory = vim.fn.isdirectory(plenary_dir) == 0
if is_not_a_directory then
  vim.fn.system({"git", "clone", "https://github.com/nvim-lua/plenary.nvim", plenary_dir})
end

vim.opt.rtp:append(".")
vim.opt.rtp:append(plenary_dir)

-- master (not the default `main` branch, a from-scratch rewrite with a
-- different API requiring the external tree-sitter-cli binary) is the
-- branch that still ships nvim-treesitter.configs/ensure_installed/sync_install.
local treesitter_dir = os.getenv("TREESITTER_DIR") or "/tmp/nvim-treesitter"
if vim.fn.isdirectory(treesitter_dir) == 0 then
  vim.fn.system({ "git", "clone", "--branch", "master", "https://github.com/nvim-treesitter/nvim-treesitter", treesitter_dir })
end
vim.opt.rtp:append(treesitter_dir)

require("nvim-treesitter.configs").setup({
  ensure_installed = { "typescript", "javascript", "lua", "go", "python" },
  sync_install = true,
})

vim.cmd("runtime plugin/plenary.vim")
require("plenary.busted")
