local M = {}

-- Extract the file name from the wiki link under the cursor
local function get_wikilink_under_cursor()
	local line = vim.api.nvim_get_current_line()
	local col = vim.api.nvim_win_get_cursor(0)[2] + 1 -- 1-indexed
	-- Find all [[...]] in the line
	for link_text in line:gmatch("%[%[(.-)%]%]") do
		local start_pos = line:find("%[%[" .. vim.pesc(link_text) .. "%]%]")
		local end_pos = start_pos + #link_text + 3 -- length of "[[" + text + "]]"
		if col >= start_pos and col <= end_pos then
			-- Strip alias if present: [[file|alias]] → return "file"
			return link_text:match("^([^|#]+)") -- also strips heading anchors (#)
		end
	end
	return nil
end

-- Find a file by name using ripgrep
local function find_file_by_name(vault_dir, filename)
	-- Normalize: strip .md extension if already present
	local search_name = filename:gsub("%.md$", "")
	local result = vim.fn.systemlist(
		string.format("rg --files %s | rg -i %s", vim.fn.shellescape(vault_dir), vim.fn.shellescape(search_name))
	)
	-- Filter results to exact filename matches (not just paths that contain the string)
	for _, path in ipairs(result) do
		local fname = vim.fn.fnamemodify(path, ":t:r") -- get filename without extension
		if fname:lower() == search_name:lower() then
			return path
		end
	end
	-- Fallback: return the first result if no exact match found
	return result[1]
end

-- Follow the wiki link under the cursor
function M.follow_wikilink(vault_dir, open_cmd)
	open_cmd = open_cmd or "edit" -- default: open in current buffer
	local link = get_wikilink_under_cursor()
	if not link then
		vim.notify("No wiki link under cursor", vim.log.levels.WARN)
		return
	end
	if not vault_dir then
		vault_dir = vim.fn.getcwd()
		vim.notify("No vault_dir, using cwd: " .. vault_dir, vim.log.levels.INFO)
	end
	local filepath = find_file_by_name(vault_dir, link)
	if filepath then
		vim.cmd(open_cmd .. " " .. vim.fn.fnameescape(filepath))
	else
		-- Page does not exist → ask whether to create it
		vim.ui.select({ "Yes", "No" }, {
			prompt = string.format('Page "%s" is not existed. Create new?', link),
		}, function(choice)
			if choice == "Yes" then
				local new_path = vault_dir .. "/" .. link .. ".md"
				vim.cmd(open_cmd .. " " .. vim.fn.fnameescape(new_path))
			end
		end)
	end
end

return M
