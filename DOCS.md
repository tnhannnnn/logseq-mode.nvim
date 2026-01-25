# Documentation

**logseq-mode.nvim** is a comprehensive Neovim plugin designed to bring the Logseq workflow into Neovim. It handles the quirks of Logseq's markdown format (tab indentation, specific properties) and provides a fluid editing experience with auto-formatting, smart indentation, and daily journaling capabilities.

---

## Features

### 1. Smart Tree Indentation
Move entire blocks (a parent bullet and all its children) seamlessly.
- **Indent**: Moves the current line and all nested children to the right.
- **Unindent**: Moves the current line and all nested children to the left.
- **Context-Aware**: Respects the structural hierarchy of your outline.

### 2. Auto-Bullet & List Continuation
Type naturally without manually adding dashes.
- **Enter (`<CR>`)**: In Insert mode, pressing Enter automatically adds a new bullet (`- `) on the next line.
    - If the current line is an empty bullet, pressing Enter again removes the bullet (exiting the list).
- **`o` / `O`**: In Normal mode, these keys create a new bulleted line below or above the current line, respectively.

### 3. Strict Formatting (Conform.nvim Integration)
Keeps your graph clean and Logseq-compatible.
- **Removes Artifacts**: Automatically strips `collapsed::true` properties to ensure all content is visible and searchable in Neovim.
- **Enforces Indentation**: Uses an efficient `awk` script to enforce tab-based indentation and correct hierarchy levels (e.g., preventing a child from being indented more than one level deeper than its parent).

### 4. Daily Journaling
Quickly access your daily notes.
- Automatically calculates today's date and opens the corresponding journal file in your graph (`/journals/YYYY_MM_DD.md`).

### 5. Unified Search
Search across your "Second Brain."
- If configured, searches both your Logseq graph and any additional directories simultaneously.
- *Requires `snacks.nvim`.*

### 6. Hoisting (Zoom/Focus)
Focus on a specific block, mimicking Logseq's "Zoom In" feature.
- Moves the cursor to the start of the block content.
- Scrolls the window to position the block at the top-left, maximizing visibility.

### 7. Dynamic GUI Styling
- Automatically increases `linespace` (e.g., in Neovide) when entering a Logseq buffer to improve readability.
- Restores default spacing when leaving.

---

## Keybindings

These keybindings are **buffer-local** and only active when editing a Markdown file inside your configured `logseq_dir`.

| Mode | Key | Action | Description |
| :--- | :--- | :--- | :--- |
| **Normal** | `<Tab>` | `Smart Indent` | Indent the current bullet tree (parent + children). |
| **Normal** | `<S-Tab>` | `Smart Unindent` | Unindent the current bullet tree. |
| **Normal** | `o` | `New Bullet Below` | Create a new line with a bullet below the cursor. |
| **Normal** | `O` | `New Bullet Above` | Create a new line with a bullet above the cursor. |
| **Normal** | `<leader>zl` | `Hoist Block` | Focus/Zoom on the current block. |
| **Insert** | `<CR>` | `Continue List` | Create a new bullet on the next line. |

---

## Configuration

### Setup Options
Pass these options to the `setup()` function.

```lua
require("logseq_mode").setup({
  -- Path to your Logseq graph (Required)
  logseq_dir = "~/logseq-graph",
  
  -- List of additional directories to include in unified search (Optional)
  additional_dirs = { "~/main-vault" },
  
  -- Extra line spacing for GUI clients (e.g., Neovide)
  -- Default: 4
  linespace = 4,
})
```

### Buffer Settings
When a file is detected as part of your Logseq graph, the following local options are automatically set:
- `foldmethod = "indent"`
- `shiftwidth = 0` (Uses `tabstop`)
- `tabstop = 2` (Logseq standard)
- `expandtab = false` (Uses real tabs)
- `wrap = true`
- `breakindent = true`
- `scrolloff = 0`

---

## Commands & API

### User Commands

- **`:LogseqDaily`**
  Opens today's journal page (`journals/YYYY_MM_DD.md`). Creates the file if it doesn't exist (standard Neovim file behavior).

### Lua API

You can access these functions via `require("logseq_mode")`.

#### `daily_note()`
Opens today's journal.
```lua
require("logseq_mode").daily_note()
```

#### `unified_search()`
Triggers a grep picker searching both `logseq_dir` and `additional_dirs`.
*Requires `snacks.nvim` installed.*
```lua
require("logseq_mode").unified_search()
```

---

## Formatting Setup

To enable the "Strict Formatting" features (cleaning `collapsed::true`, fixing indentation), you must configure `conform.nvim`.

The plugin exports a custom formatter `logseq_fixer` that is only active for files within your `logseq_dir`.

```lua
-- In your conform.nvim config
{
  "stevearc/conform.nvim",
  opts = function(_, opts)
    opts.formatters_by_ft = opts.formatters_by_ft or {}
    
    -- Ensure logseq_fixer runs on Markdown files
    if not opts.formatters_by_ft.markdown then
      opts.formatters_by_ft.markdown = { "logseq_fixer" }
    else
      table.insert(opts.formatters_by_ft.markdown, "logseq_fixer")
    end
  end,
}
```
