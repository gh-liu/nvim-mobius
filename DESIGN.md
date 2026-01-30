# DESIGN.md: Architecture & Implementation Details

This document describes the internal architecture, design decisions, and implementation details of nvim-mobius. For user-facing documentation (features, configuration, usage), see [README.md](README.md).

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Coordinate Systems & Conventions](#coordinate-systems--conventions)
3. [Rule System Internals](#rule-system-internals)
4. [Shared Helper Modules](#shared-helper-modules)
5. [Execution Engine](#execution-engine)
6. [Matching & Selection Algorithm](#matching--selection-algorithm)
7. [Performance Considerations](#performance-considerations)
8. [Extensibility Points](#extensibility-points)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│ Configuration Layer (init.lua)                      │
│ - vim.g.mobius_rules (global)                       │
│ - vim.b.mobius_rules (buffer-local)                 │
│ - String references (lazy-loaded)                    │
│ - Table definitions (direct)                        │
└────────────┬────────────────────────────────────────┘
             │
┌────────────▼────────────────────────────────────────┐
│ Shared Helpers                                      │
│ - match_scorer: unified scoring algorithm           │
│ - word_boundary: boundary checking & search         │
│ - rule_result: result factory & validation          │
└────────────┬────────────────────────────────────────┘
             │
┌────────────▼────────────────────────────────────────┐
│ Rule System                                         │
│ - Load from vim.g.mobius_rules / vim.b.mobius_rules │
│ - Rule interface: find(row, col) + add(metadata, addend)│
│ - Pattern-based / Custom matcher                    │
│ - Pre-built rules (number, hex, bool, enum, etc.)   │
│ - All rules use unified helpers for consistency     │
└────────────┬────────────────────────────────────────┘
             │
┌────────────▼────────────────────────────────────────┐
│ Matching & Selection                                │
│ - Apply rules.find() to locate matches              │
│ - Priority-based match selection                    │
│ - Context building (row, col, line, buf)            │
│ - Unified scoring via match_scorer                  │
└────────────┬────────────────────────────────────────┘
             │
┌────────────▼────────────────────────────────────────┐
│ Execution Engine                                    │
│ - execute(direction, opts)                          │
│   * direction: "increment" | "decrement"            │
│   * opts: { visual, seqadd, step, cumulative, rules }          │
│ - Buffer-aware rule caching with invalidation       │
│ - Enhanced error handling                           │
│ - Support normal/visual/sequential/cumulative modes │
│ - Cyclic & boundary behavior                        │
└────────────┬────────────────────────────────────────┘
             │
┌────────────▼────────────────────────────────────────┐
│ Buffer Operations                                   │
│ - Update text with proper cursor positioning        │
│ - Sequential increment (seqadd=true)                │
│ - Record for dot repeat                             │
└─────────────────────────────────────────────────────┘
```

### Key Design Principles

1. **Two-phase execution**: `find()` locates and parses; `add()` computes from metadata
2. **Lazy loading**: String references defer module loading until first use
3. **Buffer-local overrides**: Per-buffer rules can inherit, extend, or replace global rules
4. **Unified helpers**: Shared scoring and boundary checking ensure consistent behavior
5. **Native dot repeat**: Uses `g@` operator for normal mode, custom tracking for cumulative

---

## Coordinate Systems & Conventions

### 0-Indexed Coordinates

All internal APIs use **0-indexed coordinates** (matching Neovim's API):
- `row`: 0-indexed line number (0 = first line)
- `col`: 0-indexed column position (0 = first character)
- `end_col`: 0-indexed, inclusive (single char at col 0 has end_col = 0)

### Lua String Indexing

Lua's `string.find()` returns **1-indexed positions**. Rule implementations must convert:

```lua
-- Line from buffer (1-indexed from string.find)
local start_pos, end_pos = line:find(pattern)  -- 1-indexed

-- Return to engine (0-indexed)
return {
  col = start_pos - 1,      -- Convert to 0-indexed
  end_col = end_pos - 1,    -- Convert to 0-indexed (inclusive)
  metadata = { text = line:sub(start_pos, end_pos) },
}
```

### Cursor Position Semantics

- Cursor is at logical position between characters
- `col = 0` means before first character
- `col = length` means after last character
- Match containing cursor is preferred over matches before/after

---

## Rule System Internals

### Rule Interface Contract

Every rule must implement:

```lua
{
  id = "optional_identifier",
  priority = 50,  -- Higher = checked first

  -- Locate match at or near cursor
  find = function(row, col)
    -- Returns: { col, end_col, metadata } or nil
  end,

  -- Compute next value
  add = function(metadata, addend)
    -- Returns: string (new text) or nil (boundary)
  end,

  cyclic = false,  -- Wrap at boundaries?
}
```

### find() Semantics

**Parameters:**
- `row` (number): Line number, 0-indexed
- `col` (number): Cursor column, 0-indexed

**Returns:**
- On match: `{ col, end_col, metadata }`
  - `col`, `end_col`: 0-indexed, inclusive
  - `metadata.text`: Required, original matched text
  - Other metadata fields: Rule-specific
- No match: `nil`

**Behavior:**
- Search the line at `row` for text matching the rule
- Get line text via `vim.api.nvim_buf_get_lines(buf, row, row + 1, false)`
- Usually return matches at or after cursor column `col`
- With multiple matches, return the best one (typically closest to cursor)

### add() Semantics

**Parameters:**
- `metadata` (table): From `find`, must include `text`
- `addend` (number): Delta (+ for increment, - for decrement)

**Returns:**
- Success: New text (string)
- Boundary/failure: `nil` (respects `cyclic` option)

**Behavior:**
- Compute next value from metadata
- `cyclic = true`: Wrap at boundaries (e.g., `true` ↔ `false`)
- `cyclic = false`: Return `nil` at boundaries (no change)

### Metadata Flow

```
find() parses text → metadata (structured data)
      ↓
add() receives metadata + addend → new text
```

**Example (RGB color):**

```lua
-- find() extracts components
find = function(row, col)
  local r, g, b = line:match("rgb%((%d+),\\s*(%d+),\\s*(%d+)%)")
  return {
    col = start - 1,
    end_col = end_pos - 1,
    metadata = {
      text = "rgb(100, 50, 200)",
      component = "r",  -- Which component cursor is on
      r = 100, g = 50, b = 200,
    },
  }
end

-- add() uses parsed components
add = function(metadata, addend)
  local r, g, b = metadata.r, metadata.g, metadata.b
  if metadata.component == "r" then
    r = (r + addend) % 256
  end
  return string.format("rgb(%d, %d, %d)", r, g, b)
end
```

---

## Shared Helper Modules

### mobius.engine.match_scorer

Unified match scoring algorithm for consistent rule behavior.

```lua
local scorer = require("mobius.engine.match_scorer")

-- Calculate score for a match at cursor position
-- Higher score = better match
score = scorer.calculate_score(match_start, match_end, cursor_col, match_len)

-- Find all matches in a line using Lua pattern
-- Returns: list of {start_pos, end_pos} (1-indexed)
matches = scorer.find_all_matches(line, "%d+")

-- Find best match from candidates
-- metadata_extractor: function(text, match) -> metadata table
best = scorer.find_best_match(line, matches, cursor_col, metadata_extractor)
```

**Scoring algorithm:**
1. Match containing cursor: highest priority
2. Match before cursor: medium priority (closer is better)
3. Match after cursor: lower priority (closer is better)
4. Longer matches preferred within same category

### mobius.engine.word_boundary

Word boundary matching for rules needing complete words only.

```lua
local wb = require("mobius.engine.word_boundary")

-- Find matches with manual boundary checking
matches = wb.find_word_matches(line, "true")

-- Find matches with Lua pattern, then check boundaries
matches = wb.find_pattern_matches(line, "%d+")

-- Find matches using Lua's %f frontier pattern (most efficient)
matches = wb.find_frontier_matches(line, "%f[%w]true%f[^%w]")
```

**Use case:** Ensure `pattern "true"` matches `"true"` but not `"trueValue"`.

### mobius.engine.rule_result

Factory for consistent `find()` result structure.

```lua
local result = require("mobius.engine.rule_result")

-- Create a match result (converts 1-indexed to 0-indexed)
match = result.match(start_pos, end_pos, match_text, {extra = "metadata"})
-- Returns: {col, end_col, metadata}

-- Validate result structure (throws on error)
ok, err = result.validate(match_result)
```

---

## Execution Engine

### execute(direction, opts) Flow

```lua
local engine = require("mobius.engine")

-- Normal mode increment
engine.execute("increment", { visual = false, step = 1 })

-- Visual mode sequential (g<C-a> style)
engine.execute("increment", { visual = true, seqadd = true, step = 1 })

-- Cumulative (g<C-a> in normal mode)
engine.execute("increment", { cumulative = true })
```

**Execution steps:**

1. **Load rules**: Resolve string refs, merge global + buffer rules
2. **Get context**: Current buffer, row, col, line text
3. **Find matches**: Call `find(row, col)` on each rule (by priority)
4. **Select best**: Use match_scorer to pick winner
5. **Compute addend**: From `direction` (+/-) × `step`
6. **Transform**: Call `add(metadata, addend)` on selected rule
7. **Apply**: Replace text in buffer, position cursor
8. **Record**: For cumulative mode, save cumsum state

### Dot Repeat Implementation

**Normal mode (non-cumulative):**
Uses `g@` operator mechanism:
```
<C-a> → set operatorfunc + feedkeys("g@l") → operator callback → native . repeat
```

**Benefits:**
- ✅ Native Vim `.` repeat (no custom tracking needed)
- ✅ Count works correctly (e.g., `3<C-a>` then `.` repeats with count 3)
- ✅ Transparent to Vim's undo/redo system

**Cumulative mode:**
Uses custom state tracking:
```
g<C-a> → execute() + save cumsum → repeat_last() increases cumsum
```

**Why custom tracking for cumulative?**
Native `.` repeats the exact same operation, but cumulative mode requires increasing step (1→2→3). This state cannot be expressed in operator mechanism.

### Visual Mode Handling

**Non-sequential (same addend for all):**
```
1 1 1  →  2 2 2
```

**Sequential (addend = step × index):**
```
1 1 1  →  1 2 3
foo_1 foo_2 foo_3  →  foo_2 foo_4 foo_6
```

### Cumulative Mode (Normal Mode)

Each dot repeat adds one more than previous:

```
First g<C-a> on "5"  → "6"   (+1)
Move to "10", "."    → "12"  (+2)
"."                  → "15"  (+3)
```

**Use case:** Number lists by stepping 1, 2, 3... or increment by increasing amounts.

---

## Matching & Selection Algorithm

### Priority-Based Rule Selection

```
For each rule (sorted by priority desc):
  match = rule.find(row, col)
  if match:
    candidates.append({rule, match})

Return best_match(candidates)  -- Via match_scorer
```

### Tie-Breaking (via match_scorer)

When multiple rules match:

1. **Cursor position**: Match at cursor > before > after
2. **Proximity**: Closer to cursor is better
3. **Length**: Longer match is better (e.g., `0xFF` > `0`)

### Buffer-Aware Caching

Rules are cached per buffer with automatic invalidation:

```lua
-- Cache key: bufnr
-- Invalidate on: BufWritePost, BufRead
engine.clear_cache(buf)  -- Manual invalidation
```

---

## Performance Considerations

### Complexity

- **Rule loading**: O(R) where R = number of rules (cached per buffer)
- **Matching**: O(R × M) where M = matches per rule (typically 1-5)
- **Visual mode**: O(S) where S = selection size

### Typical Performance

- Simple rules (number, bool): ~1-2ms per operation
- Complex rules (tree-sitter, LSP): ~3-5ms per operation
- Visual mode scales linearly with selection size

### Optimization Tips

1. **Order by priority**: Higher priority rules checked first
2. **Use simple patterns**: Avoid backtracking in regex
3. **Lazy load expensive rules**: Use string refs for LSP/tree-sitter
4. **Limit rule count**: Typical config has 5-10 rules

---

## Extensibility Points

### Custom Matchers

Beyond regex, rules can use:

1. **Tree-sitter**: Match by AST node type
   ```lua
   local parser = vim.treesitter.get_parser(buf)
   local node = parser:parse()[1]:root():named_descendant_for_range(row, col, row, col)
   ```

2. **LSP**: Query completion/config options
   ```lua
   vim.lsp.buf.request(buf, "textDocument/completion", ...)
   ```

3. **External data**: File paths, env vars, timestamps

4. **Context-aware**: Buffer type, file path, cursor context

### Rule Composition

Pre-built rules can be composed:

```lua
local constant = require("mobius.rules.constant")

vim.g.mobius_rules = {
  "mobius.rules.number",
  constant({ elements = { "let", "const", "var" }, word = true }),
  constant({ elements = { { "yes", "no" }, { "Yes", "No" } } }),
}
```

### Buffer-Local Extension

```lua
-- Inherit global + add buffer-specific
vim.b[event.buf].mobius_rules = { true,
  "mobius.rules.custom_for_this_filetype",
}
```

---

## Testing

See `tests/` directory for test structure. Run tests with:

```bash
make test
# or
nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
```

---

## Future Directions

Potential areas for extension:

- Additional pre-built rules (semver, dates, UUIDs)
- Async rule evaluation for LSP/tree-sitter
- Rule profiles/presets for common workflows
- Performance profiling mode
- Rule debugging/tracing utilities
