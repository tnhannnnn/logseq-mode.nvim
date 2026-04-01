local M = {}

local PANEL_BUF_NAME = "logseq://references"
local PANEL_HEIGHT = 12
local NS_ID = vim.api.nvim_create_namespace("logseq_references")

-- ─── Ripgrep ────────────────────────────────────────────────────────────────

--- Find all files in vault_dir that contain [[note_name]]
---@param vault_dir string
---@param note_name string  filename without extension
---@return string[] list of absolute paths
local function find_references(vault_dir, note_name)
	local pattern = "\\[\\[" .. note_name .. "[\\]|#]"
	local results = vim.fn.systemlist(
		string.format('rg -l -e %s %s --glob "!logseq/**"', vim.fn.shellescape(pattern), vim.fn.shellescape(vault_dir))
	) -- exclude backup file

	-- Exclude the current file itself
	local current = vim.fn.expand("%:p")
	local refs = {}
	for _, path in ipairs(results) do
		if vim.fn.fnamemodify(path, ":p") ~= current then
			table.insert(refs, vim.fn.fnamemodify(path, ":p")) -- normalize to absolute
		end
	end
	return refs
end

-- ─── Panel buffer ───────────────────────────────────────────────────────────

--- Get existing panel buffer or create a new one
---@return integer buf
local function get_or_create_panel_buf()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == PANEL_BUF_NAME then
			return buf
		end
	end
	local buf = vim.api.nvim_create_buf(false, true) -- unlisted, scratch
	vim.api.nvim_buf_set_name(buf, PANEL_BUF_NAME)
	return buf
end

--- Find the window currently displaying the panel buffer, if any
---@param buf integer
---@return integer|nil win
local function find_panel_win(buf)
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(win) == buf then
			return win
		end
	end
	return nil
end

-- ─── Rendering ──────────────────────────────────────────────────────────────

