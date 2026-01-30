# Testing with mini.test

This directory uses [mini.test](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-test.md) for nvim-mobius tests. Tests are organized in two layers: **unit** (comprehensive) and **e2e** (user-facing scenarios).

- **Setup**: `minitest_setup.lua`
- **Unit tests**: `unit/test_*.lua` - isolated rule and engine logic
- **E2E tests**: `e2e/test_*.lua` - complete workflows with child Neovim

## Dependencies

Tests are managed via Makefile; dependencies go to `.deps/`:

- **`make .deps`**: Clone mini.nvim to `.deps/mini.nvim` (skipped if already present)
- **`make test`**: Run `.deps` then all tests

## Running tests

### Makefile (recommended)

```bash
make .deps   # Fetch dependencies only
make test    # Fetch deps + run all tests
```

### Direct Neovim

```bash
# Run all tests (after make .deps)
nvim --headless -u tests/minitest_setup.lua -c "lua MiniTest.run()" -c "qa"

# Run only unit tests
nvim --headless -u tests/minitest_setup.lua -c "lua MiniTest.run_file('tests/unit')" -c "qa"

# Run only e2e tests
nvim --headless -u tests/minitest_setup.lua -c "lua MiniTest.run_file('tests/e2e')" -c "qa"

# Run a specific file
nvim --headless -u tests/minitest_setup.lua -c "lua MiniTest.run_file('tests/unit/test_numeric_rules.lua')" -c "qa"
```

## Test organization

Tests split into **two layers** for clarity and speed:

### Unit Tests (`unit/`)

Comprehensive coverage of individual components in isolation. Direct function calls without UI.

- **`test_numeric_rules.lua`**: Integer, hex, octal, decimal rules
  - Focuses on: add/find correctness, edge cases (wrap, negative, large numbers)
- **`test_constant_rules.lua`**: Boolean, yes/no, on/off, and/or, HTTP method rules
  - Focuses on: cycling behavior, case preservation, variants
- **`test_complex_rules.lua`**: Date, semver, hexcolor, markdown, paren, case rules
  - Focuses on: overflow handling, component detection, boundary conditions
- **`test_helpers.lua`**: Match scorer, word boundary detection, rule result utilities
  - Focuses on: cursor priority, proximity scoring, index conversions
- **`test_engine_core.lua`**: Execution modes, rule selection, caching, custom rules
  - Focuses on: priority ordering, buffer-local rules, error handling
  - Includes detailed cursor positioning (match.col, offset calculation)

### E2E Tests (`e2e/`)

End-to-end workflows with real Neovim (child process). Tests complete user interactions.

- **`test_user_scenarios.lua`**: All built-in rules with real keybindings
  - Core scenarios: increment/decrement, wrap behavior, multi-rule priority
  - Validates text transformation and cursor position (stay on correct line)
  - Uses child Neovim with full plugin runtime

## Testing Strategy

### Two-layer approach

| Layer | Purpose | Speed | Scope |
|-------|---------|-------|-------|
| **Unit** | Fast feedback, exhaustive edge cases | <100ms | Direct function calls, all branches |
| **E2E** | Integration validation, real keybindings | ~1-2s | User workflows with child Neovim |

**Why split?**

1. **Speed**: Unit tests run locally without spawning child processes
2. **Coverage**: Unit tests explore edge cases (wrap, boundary, negative) via direct calls; E2E validates the complete path works
3. **Separation of concerns**: 
   - Unit tests verify arithmetic (e.g., wrap logic, date overflow)
   - E2E tests verify UI integration (keybinding→execution→buffer update→cursor movement)

### Test focus by layer

**Unit tests cover:**
- Correctness of add/find functions
- Edge cases: wrap behavior, boundary conditions, negative numbers
- Overflow handling (dates, time)
- Case preservation and variants
- Priority and scoring logic
- Detailed cursor positioning (match.col calculation, offset handling)

**E2E tests cover:**
- Complete workflow: real Neovim, keybindings, buffer updates
- Text transformation correctness across all rule types
- Cursor stays on correct line after operation
- Multi-rule priority (e.g., hex vs integer matching)
- No regressions in user-facing behavior

## Adding tests

Use mini.test native API:

```lua
local MiniTest = require("mini.test")
local expect = MiniTest.expect

local T = MiniTest.new_set({
  hooks = {
    pre_case = function() end,  -- setup before each test
    post_case = function() end,  -- teardown after each test
  },
})

T["Test name"] = function()
  expect.equality(actual, expected)
end

-- Nested set
local nested = MiniTest.new_set()
nested["Sub test"] = function() ... end
T["Module"] = nested

return T
```

## Assertions

- `expect.equality(left, right)` – equal
- `expect.no_equality(left, right)` – not equal
- `expect.error(f, pattern?)` – `f` throws and message matches `pattern`
- `expect.no_error(f, ...)` – call does not throw

See [mini.test docs](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-test.md) for more.
