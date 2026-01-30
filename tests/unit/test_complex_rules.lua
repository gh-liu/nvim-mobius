-- Unit tests for complex rules: date, semver, hexcolor, markdown_header, case, paren
-- Tests focus on find() and add() functions in isolation

local MiniTest = require("mini.test")
local expect = MiniTest.expect

local rules_date = require("mobius.rules.date")
local rules_semver = require("mobius.rules.semver")
local rules_hexcolor = require("mobius.rules.hexcolor")
local rules_markdown_header = require("mobius.rules.markdown_header")
local rules_case = require("mobius.rules.case")
local rules_paren = require("mobius.rules.paren")

local function create_test_buf(lines)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_set_current_buf(buf)
	local win = vim.api.nvim_get_current_win()
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_set_buf(win, buf)
	end
	return buf
end

local function date_add_result(ret)
	return type(ret) == "table" and ret.text or ret
end

local T = MiniTest.new_set({
	hooks = {
		pre_case = function() end,
		post_case = function() end,
	},
})

-- ============================================================================
-- Date Rule (YMD format)
-- ============================================================================
local date_tests = MiniTest.new_set()

date_tests["add_day"] = function()
	local r = rules_date("%Y/%m/%d")
	local meta = { text = "2024/01/15", pattern = "%Y/%m/%d", component = "day", captures = { "2024", "01", "15" } }
	expect.equality(date_add_result(r.add(1, meta)), "2024/01/16")
end

date_tests["add_month"] = function()
	local r = rules_date("%Y/%m/%d")
	local meta = { text = "2024/01/15", pattern = "%Y/%m/%d", component = "month", captures = { "2024", "01", "15" } }
	expect.equality(date_add_result(r.add(1, meta)), "2024/02/15")
end

date_tests["add_year"] = function()
	local r = rules_date("%Y/%m/%d")
	local meta = { text = "2024/01/15", pattern = "%Y/%m/%d", component = "year", captures = { "2024", "01", "15" } }
	expect.equality(date_add_result(r.add(1, meta)), "2025/01/15")
end

date_tests["add_month_overflow"] = function()
	local r = rules_date("%Y/%m/%d")
	local meta = { text = "2024/12/15", pattern = "%Y/%m/%d", component = "month", captures = { "2024", "12", "15" } }
	expect.equality(date_add_result(r.add(1, meta)), "2025/01/15")
end

date_tests["add_day_overflow"] = function()
	local r = rules_date("%Y/%m/%d")
	local meta = { text = "2024/01/31", pattern = "%Y/%m/%d", component = "day", captures = { "2024", "01", "31" } }
	expect.equality(date_add_result(r.add(1, meta)), "2024/02/01")
end

date_tests["add_day_decrement"] = function()
	local r = rules_date("%Y/%m/%d")
	local meta = { text = "2024/02/01", pattern = "%Y/%m/%d", component = "day", captures = { "2024", "02", "01" } }
	expect.equality(date_add_result(r.add(-1, meta)), "2024/01/31")
end

date_tests["add_leap_year_feb"] = function()
	local r = rules_date("%Y/%m/%d")
	local meta = { text = "2024/02/29", pattern = "%Y/%m/%d", component = "day", captures = { "2024", "02", "29" } }
	expect.equality(date_add_result(r.add(1, meta)), "2024/03/01")
end

date_tests["add_month_decrement"] = function()
	local r = rules_date("%Y/%m/%d")
	local meta = { text = "2024/01/15", pattern = "%Y/%m/%d", component = "month", captures = { "2024", "01", "15" } }
	expect.equality(date_add_result(r.add(-1, meta)), "2023/12/15")
end

date_tests["find_basic"] = function()
	local buf = create_test_buf({ "date: 2024/01/15" })
	local r = rules_date("%Y/%m/%d")
	local match = r.find({ row = 0, col = 6 })
	expect.equality(match ~= nil, true)
	expect.equality(match.metadata.text, "2024/01/15")
end

T["date"] = date_tests

-- ============================================================================
-- Semantic Version Rule
-- ============================================================================
local semver_tests = MiniTest.new_set()

semver_tests["add_major"] = function()
	local r = require("mobius.rules.semver")()
	local meta = { text = "1.2.3", component = "major", major = 1, minor = 2, patch = 3 }
	expect.equality(r.add(1, meta), "2.0.0")
end

semver_tests["add_minor"] = function()
	local r = require("mobius.rules.semver")()
	local meta = { text = "1.2.3", component = "minor", major = 1, minor = 2, patch = 3 }
	expect.equality(r.add(1, meta), "1.3.0")
end

semver_tests["add_patch"] = function()
	local r = require("mobius.rules.semver")()
	local meta = { text = "1.2.3", component = "patch", major = 1, minor = 2, patch = 3 }
	expect.equality(r.add(1, meta), "1.2.4")
end

