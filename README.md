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

Built-in rules; enable via `vim.g.mobius_rules` or `vim.b.mobius_rules`.

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
| Date | `2024/01/15` ↔ `2024/02/15` (multiple formats) |
| Semver | `1.0.0` ↔ `1.0.1`, major/minor/patch at cursor |
| Hex color | `#fff` ↔ `#100`, `#RRGGBB` per-component |
| Case style | `snake_case` ↔ `camelCase` ↔ `kebab-case` ↔ … |
| LSP enum | Get config/options via LSP (when LSP attached) |

---

## Installation

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "gh-liu/nvim-mobius",
  keys = {
    { "<C-a>", "<Plug>(MobiusIncrement)", mode = { "n", "v" }, desc = "Increment" },
    { "<C-x>", "<Plug>(MobiusDecrement)", mode = { "n", "v" }, desc = "Decrement" },
    { "g<C-a>", "<Plug>(MobiusIncrementSeq)", mode = { "n", "v" }, remap = true, desc = "Increment seq" },
    { "g<C-x>", "<Plug>(MobiusDecrementSeq)", mode = { "n", "v" }, remap = true, desc = "Decrement seq" },
  },
}
```

Defaults: plugin sets `g:mobius_rules` on load. Use `init` for filetype rules; see [Configuration](#configuration).

---

## Configuration

`g:mobius_rules` and `b:mobius_rules` are lists. Each entry may be:

- **String** — module path, lazy-loaded via `require(...)` (e.g. `"mobius.rules.numeric.integer"`).
- **Table** — a rule object `{ find, add, ... }` directly.
- **Function** — called when resolving rules; must return a rule table (or a list of rules).

Buffer rules only: the first element may be `true` to inherit `g:mobius_rules`, then append buffer-local entries.

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

### Available Pre-built Rules

Default = loaded when `g:mobius_rules` is unset (plugin sets it on load).

| Module | Description | Default |
|--------|-------------|:------:|
| `mobius.rules.numeric.integer` | Integers | ✓ |
| `mobius.rules.numeric.hex` | Hexadecimal (`0x...`) | ✓ |
| `mobius.rules.numeric.octal` | Octal (`0o...`) | ✓ |
| `mobius.rules.numeric.decimal_fraction` | Decimal numbers (`1.5`) | ✓ |
| `mobius.rules.constant.bool` | `true`/`false` | ✓ |
| `mobius.rules.constant.yes_no` | `yes`/`no` | ✓ |
| `mobius.rules.constant.on_off` | `on`/`off` | ✓ |
| `mobius.rules.constant.and_or` | `&&`/`\|\|`, `and`/`or` | |
| `mobius.rules.constant.http_method` | `GET`/`POST`/`PUT`/`DELETE` | |
| `mobius.rules.constant` | Generic constant cycler (custom elements) | |
| `mobius.rules.paren` | Brackets `()` ↔ `[]` ↔ `{}` | ✓ |
| `mobius.rules.markdown_header` | `#` ↔ `##` ↔ `###` | |
| `mobius.rules.date` | Date (iso, ymd, mdy, dmy, time_hm, time_hms) | ✓ |
| `mobius.rules.semver` | Semantic version `major.minor.patch` | |
| `mobius.rules.hexcolor` | Hex colors `#RRGGBB` / `#RGB` | |
| `mobius.rules.case` | Case style (snake_case, camelCase, etc.) | |
| `mobius.rules.lsp_enum` | LSP-based enum (when LSP attached) | |

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

A rule is a table: `{ id?, priority?, find, add, cyclic? }`. `find(cursor)` returns `{ col, end_col, metadata }` or `nil`; `add(metadata, addend)` returns the new text. Use the pattern helper for regex-based rules:

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

For the full rule interface and pattern options, see `doc/mobius.txt` (`:h mobius-custom-rules`).

---

## License

MIT
