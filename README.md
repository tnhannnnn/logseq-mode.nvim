# logseq-mode.nvim

A Neovim plugin for editing [Logseq](https://logseq.com/) graphs.

It provides:
- **Smart Indentation**: `<Tab>` and `<S-Tab>` move the entire bullet tree (parent + children).
- **Auto-bullet**: `<CR>`, `o`, and `O` automatically continue the bullet list.
- **Strict Formatting**: An `awk`-based formatter (via `conform.nvim`) that cleans up `collapsed::true` and enforces hierarchy/indentation levels compatible with Logseq.
- **Daily Note Access**: `:LogseqDaily` or Lua API.
- **Hoisting**: Focus on the current block (`<leader>zl`).

## Installation

### using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "dir", -- Replace with git url if you push this, e.g. "username/logseq-mode.nvim"
  dir = "/path/to/logseq-mode.nvim", -- If local
  dependencies = {
    "stevearc/conform.nvim", -- Optional, for formatting
    "folke/snacks.nvim",     -- Optional, for grep picker
  },
  opts = {
    logseq_dir = "~/logseq-graph", -- Path to your graph
    obsidian_dir = "~/main-vault", -- Optional, for unified search
  },
  config = function(_, opts)
    require("logseq_mode").setup(opts)
  end,
}
```

## Configuration

### Formatters (Conform.nvim)

To enable the fix-formatting on save, you need to configure `conform.nvim` to use the `logseq_fixer`.

```lua
{
  "stevearc/conform.nvim",
  opts = function(_, opts)
    opts.formatters_by_ft = opts.formatters_by_ft or {}
    
    -- Add logseq_fixer to markdown
    -- It only runs if the file is inside the configured logseq_dir
    if not opts.formatters_by_ft.markdown then
      opts.formatters_by_ft.markdown = { "logseq_fixer" }
    else
      table.insert(opts.formatters_by_ft.markdown, "logseq_fixer")
    end
  end,
}
```

### Keymaps

The plugin automatically sets buffer-local keymaps for Markdown files inside your `logseq_dir`.

| Key | Description |
| --- | --- |
| `<Tab>` | Indent current tree (Smart Indent) |
| `<S-Tab>` | Unindent current tree |
| `<CR>` (Insert) | Continue list (auto-bullet) |
| `o` / `O` | New line with bullet |
| `<leader>zl` | Hoist block (Focus) |

### API

```lua
local logseq = require("logseq_mode")

-- Open today's journal
logseq.daily_note() 

-- Search across Logseq + Obsidian (requires snacks.nvim)
logseq.unified_search()
```