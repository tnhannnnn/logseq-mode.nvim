local M = {}

M.awk_script = [[
  BEGIN { last_indent = -1; OFS="" }
  {
    # 1. Strip collapsed::true
    gsub(/ *collapsed::true/, "")
    
    # 2. Check for Bullet
    if ($0 ~ /^[ 	]*- /) {
      # Identify indent
      match($0, /^[ 	]*/)
      indent_str = substr($0, 1, RLENGTH)
      
      # Identify Content (after the "- ")
      match($0, /- /)
      # content starts after dash+space. 
      # Note: match sets RSTART to index of "- ".
      content = substr($0, RSTART + 2)
      # Trim leading space from content if any (to ensure strictly "- content")
      sub(/^ +/, "", content)

      # Calculate Level
      # Count Tabs
      n_tabs = gsub(/\t/, "&", indent_str)
      # Count Spaces
      n_spaces = gsub(/ /, "&", indent_str)
      
      level = n_tabs + int(n_spaces / 2)
      
      # Enforce Hierarchy
      enforce_level = level
      if (last_indent == -1) {
          # First bullet sets the base. 
          last_indent = level
          enforce_level = level
      } else {
          if (level > last_indent + 1) {
            enforce_level = last_indent + 1
          }
          last_indent = enforce_level
      }
      
      # Output
      indent_out = ""
      for (i=0; i<enforce_level; i++) indent_out = indent_out "\t"
      
      print indent_out "- " content
    } else {
      # Non-bullet
      print $0
    }
  }
]]

function M.get_config(logseq_dir)
	return {
		condition = function(self, ctx)
			local bufname = vim.api.nvim_buf_get_name(ctx.buf)
			return bufname:find(logseq_dir, 1, true) ~= nil
		end,
		command = "awk",
		args = { M.awk_script },
		stdin = true,
	}
end

return M

