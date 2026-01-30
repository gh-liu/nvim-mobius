-- E2E tests: blackbox scenarios with real keybinding and child Neovim
-- Verify user-facing workflows: <C-a>, <C-x>, g<C-a>, dot repeat, visual mode

local MiniTest = require("mini.test")
local expect = MiniTest.expect

-- Path to plugin root (for child neovim init)
local plugin_path = vim.fn.getcwd()

-- Inlined child init: load nvim-mobius with default rules
local CHILD_INIT_LUA = [[
local plugin_path = vim.fn.getcwd()
vim.opt.runtimepath:prepend(plugin_path)
package.path = plugin_path .. "/lua/?.lua;" .. plugin_path .. "/lua/?/init.lua;" .. package.path
vim.cmd("runtime! plugin/mobius.lua")
local rules = {
  -- Numeric
  "mobius.rules.numeric.integer",
  require("mobius.rules.numeric.hex"),  -- Direct module (has .find directly)
  require("mobius.rules.numeric.octal"),  -- Direct module (has .find directly)
  require("mobius.rules.numeric.decimal_fraction"),  -- Direct module
  -- Boolean & Constants
  "mobius.rules.constant.bool",
  "mobius.rules.constant.yes_no",
  "mobius.rules.constant.on_off",
  "mobius.rules.constant.and_or",
  "mobius.rules.constant.http_method",
  -- Complex
  "mobius.rules.paren",
  -- Date/Time
  "mobius.rules.date.ymd",
  "mobius.rules.date.iso",
  "mobius.rules.date.dmy",
  "mobius.rules.date.mdy",
  "mobius.rules.date.md",
  "mobius.rules.date.time_hm",
  "mobius.rules.date.time_hms",
}
table.insert(rules, require("mobius.rules.hexcolor")())
table.insert(rules, require("mobius.rules.semver")())
table.insert(rules, require("mobius.rules.markdown_header")())
table.insert(rules, require("mobius.rules.case")())
vim.g.mobius_rules = rules
]]

local child = MiniTest.new_child_neovim()

local function child_set_lines(c, lines)
	if type(lines) == "string" then
		lines = vim.split(lines, "\n")
	end
	c.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

local function child_set_cursor(c, line, col)
	c.api.nvim_win_set_cursor(0, { line, col })
end

local function child_get_lines(c)
	return c.api.nvim_buf_get_lines(0, 0, -1, false)
end

local function child_get_cursor(c)
	local pos = c.api.nvim_win_get_cursor(0)
	return { pos[1], pos[2] }
end

local function child_feedkey(c, key)
	c.type_keys(key)
	c.api.nvim_eval("1")
end

local function child_engine_execute(c, direction, step)
	step = step or 1
	local path_prefix = plugin_path .. "/lua/?.lua;" .. plugin_path .. "/lua/?/init.lua;"
	c.lua(
		"local dir, n, prefix = ...; package.path = prefix .. package.path; require('mobius.engine').execute(dir, { step = n })",
		{ direction, step, path_prefix }
	)
end

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			local tmp = vim.fn.tempname() .. ".lua"
			local f = io.open(tmp, "w")
			f:write(CHILD_INIT_LUA)
			f:close()
			child.restart({ "-u", tmp })
		end,
		post_once = function()
			child.stop()
		end,
	},
})

-- ============================================================================
-- Core Scenarios: <C-a> and <C-x>
-- ============================================================================
local increment_tests = MiniTest.new_set()

increment_tests["integer_increment_with_feedkey"] = function()
	child_set_lines(child, { "foo 123 bar" })
	child_set_cursor(child, 1, 4)
	child_feedkey(child, "<C-a>")
	expect.equality(child_get_lines(child), { "foo 124 bar" })
	-- Cursor stays on modified element (row 1, col 4)
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 4)
end

increment_tests["integer_decrement_with_feedkey"] = function()
	child_set_lines(child, { "foo 123 bar" })
	child_set_cursor(child, 1, 4)
	child_feedkey(child, "<C-x>")
	expect.equality(child_get_lines(child), { "foo 122 bar" })
	-- Cursor stays on modified element (row 1, col 4)
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 4)
end

increment_tests["integer_increment_text_and_cursor"] = function()
	child_set_lines(child, { "foo 123 bar" })
	child_set_cursor(child, 1, 4)
	child_feedkey(child, "<C-a>")
	expect.equality(child_get_lines(child), { "foo 124 bar" })
	-- Cursor should stay on modified element (row 1, col 4)
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 4)
end

increment_tests["integer_single_digit_to_double"] = function()
	child_set_lines(child, { "9" })
	child_set_cursor(child, 1, 0)
	child_feedkey(child, "<C-a>")
	expect.equality(child_get_lines(child), { "10" })
	-- Cursor should stay on modified element (row 1, col 0)
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 0)
end