--- Write lines into the panel buffer and set highlights
---@param buf integer
---@param note_name string
---@param refs string[]
---@return string[] paths  ordered list matching rendered lines (for jumping)
local function render_panel(buf, note_name, refs)
	local header = string.format(" References to [[%s]]  %d found", note_name, #refs)
	local separator = string.rep("─", 60)

	local lines = { header, separator }
	local paths = {} -- parallel list: paths[i] corresponds to lines[i+2]

	if #refs == 0 then
		table.insert(lines, "  (no references found)")
	else
		for _, path in ipairs(refs) do
			local display = vim.fn.fnamemodify(path, ":~:.") -- relative to home/cwd
			table.insert(lines, "  " .. display)
			table.insert(paths, path)
		end
	end

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false

	-- Highlights
	vim.api.nvim_buf_clear_namespace(buf, NS_ID, 0, -1)
	vim.api.nvim_buf_add_highlight(buf, NS_ID, "Title", 0, 0, -1) -- header
	vim.api.nvim_buf_add_highlight(buf, NS_ID, "Comment", 1, 0, -1) -- separator
	for i = 0, #paths - 1 do
		vim.api.nvim_buf_add_highlight(buf, NS_ID, "Directory", i + 2, 0, -1)
	end

	return paths
end

-- ─── Keymaps ────────────────────────────────────────────────────────────────

--- Set buffer-local keymaps for the panel
---@param buf integer
---@param win integer  the panel window (for closing)
---@param source_win integer  the window to return focus to after jump
---@param paths string[]
local function set_panel_keymaps(buf, win, source_win, paths)
	local opts = { buffer = buf, silent = true, nowait = true }

	-- <CR>: jump to reference under cursor
	vim.keymap.set("n", "<CR>", function()
		local row = vim.api.nvim_win_get_cursor(0)[1]
		local idx = row - 2 -- header=1, separator=2, refs start at 3
		if idx >= 1 and idx <= #paths then
			-- Focus back to source window and open file
			if vim.api.nvim_win_is_valid(source_win) then
				vim.api.nvim_set_current_win(source_win)
			end
			vim.cmd("edit " .. vim.fn.fnameescape(paths[idx]))
		end
	end, vim.tbl_extend("force", opts, { desc = "Jump to reference" }))

	-- q / <Esc>: close panel
	local function close_panel()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
		if vim.api.nvim_win_is_valid(source_win) then
			vim.api.nvim_set_current_win(source_win)
		end
	end
	vim.keymap.set("n", "q", close_panel, vim.tbl_extend("force", opts, { desc = "Close references panel" }))
	vim.keymap.set("n", "<Esc>", close_panel, vim.tbl_extend("force", opts, { desc = "Close references panel" }))
end

-- ─── Badge (virtual text at top-right) ─────────────────────────────────────

local BADGE_NS = vim.api.nvim_create_namespace("logseq_references_badge")

--- Show a small reference count badge on the first line of the source buffer
---@param source_buf integer
---@param count integer
local function show_badge(source_buf, count)
	if not vim.api.nvim_buf_is_valid(source_buf) then
		return
	end
	vim.api.nvim_buf_clear_namespace(source_buf, BADGE_NS, 0, -1)
	if count == 0 then
		return
	end

	local label = string.format("  %d ref%s", count, count == 1 and "" or "s")
	vim.api.nvim_buf_set_extmark(source_buf, BADGE_NS, 0, 0, {
		virt_text = { { label, "DiagnosticHint" } },
		virt_text_pos = "right_align",
	})
end

-- ─── Public API ─────────────────────────────────────────────────────────────

--- Toggle the references panel for the current buffer
function M.toggle_references()
	if vim.fn.executable("rg") == 0 then
		vim.notify("logseq-mode: ripgrep (rg) is required for references panel", vim.log.levels.ERROR)
		return
	end

	local current_file = vim.fn.expand("%:p")
	if current_file == "" then
		vim.notify("logseq-mode: no file open", vim.log.levels.WARN)
		return
	end

	local note_name = vim.fn.fnamemodify(current_file, ":t:r")
	local vault_dir = require("logseq_mode.config").options.logseq_dir
	local source_win = vim.api.nvim_get_current_win()
	local source_buf = vim.api.nvim_get_current_buf()

	local panel_buf = get_or_create_panel_buf()
	local panel_win = find_panel_win(panel_buf)

	-- Toggle: if panel already open, close it
	if panel_win then
		vim.api.nvim_win_close(panel_win, true)
		return
	end

	-- Find references
	local refs = find_references(vault_dir, note_name)

	-- Show badge on source buffer
	show_badge(source_buf, #refs)

	-- Set buffer options before opening split
	vim.bo[panel_buf].buftype = "nofile"
	vim.bo[panel_buf].swapfile = false
	vim.bo[panel_buf].bufhidden = "hide"
	vim.bo[panel_buf].filetype = "logseq-references"

	-- Open split at bottom
	vim.cmd("botright " .. PANEL_HEIGHT .. "split")
	panel_win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(panel_win, panel_buf)

	-- Window options
	vim.wo[panel_win].number = false
	vim.wo[panel_win].relativenumber = false
	vim.wo[panel_win].signcolumn = "no"
	vim.wo[panel_win].wrap = false
	vim.wo[panel_win].cursorline = true
	vim.wo[panel_win].winfixheight = true

	-- Render content
	local paths = render_panel(panel_buf, note_name, refs)

	-- Set keymaps
	set_panel_keymaps(panel_buf, panel_win, source_win, paths)

	-- Move cursor to first reference line (line 3)
	if #refs > 0 then
		vim.api.nvim_win_set_cursor(panel_win, { 3, 2 })
	end
end

--- Refresh badge for current buffer (call on BufEnter)
function M.refresh_badge(vault_dir)
	if vim.fn.executable("rg") == 0 then
		return
	end

	local current_file = vim.fn.expand("%:p")
	if current_file == "" then
		return
	end

	local note_name = vim.fn.fnamemodify(current_file, ":t:r")
	local source_buf = vim.api.nvim_get_current_buf()

	-- Run async to avoid blocking BufEnter
	vim.defer_fn(function()
		if not vim.api.nvim_buf_is_valid(source_buf) then
			return
		end
		local refs = find_references(vault_dir, note_name)
		show_badge(source_buf, #refs)
	end, 50)
end

return M
