local M = {}

M.defaults = {
	logseq_dir = vim.fn.expand("~/logseq-graph"),
	-- Optional: Used for unified search if you have an obsidian vault too
	obsidian_dir = vim.fn.expand("~/main-vault"),
}

M.options = {}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M