increment_tests["boolean_toggle"] = function()
	child_set_lines(child, { "let x = true" })
	child_set_cursor(child, 1, 9)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "let x = false" })
	-- Cursor should move to start of replacement (match.col), which is where "true" starts
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 9)
end

increment_tests["no_match_no_change"] = function()
	child_set_lines(child, { "foo bar" })
	child_set_cursor(child, 1, 2)
	child_feedkey(child, "<C-a>")
	expect.equality(child_get_lines(child), { "foo bar" })
	expect.equality(child_get_cursor(child), { 1, 2 })
end

increment_tests["multiple_matches_on_line_cursor_on_second"] = function()
	child_set_lines(child, { "1 2 3" })
	child_set_cursor(child, 1, 2) -- on "2"
	child_feedkey(child, "<C-a>")
	expect.equality(child_get_lines(child), { "1 3 3" })
	-- Cursor should stay on modified element (row 1, col 2)
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 2)
end

T["increment"] = increment_tests

-- ============================================================================
-- Numeric Rules
-- ============================================================================
local numeric_tests = MiniTest.new_set()

numeric_tests["integer_decrement"] = function()
	child_set_lines(child, { "count 42 items" })
	child_set_cursor(child, 1, 6)
	child_engine_execute(child, "decrement", 1)
	expect.equality(child_get_lines(child), { "count 41 items" })
	-- Cursor should be on the match (row 1, col 6)
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 6)
end

numeric_tests["hex_increment"] = function()
	child_set_lines(child, { "color: 0xFF" })
	child_set_cursor(child, 1, 8)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "color: 0x100" })
	-- Cursor stays on modified element (row 1, col 8: first digit of new hex)
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 8)
end

numeric_tests["hex_decrement_wrap"] = function()
	child_set_lines(child, { "0x0" })
	child_set_cursor(child, 1, 1)
	child_engine_execute(child, "decrement", 1)
	expect.equality(child_get_lines(child), { "0xf" })
	-- Cursor stays on modified element (row 1, col 1)
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 1)
end

numeric_tests["octal_increment"] = function()
	child_set_lines(child, { "chmod 0o755 file" })
	child_set_cursor(child, 1, 6)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "chmod 0o756 file" })
	-- Cursor stays on modified element (row 1, col 6)
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 6)
end

numeric_tests["octal_uppercase"] = function()
	child_set_lines(child, { "mode 0O644" })
	child_set_cursor(child, 1, 5)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "mode 0O645" })
	-- Cursor stays on modified element (row 1, col 5)
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 5)
end

numeric_tests["decimal_increment"] = function()
	child_set_lines(child, { "price: 1.5 usd" })
	child_set_cursor(child, 1, 7)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "price: 2.5 usd" })
	-- Cursor stays on modified element (row 1, col 7)
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 7)
end

numeric_tests["decimal_decrement"] = function()
	child_set_lines(child, { "balance: 10.5" })
	child_set_cursor(child, 1, 10)
	child_engine_execute(child, "decrement", 1)
	expect.equality(child_get_lines(child), { "balance: 9.5" })
	-- Cursor stays on modified element (row 1, col 9: start of "9.5")
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 9)
end

T["numeric"] = numeric_tests

-- ============================================================================
-- Constant Rules (Boolean & Enums)
-- ============================================================================
local constant_tests = MiniTest.new_set()

constant_tests["bool_toggle"] = function()
	child_set_lines(child, { "let enabled = true" })
	child_set_cursor(child, 1, 15)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "let enabled = false" })
	-- Cursor should move to start of replacement (row 1, col 15)
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 15)
end

constant_tests["yes_no_toggle"] = function()
	child_set_lines(child, { "answer: yes" })
	child_set_cursor(child, 1, 8)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "answer: no" })
	-- Cursor on modified element (row 1, col 8)
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 8)
end

constant_tests["on_off_toggle"] = function()
	child_set_lines(child, { "status: on" })
	child_set_cursor(child, 1, 8)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "status: off" })
	-- Cursor on modified element (row 1, col 8)
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 8)
end

constant_tests["and_or_toggle"] = function()
	child_set_lines(child, { "if a && b" })
	child_set_cursor(child, 1, 5)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "if a || b" })
	-- Cursor on modified element (row 1, col 5)
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 5)
end

constant_tests["http_method_cycle"] = function()
	child_set_lines(child, { "method: GET" })
	child_set_cursor(child, 1, 8)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "method: POST" })
	-- Cursor on modified element (row 1, col 8)
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 8)
end

T["constant"] = constant_tests

-- ============================================================================
-- Date & Time Rules
-- ============================================================================
local date_tests = MiniTest.new_set()

date_tests["iso_month_increment"] = function()
	child_set_lines(child, { "2022-12-06" })
	child_set_cursor(child, 1, 6)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "2023-01-06" })
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 6)
end

