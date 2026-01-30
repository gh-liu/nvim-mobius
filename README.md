# nvim-mobius: Intelligent Increment/Decrement for Neovim

A powerful and extensible Neovim plugin that intelligently increments/decrements various types of values with full support for buffer-local and global rule configurations.

## Features

- 🎯 **Multi-layered rule system** - Global + buffer-local rules
- 🔌 **Fully extensible** - Custom matchers and handlers
- 💪 **Rich scenarios** - Numbers, hex, booleans, enums, dates, colors, and more
- 🎨 **Visual mode** - Sequential increment like Vim's `g<C-a>`
- ♻️ **Dot repeat** - `.` repeats last increment/decrement
- 🚀 **100% backward compatible** - Drop-in replacement for Vim's `<C-a>`/`<C-x>`

### Supported Scenarios

| Scenario | Example |
|----------|---------|
| Integer | `1` ↔ `2` ↔ `3`, supports `10<C-a>` |
| Decimal | `1.5` ↔ `2.5`, preserves decimal places |
| Hex | `0xFF` ↔ `0x100` |
| Octal | `0o755` ↔ `0o756` |
| Boolean | `true` ↔ `false` (also `True`/`False`, `TRUE`/`FALSE`) |
| Toggle | `on` ↔ `off`, `yes` ↔ `no` |
| Operators | `&&` ↔ `\|\|`, `and` ↔ `or` |
| HTTP methods | `GET` ↔ `POST` ↔ `PUT` ↔ `DELETE` |
| Brackets | `()` ↔ `[]` ↔ `{}` (handles nesting) |
| Markdown headings | `#` ↔ `##` ↔ `###` |
| Date | `2024/01/15` ↔ `2024/02/15` |
| RGB color | `rgb(100, 100, 100)` per-component increment |
| HTML tags | `<div>` ↔ `<span>` ↔ `<p>` |
| File paths | Relative/absolute path increment/decrement |
| Tree-sitter | Match by AST node type |
| LSP enum | Get config/options via LSP |

---

## Installation

Use [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "gh-liu/nvim-mobius",
  config = function()
    -- Key mappings (dot repeat supported)
    vim.keymap.set("n", "<C-a>", "<Plug>(MobiusIncrement)")
    vim.keymap.set("n", "<C-x>", "<Plug>(MobiusDecrement)")
    vim.keymap.set("n", "g<C-a>", "<Plug>(MobiusIncrementCumulative)")
    vim.keymap.set("n", "g<C-x>", "<Plug>(MobiusDecrementCumulative)")
    vim.keymap.set("x", "<C-a>", "<Plug>(MobiusIncrement)")
    vim.keymap.set("x", "g<C-a>", "<Plug>(MobiusIncrementSeq)")
    vim.keymap.set("x", "g<C-x>", "<Plug>(MobiusDecrementSeq)")
  end,
}
```

---

## Configuration

### Basic Setup

```lua
-- Global rules (lazy-loaded, default config)
vim.g.mobius_rules = {
	"mobius.rules.numeric.integer",
	"mobius.rules.numeric.hex",
	"mobius.rules.constant.bool",
	"mobius.rules.constant.yes_no",
	"mobius.rules.constant.on_off",
}
```

### Customize Pre-built Rules

```lua
local integer_rule = require("mobius.rules.numeric.integer")
local bool_rule = require("mobius.rules.constant.bool")

vim.g.mobius_rules = {
	integer_rule({ priority = 60 }), -- Higher priority
	bool_rule({ word = false }), -- Match anywhere
	"mobius.rules.numeric.hex",
}
```

### Custom Enum

```lua
local constant = require("mobius.rules.constant")

