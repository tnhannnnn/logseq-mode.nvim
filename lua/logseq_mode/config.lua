local M = {}

M.defaults = {
	logseq_dir = vim.fn.expand("~/logseq-graph"),
	-- Optional: Used for unified search if you have an obsidian vault too
	obsidian_dir = vim.fn.expand("~/main-vault"),
	-- Amount of extra space between lines (only works in GUI clients)
	linespace = 4,
}

M.options = {}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
	-- Ensure paths are expanded (e.g. handle ~)
	if M.options.logseq_dir then
		M.options.logseq_dir = vim.fn.expand(M.options.logseq_dir)
	end
	if M.options.obsidian_dir then
		M.options.obsidian_dir = vim.fn.expand(M.options.obsidian_dir)
	end
end

return M