date_tests["iso_day_increment"] = function()
	child_set_lines(child, { "2022-12-06" })
	child_set_cursor(child, 1, 9)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "2022-12-07" })
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 9)
end

date_tests["ymd_day_increment"] = function()
	child_set_lines(child, { "2024/01/15" })
	child_set_cursor(child, 1, 8)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "2024/01/16" })
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 8)
end

date_tests["dmy_month_increment"] = function()
	child_set_lines(child, { "15/01/2024" })
	child_set_cursor(child, 1, 3)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "15/02/2024" })
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 3)
end

date_tests["mdy_day_increment"] = function()
	child_set_lines(child, { "01/15/2024" })
	child_set_cursor(child, 1, 3)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "01/16/2024" })
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 3)
end

date_tests["md_day_increment"] = function()
	child_set_lines(child, { "01/15" })
	child_set_cursor(child, 1, 3)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "01/16" })
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 3)
end

date_tests["ymd_day_boundary"] = function()
	child_set_lines(child, { "2024/01/31" })
	child_set_cursor(child, 1, 8)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "2024/02/01" })
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 8)
end

date_tests["month_decrement_boundary"] = function()
	child_set_lines(child, { "2024/01/15" })
	child_set_cursor(child, 1, 5)
	child_engine_execute(child, "decrement", 1)
	expect.equality(child_get_lines(child), { "2023/12/15" })
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 5)
end

date_tests["time_hm_increment"] = function()
	child_set_lines(child, { "14:30" })
	child_set_cursor(child, 1, 0)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "15:30" })
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 0)
end

date_tests["time_hm_decrement"] = function()
	child_set_lines(child, { "01:30" })
	child_set_cursor(child, 1, 0)
	child_engine_execute(child, "decrement", 1)
	expect.equality(child_get_lines(child), { "00:30" })
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 0)
end

date_tests["time_hms_increment"] = function()
	child_set_lines(child, { "14:30:45" })
	child_set_cursor(child, 1, 0)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "15:30:45" })
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 0)
end

date_tests["time_hms_minute_increment"] = function()
	child_set_lines(child, { "14:30:45" })
	child_set_cursor(child, 1, 3)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "14:31:45" })
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 3)
end

T["date"] = date_tests

-- ============================================================================
-- Complex Type Rules
-- ============================================================================
local complex_type_tests = MiniTest.new_set()

complex_type_tests["semver_patch_increment"] = function()
	child_set_lines(child, { "version 1.2.3" })
	child_set_cursor(child, 1, 13)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "version 1.2.4" })
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 12)
end

complex_type_tests["semver_minor_increment"] = function()
	child_set_lines(child, { "version 1.2.3" })
	child_set_cursor(child, 1, 10)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "version 1.3.0" })
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 10)
end

complex_type_tests["hexcolor_increment"] = function()
	child_set_lines(child, { "color: #100000" })
	child_set_cursor(child, 1, 8)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "color: #110000" })
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 8)
end

complex_type_tests["markdown_level_increase"] = function()
	child_set_lines(child, { "## Header" })
	child_set_cursor(child, 1, 1)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "### Header" })
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 1)
end

complex_type_tests["markdown_level_decrease"] = function()
	child_set_lines(child, { "### Header" })
	child_set_cursor(child, 1, 1)
	child_engine_execute(child, "decrement", 1)
	expect.equality(child_get_lines(child), { "## Header" })
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 1)
end

complex_type_tests["paren_cycle"] = function()
	child_set_lines(child, { "func(x)" })
	child_set_cursor(child, 1, 4)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "func[x]" })
	-- Cursor stays on modified element (row 1, col 4)
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 4)
end

complex_type_tests["case_conversion"] = function()
	child_set_lines(child, { "myVariable" })
	child_set_cursor(child, 1, 0)
	child_engine_execute(child, "increment", 1)
	expect.equality(child_get_lines(child), { "my_variable" })
	-- Cursor stays on modified element (row 1, col 0)
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 0)
end

T["complex_type"] = complex_type_tests

-- ============================================================================
-- Mixed Rules: Priority and Selection
-- ============================================================================
local priority_scenario_tests = MiniTest.new_set()

priority_scenario_tests["rule_priority_determines_match"] = function()
	child_set_lines(child, { "0xFF 123" })
	child_set_cursor(child, 1, 1)
	child_feedkey(child, "<C-a>") -- Should match hex (priority > integer)
	expect.equality(child_get_lines(child), { "0x100 123" })
	-- Cursor should stay on modified element (row 1, col 1)
	local cursor = child_get_cursor(child)
	expect.equality(cursor[1], 1)
	expect.equality(cursor[2], 1)
end

T["priority_scenario"] = priority_scenario_tests

return T