vim.g.mobius_rules = {
	"mobius.rules.numeric.integer",
	constant({ elements = { "let", "const", "var" }, word = true }),
	-- Grouped variants (cycle within groups)
	constant({ elements = {
		{ "yes", "no" },
		{ "Yes", "No" },
		{ "YES", "NO" },
	} }),
}
```

### Filetype-Specific Rules

```lua
-- Inherit global rules + add buffer-specific
vim.api.nvim_create_autocmd("FileType", {
	pattern = "typescript",
	callback = function(event)
		vim.b[event.buf].mobius_rules = {
			true, -- Inherit global
			require("mobius.rules.constant")({ elements = { "let", "const", "var" }, word = true }),
		}
	end,
})
```

### LSP Enum (Automatic)

```lua
vim.g.mobius_rules = {
	"mobius.rules.lsp_enum", -- Enabled when LSP attached
}
```

Customize LSP enum:

```lua
require("mobius.rules.lsp_enum")({
	symbol_kinds = { "EnumMember", "Key", "Constant" },
	cyclic = true,
	timeout_ms = 150,
	priority = 55,
})
```

---

## Usage

### Normal Mode

```
<C-a>        Increment at cursor
<C-x>        Decrement at cursor
10<C-a>      Increment by 10
.            Repeat last action
g<C-a>       Cumulative increment (each repeat adds more)
g<C-x>       Cumulative decrement
```

### Visual Mode

```
<C-a>        Increment all selected (same amount)
g<C-a>       Sequential increment (1, 2, 3...)
<C-x>        Decrement all selected
g<C-x>       Sequential decrement
```

**Sequential example:**

```
Before:       After g<C-a>:
foo_1         foo_2
foo_1         foo_3
foo_1         foo_4
```

**Cumulative example:**

```
Start: 5
g<C-a>  →  6   (+1)
Move to 10, press .  → 12   (+2)
Press .  → 15   (+3)
```

**Note**: Each `.` adds one more than the previous.

---

## Writing Custom Rules

### Rule Interface

```lua
{
  id = "my_rule",
  priority = 50,

  -- Find matching text
  find = function(row, col)
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)
    local line = lines[1] or ""

    local pattern = "\\d+"
    local start, end_pos = line:find(pattern)

    -- Note: end_pos is 1-indexed, col is 0-indexed
    if start and end_pos >= col + 1 then
      return {
        col = start - 1,
        end_col = end_pos - 1,
        metadata = {
          text = line:sub(start, end_pos),
        },
      }
    end
    return nil
  end,

  -- Transform matched text
  add = function(metadata, addend)
    local num = tonumber(metadata.text) + (addend or 1)
    return tostring(num)
  end,

  cyclic = false,  -- Wrap at boundaries?
}
```

### Pattern Helper

```lua
local Rules = require("mobius.rules")

Rules.pattern({
	id = "number",
	pattern = "\\d+",
	word = false,
	add = function(metadata, addend)
		return tostring(tonumber(metadata.text) + addend)
	end,
	cyclic = false,
})
```

### Tree-sitter Example

```lua
{
  id = "typescript_keyword",
  priority = 60,

  find = function(row, col)
    local buf = vim.api.nvim_get_current_buf()
    local parser = vim.treesitter.get_parser(buf, "typescript")
    local tree = parser:parse()[1]
    local root = tree:root()
    local node = root:named_descendant_for_range(row, col, row, col)

    if node and node:type() == "var" then
      local start_row, start_col, end_row, end_col = node:range()
      local text = vim.treesitter.get_node_text(node, buf)

      return {
        col = start_col,
        end_col = end_col,
        metadata = { text = text },
      }
    end
    return nil
  end,

  add = function(metadata, addend)
    local cycle = { "let", "const", "var" }
    for i, v in ipairs(cycle) do
      if v == metadata.text then
        local next_idx = ((i - 1 + addend) % #cycle) + 1
        return cycle[next_idx]
      end
    end
    return nil
  end,

  cyclic = true,
}
```

---

## API Reference

```lua
local engine = require("mobius.engine")

-- Execute increment/decrement
engine.execute("increment", {
	visual = false, -- Visual mode
	seqadd = false, -- Sequential add (visual mode)
	step = 1, -- Step size
	cumulative = false, -- Cumulative (normal mode)
	rules = nil, -- Override rules (optional)
})

-- Clear cached rules for buffer
engine.clear_cache(buf)
```

---

## Available Pre-built Rules

- `mobius.rules.numeric.integer` - Integers
- `mobius.rules.numeric.hex` - Hexadecimal (`0x...`)
- `mobius.rules.numeric.octal` - Octal (`0o...`)
- `mobius.rules.numeric.decimal_fraction` - Decimal numbers (`1.5`)
- `mobius.rules.constant.bool` - `true`/`false`
- `mobius.rules.constant.yes_no` - `yes`/`no`
- `mobius.rules.constant.on_off` - `on`/`off`
- `mobius.rules.constant` - Generic constant cycler
- `mobius.rules.lsp_enum` - LSP-based (auto-enabled with LSP)

---

## Documentation

Vim help is in `doc/mobius.txt`. Run `:helptags doc` then `:h mobius`.

For architecture and implementation details, see [DESIGN.md](DESIGN.md).

---

## License

MIT
