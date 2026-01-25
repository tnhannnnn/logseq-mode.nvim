local Config = require("logseq_mode.config")
local Formatter = require("logseq_mode.formatter")

local M = {}

-- Helper to indent/unindent a tree
local function move_tree(direction)
	local start_line = vim.fn.line(".")
	local current_indent = vim.fn.indent(start_line)
	local last_line = vim.fn.line("$")
	local end_line = start_line

	-- Find the range of children
	for l = start_line + 1, last_line do
		local line_text = vim.fn.getline(l)
		-- Only check indent of non-empty lines
		if line_text:match("%S") then
			local next_indent = vim.fn.indent(l)
			if next_indent <= current_indent then
				break
			end
			end_line = l
		else
			-- Include empty lines in the block
			end_line = l
		end
	end

	-- Construct the range command (e.g., ":10,15>")
	local cmd_char = direction == "in" and ">" or "<"
	local cmd = string.format("%d,%d%s", start_line, end_line, cmd_char)

	-- Save cursor position to prevent jumping
	local cursor_pos = vim.api.nvim_win_get_cursor(0)

	vim.cmd(cmd)

	-- Restore cursor
	pcall(vim.api.nvim_win_set_cursor, 0, cursor_pos)
end

-- Helper for auto-bullet
local function get_bullet_prefix()
	local line = vim.api.nvim_get_current_line()
	-- Match leading whitespace + bullet + space
	local indent, bullet = line:match("^(%s*)(%- )")
	if indent and bullet then
		return indent .. "- "
	end
	return nil
end

function M.daily_note()
	local date = os.date("%Y_%m_%d")
	local path = Config.options.logseq_dir .. "/journals/" .. date .. ".md"
	vim.cmd("edit " .. path)
end

function M.unified_search()
	local ok, snacks = pcall(require, "snacks")
	if not ok then
		vim.notify("Snacks.nvim is required for unified search", vim.log.levels.ERROR)
		return
	end

	snacks.picker.grep({
		dirs = { Config.options.logseq_dir, Config.options.obsidian_dir },
		title = "Unified Search (Logseq + Obsidian)",
	})
end

function M.hoist_block()
	-- 1. Move cursor to first non-blank character
	vim.cmd("normal! ^")
	-- 2. Scroll so current line is at the top
	vim.cmd("normal! zt")
	-- 3. Scroll horizontally so current cursor is at the left
	vim.cmd("normal! zs")
end

function M.setup(opts)
	Config.setup(opts)

	-- Register User Commands
	vim.api.nvim_create_user_command("LogseqDaily", M.daily_note, {})

	-- Register Formatter if Conform is loaded
	local has_conform, conform = pcall(require, "conform")
	if has_conform then
		conform.formatters.logseq_fixer = Formatter.get_config(Config.options.logseq_dir)
	end

	-- FileType Autocommand
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "markdown",
		callback = function(ev)
			-- Don't run on special buffers (nofile, prompt, etc.)
			if not vim.api.nvim_buf_is_valid(ev.buf) or vim.bo[ev.buf].buftype ~= "" then
				return
			end

			local bufname = ev.file
			local logseq_dir = Config.options.logseq_dir

			if not logseq_dir or type(logseq_dir) ~= "string" or not bufname or bufname == "" then
				return
			end

			if bufname:find(logseq_dir, 1, true) then
				-- Set local options
				vim.opt_local.foldmethod = "indent"
				vim.opt_local.shiftwidth = 0 -- Use tabstop
				vim.opt_local.tabstop = 2 -- Or whatever Logseq prefers
				vim.opt_local.expandtab = false -- Logseq uses real tabs
				vim.opt_local.wrap = true
				vim.opt_local.breakindent = true
				vim.opt_local.breakindentopt = "shift:2"
				vim.opt_local.scrolloff = 0

				-- Keymaps
				local map = function(mode, lhs, rhs, desc)
					vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, desc = desc, silent = true })
				end
				local map_expr = function(mode, lhs, rhs, desc)
					vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, desc = desc, expr = true, silent = true })
				end

				-- Smart Indent/Unindent
				map("n", "<Tab>", function()
					move_tree("in")
				end, "Smart Logseq Indent")
				map("n", "<S-Tab>", function()
					move_tree("out")
				end, "Smart Logseq Unindent")

				-- Auto-continuation: Enter
				map_expr("i", "<CR>", function()
					local prefix = get_bullet_prefix()
					local line = vim.api.nvim_get_current_line()
					if prefix and line == prefix then
						return "<BS><BS><CR>" -- Deletes "- " then CR
					end
					if prefix then
						return "<CR><C-u>" .. prefix
					end
					return "<CR>"
				end, "Logseq List Continuation")

				-- Auto-continuation: o
				map_expr("n", "o", function()
					local prefix = get_bullet_prefix()
					if prefix then
						return "o<C-u>" .. prefix
					end
					return "o"
				end, "Logseq New Line Below")

				-- Auto-continuation: O
				map_expr("n", "O", function()
					local prefix = get_bullet_prefix()
					if prefix then
						return "O<C-u>" .. prefix
					end
					return "O"
				end, "Logseq New Line Above")

				-- Hoisting
				map("n", "<leader>zl", M.hoist_block, "Logseq Hoist Block")
			end
		end,
	})

	-- Dynamic Line Spacing (GUI only)
	M.default_linespace = vim.opt.linespace:get() or 0
	vim.api.nvim_create_autocmd("BufEnter", {
		callback = function(ev)
			-- Don't run on special buffers
			if not vim.api.nvim_buf_is_valid(ev.buf) or vim.bo[ev.buf].buftype ~= "" then
				return
			end

			local bufname = ev.file
			local logseq_dir = Config.options.logseq_dir

			if not logseq_dir or type(logseq_dir) ~= "string" or not bufname or bufname == "" then
				return
			end

			-- Check if current buffer is in logseq dir
			if bufname:find(logseq_dir, 1, true) then
				if Config.options.linespace and Config.options.linespace > 0 then
					vim.opt.linespace = Config.options.linespace
				end
			else
				-- Restore default
				if M.default_linespace then
					vim.opt.linespace = M.default_linespace
				end
			end
		end,
	})
end

return M