semver_tests["find_cursor_before_match"] = function()
	local buf = create_test_buf({ "prefix 1.2.3 suffix" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	local r = require("mobius.rules.semver")()
	local match = r.find({ row = 0, col = 0 })
	expect.equality(match ~= nil, true)
	expect.equality(match.metadata.component, "major")
end

semver_tests["find_cursor_on_minor"] = function()
	local buf = create_test_buf({ "version 5.10.15" })
	vim.api.nvim_win_set_cursor(0, { 1, 11 })
	local r = require("mobius.rules.semver")()
	local match = r.find({ row = 0, col = 11 })
	expect.equality(match ~= nil, true)
	expect.equality(match.metadata.component, "minor")
end

T["semver"] = semver_tests

-- ============================================================================
-- Hex Color Rule
-- ============================================================================
local hexcolor_tests = MiniTest.new_set()

hexcolor_tests["add_red_component"] = function()
	local r = require("mobius.rules.hexcolor")()
	local meta = { text = "#100000", component = "r", r = 16, g = 0, b = 0, original_case = "lower" }
	expect.equality(r.add(1, meta), "#110000")
end

hexcolor_tests["add_red_component_clamp_max"] = function()
	local r = require("mobius.rules.hexcolor")()
	local meta = { text = "#FF0000", component = "r", r = 255, g = 0, b = 0, original_case = "lower" }
	expect.equality(r.add(1, meta), "#ff0000")
end

hexcolor_tests["add_blue_component_decrement"] = function()
	local r = require("mobius.rules.hexcolor")()
	local meta = { text = "#0000FF", component = "b", r = 0, g = 0, b = 255, original_case = "lower" }
	expect.equality(r.add(-1, meta), "#0000fe")
end

T["hexcolor"] = hexcolor_tests

-- ============================================================================
-- Markdown Header Rule
-- ============================================================================
local markdown_tests = MiniTest.new_set()

-- Markdown header is tested via integration (not directly via mock)
-- Skipping direct unit tests for rules that depend on buffer operations

T["markdown_header"] = markdown_tests

-- ============================================================================
-- Case Conversion Rule
-- ============================================================================
local case_tests = MiniTest.new_set()

case_tests["camel_to_snake"] = function()
	local r = require("mobius.rules.case")({ types = { "camelCase", "snake_case", "PascalCase" } })
	local meta = { text = "camelCase", case_type = "camelCase", types = { "camelCase", "snake_case", "PascalCase" } }
	expect.equality(r.add(1, meta), "camel_case")
end

case_tests["snake_to_pascal"] = function()
	local r = require("mobius.rules.case")({ types = { "camelCase", "snake_case", "PascalCase" } })
	local meta = { text = "snake_case", case_type = "snake_case", types = { "camelCase", "snake_case", "PascalCase" } }
	expect.equality(r.add(1, meta), "SnakeCase")
end

case_tests["pascal_wrap_to_camel"] = function()
	local r = require("mobius.rules.case")({ types = { "camelCase", "snake_case", "PascalCase" } })
	local meta = { text = "PascalCase", case_type = "PascalCase", types = { "camelCase", "snake_case", "PascalCase" } }
	-- PascalCase is at index 3, next is index 1 (wrap), which is camelCase
	expect.equality(r.add(1, meta), "pascalCase")
end

T["case"] = case_tests

-- ============================================================================
-- Parenthesis/Bracket Rule
-- ============================================================================
local paren_tests = MiniTest.new_set()

paren_tests["find_parens"] = function()
	local buf = create_test_buf({ "func(x)" })
	local match = rules_paren.find({ row = 0, col = 4 })
	expect.equality(match ~= nil, true)
end

paren_tests["add_paren_to_bracket"] = function()
	local buf = create_test_buf({ "func(x)" })
	local match = rules_paren.find({ row = 0, col = 4 })
	expect.equality(match ~= nil, true)
	local result = rules_paren.add(1, match.metadata)
	-- paren rule preserves content inside brackets: (x) -> [x]
	expect.equality(result, "[x]")
end

-- Cursor inside bracket content must NOT match (only ( or ) should trigger paren)
paren_tests["no_match_when_cursor_inside_content"] = function()
	local buf = create_test_buf({ "(balabalabala)" })
	-- col 5 = first 'a' inside the parens (0-indexed: 0=(, 1=b, 2=a, 3=l, 4=a, 5=b, ...)
	local match = rules_paren.find({ row = 0, col = 5 })
	expect.equality(match, nil)
end

paren_tests["match_when_cursor_on_open_bracket"] = function()
	local buf = create_test_buf({ "(bala)" })
	local match = rules_paren.find({ row = 0, col = 0 })
	expect.equality(match ~= nil, true)
end

paren_tests["match_when_cursor_on_close_bracket"] = function()
	local buf = create_test_buf({ "(bala)" })
	local match = rules_paren.find({ row = 0, col = 5 })
	expect.equality(match ~= nil, true)
end

T["paren"] = paren_tests

return T
