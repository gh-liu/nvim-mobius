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

semver_tests["semver_major_reset_minor_patch"] = function()
	local r = require("mobius.rules.semver")()
	local meta = { text = "1.5.3", component = "major", major = 1, minor = 5, patch = 3 }
	expect.equality(r.add(1, meta), "2.0.0")
end

semver_tests["semver_minor_reset_patch"] = function()
	local r = require("mobius.rules.semver")()
	local meta = { text = "1.5.3", component = "minor", major = 1, minor = 5, patch = 3 }
	expect.equality(r.add(1, meta), "1.6.0")
end

semver_tests["semver_major_zero_decrement"] = function()
	local r = require("mobius.rules.semver")()
	local meta = { text = "0.1.2", component = "major", major = 0, minor = 1, patch = 2 }
	local result = r.add(-1, meta)
	-- Cannot go below 0, should return nil
	expect.equality(result, nil)
end

semver_tests["semver_minor_zero_decrement"] = function()
	local r = require("mobius.rules.semver")()
	local meta = { text = "1.0.5", component = "minor", major = 1, minor = 0, patch = 5 }
	local result = r.add(-1, meta)
	-- Cannot go below 0, should return nil
	expect.equality(result, nil)
end

semver_tests["semver_patch_zero_decrement"] = function()
	local r = require("mobius.rules.semver")()
	local meta = { text = "1.2.0", component = "patch", major = 1, minor = 2, patch = 0 }
	local result = r.add(-1, meta)
	-- Cannot go below 0, should return nil
	expect.equality(result, nil)
end

semver_tests["semver_large_numbers"] = function()
	local r = require("mobius.rules.semver")()
	local meta = { text = "999.999.999", component = "patch", major = 999, minor = 999, patch = 999 }
	expect.equality(r.add(1, meta), "999.999.1000")
end

semver_tests["semver_decrement_major"] = function()
	local r = require("mobius.rules.semver")()
	local meta = { text = "5.2.1", component = "major", major = 5, minor = 2, patch = 1 }
	expect.equality(r.add(-1, meta), "4.0.0")
end

semver_tests["semver_decrement_minor"] = function()
	local r = require("mobius.rules.semver")()
	local meta = { text = "3.5.2", component = "minor", major = 3, minor = 5, patch = 2 }
	expect.equality(r.add(-1, meta), "3.4.0")
end

semver_tests["semver_decrement_patch"] = function()
	local r = require("mobius.rules.semver")()
	local meta = { text = "2.4.8", component = "patch", major = 2, minor = 4, patch = 8 }
	expect.equality(r.add(-1, meta), "2.4.7")
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

semver_tests["find_cursor_on_patch"] = function()
	local buf = create_test_buf({ "version 5.10.15" })
	vim.api.nvim_win_set_cursor(0, { 1, 14 })
	local r = require("mobius.rules.semver")()
	local match = r.find({ row = 0, col = 14 })
	expect.equality(match ~= nil, true)
	expect.equality(match.metadata.component, "patch")
end

semver_tests["find_basic"] = function()
	local buf = create_test_buf({ '"version": "1.2.3"' })
	local r = require("mobius.rules.semver")()
	local match = r.find({ row = 0, col = 12 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "1.2.3")
	end
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

hexcolor_tests["add_green_component"] = function()
	local r = require("mobius.rules.hexcolor")()
	local meta = { text = "#001000", component = "g", r = 0, g = 16, b = 0, original_case = "lower" }
	expect.equality(r.add(1, meta), "#001100")
end

hexcolor_tests["add_blue_component"] = function()
	local r = require("mobius.rules.hexcolor")()
	local meta = { text = "#000010", component = "b", r = 0, g = 0, b = 16, original_case = "lower" }
	expect.equality(r.add(1, meta), "#000011")
end

hexcolor_tests["add_red_component_clamp_max"] = function()
	local r = require("mobius.rules.hexcolor")()
	local meta = { text = "#FF0000", component = "r", r = 255, g = 0, b = 0, original_case = "lower" }
	expect.equality(r.add(1, meta), "#ff0000")
end

hexcolor_tests["add_green_component_clamp_max"] = function()
	local r = require("mobius.rules.hexcolor")()
	local meta = { text = "#00FF00", component = "g", r = 0, g = 255, b = 0, original_case = "lower" }
	expect.equality(r.add(1, meta), "#00ff00")
end

hexcolor_tests["add_blue_component_clamp_max"] = function()
	local r = require("mobius.rules.hexcolor")()
	local meta = { text = "#0000FF", component = "b", r = 0, g = 0, b = 255, original_case = "lower" }
	expect.equality(r.add(1, meta), "#0000ff")
end

hexcolor_tests["add_red_component_clamp_min"] = function()
	local r = require("mobius.rules.hexcolor")()
	local meta = { text = "#000000", component = "r", r = 0, g = 0, b = 0, original_case = "lower" }
	expect.equality(r.add(-1, meta), "#000000")
end

hexcolor_tests["add_green_component_clamp_min"] = function()
	local r = require("mobius.rules.hexcolor")()
	local meta = { text = "#000000", component = "g", r = 0, g = 0, b = 0, original_case = "lower" }
	expect.equality(r.add(-1, meta), "#000000")
end

hexcolor_tests["add_blue_component_clamp_min"] = function()
	local r = require("mobius.rules.hexcolor")()
	local meta = { text = "#000000", component = "b", r = 0, g = 0, b = 0, original_case = "lower" }
	expect.equality(r.add(-1, meta), "#000000")
end

hexcolor_tests["add_blue_component_decrement"] = function()
	local r = require("mobius.rules.hexcolor")()
	local meta = { text = "#0000FF", component = "b", r = 0, g = 0, b = 255, original_case = "lower" }
	expect.equality(r.add(-1, meta), "#0000fe")
end

hexcolor_tests["hexcolor_case_preserved_upper"] = function()
	local r = require("mobius.rules.hexcolor")()
	local meta = { text = "#ABCDEF", component = "r", r = 171, g = 205, b = 239, original_case = "upper" }
	local result = r.add(1, meta)
	-- Should preserve upper case (6-digit format)
	expect.equality(result, "#ACCDEF")
end

hexcolor_tests["hexcolor_case_preserved_lower"] = function()
	local r = require("mobius.rules.hexcolor")()
	local meta = { text = "#abcdef", component = "r", r = 171, g = 205, b = 239, original_case = "lower" }
	local result = r.add(1, meta)
	-- Should preserve lower case (6-digit format)
	expect.equality(result, "#accdef")
end

hexcolor_tests["hexcolor_rgb_format"] = function()
	-- 3-digit format: #RGB -> output as 6-digit #RRGGBB
	local r = require("mobius.rules.hexcolor")()
	local meta = { text = "#F00", component = "r", r = 255, g = 0, b = 0, original_case = "upper" }
	-- Red at max, clamped; output is 6-digit (case follows original_case)
	expect.equality(r.add(1, meta), "#FF0000")
end

hexcolor_tests["hexcolor_rrggbb_format"] = function()
	local r = require("mobius.rules.hexcolor")()
	local meta = { text = "#FF00FF", component = "g", r = 255, g = 0, b = 255, original_case = "upper" }
	expect.equality(r.add(1, meta), "#FF01FF")
end

hexcolor_tests["hexcolor_mixed_case_input"] = function()
	-- Mixed case like #Ff00aB should be detected
	local buf = create_test_buf({ "color: #Ff00aB" })
	local r = require("mobius.rules.hexcolor")()
	local match = r.find({ row = 0, col = 8 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "#Ff00aB")
		-- original_case should be detected as "upper" if any uppercase
		expect.equality(match.metadata.original_case, "upper")
	end
end

hexcolor_tests["hexcolor_cursor_on_red_component"] = function()
	local buf = create_test_buf({ "#123456" })
	local r = require("mobius.rules.hexcolor")()
	-- Cursor on first digit of red component (col 1, skip #)
	local match = r.find({ row = 0, col = 1 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.component, "r")
	end
end

hexcolor_tests["hexcolor_cursor_on_green_component"] = function()
	local buf = create_test_buf({ "#123456" })
	local r = require("mobius.rules.hexcolor")()
	-- Cursor on first digit of green component (col 3)
	local match = r.find({ row = 0, col = 3 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.component, "g")
	end
end

hexcolor_tests["hexcolor_cursor_on_blue_component"] = function()
	local buf = create_test_buf({ "#123456" })
	local r = require("mobius.rules.hexcolor")()
	-- Cursor on first digit of blue component (col 5)
	local match = r.find({ row = 0, col = 5 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.component, "b")
	end
end

hexcolor_tests["hexcolor_find_3digit"] = function()
	local buf = create_test_buf({ "background: #fff" })
	local r = require("mobius.rules.hexcolor")()
	local match = r.find({ row = 0, col = 13 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "#fff")
	end
end

hexcolor_tests["hexcolor_find_6digit"] = function()
	local buf = create_test_buf({ "background: #ffffff" })
	local r = require("mobius.rules.hexcolor")()
	local match = r.find({ row = 0, col = 13 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "#ffffff")
	end
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

case_tests["case_camel_to_snake_direct"] = function()
	local r = require("mobius.rules.case")({ types = { "camelCase", "snake_case", "PascalCase" } })
	local meta =
		{ text = "myVariableName", case_type = "camelCase", types = { "camelCase", "snake_case", "PascalCase" } }
	expect.equality(r.add(1, meta), "my_variable_name")
end

case_tests["case_snake_to_pascal_direct"] = function()
	local r = require("mobius.rules.case")({ types = { "camelCase", "snake_case", "PascalCase" } })
	local meta =
		{ text = "my_variable_name", case_type = "snake_case", types = { "camelCase", "snake_case", "PascalCase" } }
	expect.equality(r.add(1, meta), "MyVariableName")
end

case_tests["case_pascal_to_kebab"] = function()
	local r = require("mobius.rules.case")({ types = { "PascalCase", "kebab-case", "camelCase" } })
	local meta = { text = "MyVariable", case_type = "PascalCase", types = { "PascalCase", "kebab-case", "camelCase" } }
	expect.equality(r.add(1, meta), "my-variable")
end

case_tests["case_kebab_to_screaming"] = function()
	local r = require("mobius.rules.case")({ types = { "kebab-case", "SCREAMING_SNAKE_CASE", "camelCase" } })
	local meta = {
		text = "my-variable",
		case_type = "kebab-case",
		types = { "kebab-case", "SCREAMING_SNAKE_CASE", "camelCase" },
	}
	expect.equality(r.add(1, meta), "MY_VARIABLE")
end

case_tests["case_screaming_to_camel"] = function()
	local r = require("mobius.rules.case")({ types = { "SCREAMING_SNAKE_CASE", "camelCase", "snake_case" } })
	local meta = {
		text = "MY_VARIABLE",
		case_type = "SCREAMING_SNAKE_CASE",
		types = { "SCREAMING_SNAKE_CASE", "camelCase", "snake_case" },
	}
	expect.equality(r.add(1, meta), "myVariable")
end

case_tests["case_full_cycle"] = function()
	local r = require("mobius.rules.case")({
		types = { "camelCase", "snake_case", "PascalCase", "kebab-case", "SCREAMING_SNAKE_CASE" },
	})
	-- Test full cycle: camelCase -> snake_case -> PascalCase -> kebab-case -> SCREAMING_SNAKE_CASE -> camelCase
	local meta1 = {
		text = "myVar",
		case_type = "camelCase",
		types = { "camelCase", "snake_case", "PascalCase", "kebab-case", "SCREAMING_SNAKE_CASE" },
	}
	expect.equality(r.add(1, meta1), "my_var")

	local meta2 = {
		text = "my_var",
		case_type = "snake_case",
		types = { "camelCase", "snake_case", "PascalCase", "kebab-case", "SCREAMING_SNAKE_CASE" },
	}
	expect.equality(r.add(1, meta2), "MyVar")

	local meta3 = {
		text = "MyVar",
		case_type = "PascalCase",
		types = { "camelCase", "snake_case", "PascalCase", "kebab-case", "SCREAMING_SNAKE_CASE" },
	}
	expect.equality(r.add(1, meta3), "my-var")

	local meta4 = {
		text = "my-var",
		case_type = "kebab-case",
		types = { "camelCase", "snake_case", "PascalCase", "kebab-case", "SCREAMING_SNAKE_CASE" },
	}
	expect.equality(r.add(1, meta4), "MY_VAR")

	local meta5 = {
		text = "MY_VAR",
		case_type = "SCREAMING_SNAKE_CASE",
		types = { "camelCase", "snake_case", "PascalCase", "kebab-case", "SCREAMING_SNAKE_CASE" },
	}
	expect.equality(r.add(1, meta5), "myVar")
end

case_tests["case_multiple_words"] = function()
	local r = require("mobius.rules.case")({ types = { "camelCase", "snake_case", "PascalCase" } })
	local meta =
		{ text = "httpResponseCode", case_type = "camelCase", types = { "camelCase", "snake_case", "PascalCase" } }
	expect.equality(r.add(1, meta), "http_response_code")
end

case_tests["case_with_numbers"] = function()
	local r = require("mobius.rules.case")({ types = { "camelCase", "snake_case", "PascalCase" } })
	local meta = { text = "value2Name", case_type = "camelCase", types = { "camelCase", "snake_case", "PascalCase" } }
	expect.equality(r.add(1, meta), "value2_name")
end

case_tests["case_with_acronyms"] = function()
	local r = require("mobius.rules.case")({ types = { "camelCase", "snake_case", "PascalCase" } })
	local meta = { text = "parseXMLData", case_type = "camelCase", types = { "camelCase", "snake_case", "PascalCase" } }
	-- Acronyms in camelCase are split per character (XML -> x_m_l)
	local result = r.add(1, meta)
	expect.equality(result, "parse_x_m_l_data")
end

case_tests["case_decrement"] = function()
	local r = require("mobius.rules.case")({ types = { "camelCase", "snake_case", "PascalCase" } })
	local meta = { text = "myVariable", case_type = "camelCase", types = { "camelCase", "snake_case", "PascalCase" } }
	-- Decrement: camelCase -> PascalCase (wrap backward)
	expect.equality(r.add(-1, meta), "MyVariable")
end

case_tests["case_find_camel"] = function()
	local buf = create_test_buf({ "let myVar = 5" })
	local r = require("mobius.rules.case")({ types = { "camelCase", "snake_case", "PascalCase" } })
	local match = r.find({ row = 0, col = 5 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "myVar")
		expect.equality(match.metadata.case_type, "camelCase")
	end
end

case_tests["case_find_snake"] = function()
	local buf = create_test_buf({ "let my_var = 5" })
	local r = require("mobius.rules.case")({ types = { "camelCase", "snake_case", "PascalCase" } })
	local match = r.find({ row = 0, col = 5 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "my_var")
		expect.equality(match.metadata.case_type, "snake_case")
	end
end

case_tests["case_find_pascal"] = function()
	local buf = create_test_buf({ "let MyVar = 5" })
	local r = require("mobius.rules.case")({ types = { "camelCase", "snake_case", "PascalCase" } })
	local match = r.find({ row = 0, col = 5 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "MyVar")
		expect.equality(match.metadata.case_type, "PascalCase")
	end
end

case_tests["case_no_match_lowercase_single_word"] = function()
	-- Single lowercase word cannot be classified
	local buf = create_test_buf({ "let value = 5" })
	local r = require("mobius.rules.case")({ types = { "camelCase", "snake_case", "PascalCase" } })
	local match = r.find({ row = 0, col = 5 })
	expect.equality(match, nil)
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

paren_tests["paren_to_bracket"] = function()
	-- (x) -> [x]
	local meta = { text = "(x)", open = "(", close = ")", inner = "x" }
	local result = rules_paren.add(1, meta)
	expect.equality(result, "[x]")
end

paren_tests["bracket_to_brace"] = function()
	-- [x] -> {x}
	local meta = { text = "[x]", open = "[", close = "]", inner = "x" }
	local result = rules_paren.add(1, meta)
	expect.equality(result, "{x}")
end

paren_tests["brace_to_paren"] = function()
	-- {x} -> (x)
	local meta = { text = "{x}", open = "{", close = "}", inner = "x" }
	local result = rules_paren.add(1, meta)
	expect.equality(result, "(x)")
end

paren_tests["paren_content_preserved"] = function()
	-- Content should be preserved when cycling
	local meta = { text = "(myVariable)", open = "(", close = ")", inner = "myVariable" }
	local result = rules_paren.add(1, meta)
	expect.equality(result, "[myVariable]")
end

paren_tests["paren_cycle_complete"] = function()
	-- Full cycle: () -> [] -> {} -> ()
	local meta1 = { text = "(x)", open = "(", close = ")", inner = "x" }
	expect.equality(rules_paren.add(1, meta1), "[x]")

	local meta2 = { text = "[x]", open = "[", close = "]", inner = "x" }
	expect.equality(rules_paren.add(1, meta2), "{x}")

	local meta3 = { text = "{x}", open = "{", close = "}", inner = "x" }
	expect.equality(rules_paren.add(1, meta3), "(x)")
end

paren_tests["paren_decrement_cycle"] = function()
	-- Reverse cycle: () -> {} -> [] -> ()
	local meta1 = { text = "(x)", open = "(", close = ")", inner = "x" }
	local result1 = rules_paren.add(-1, meta1)
	expect.equality(result1, "{x}")

	local meta2 = { text = "{x}", open = "{", close = "}", inner = "x" }
	local result2 = rules_paren.add(-1, meta2)
	expect.equality(result2, "[x]")

	local meta3 = { text = "[x]", open = "[", close = "]", inner = "x" }
	local result3 = rules_paren.add(-1, meta3)
	expect.equality(result3, "(x)")
end

paren_tests["paren_nested_simple"] = function()
	-- Simple nesting: func((x))
	local buf = create_test_buf({ "func((x))" })
	-- Cursor on outer open paren (col 4 = first '(')
	local match_outer = rules_paren.find({ row = 0, col = 4 })
	expect.equality(match_outer ~= nil, true)
	if match_outer then
		expect.equality(match_outer.metadata.inner, "(x)")
	end
end

paren_tests["paren_cursor_on_open"] = function()
	local buf = create_test_buf({ "(bala)" })
	local match = rules_paren.find({ row = 0, col = 0 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.open, "(")
	end
end

paren_tests["paren_cursor_on_close"] = function()
	local buf = create_test_buf({ "(bala)" })
	local match = rules_paren.find({ row = 0, col = 5 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.close, ")")
	end
end

paren_tests["paren_cursor_inside_no_match"] = function()
	local buf = create_test_buf({ "(balabalabala)" })
	-- col 5 = first 'a' inside the parens (0-indexed: 0=(, 1=b, 2=a, 3=l, 4=a, 5=b, ...)
	local match = rules_paren.find({ row = 0, col = 5 })
	expect.equality(match, nil)
end

paren_tests["paren_empty_content"] = function()
	-- Empty brackets: () -> []
	local meta = { text = "()", open = "(", close = ")", inner = "" }
	local result = rules_paren.add(1, meta)
	expect.equality(result, "[]")
end

paren_tests["paren_bracket_find"] = function()
	local buf = create_test_buf({ "arr[i]" })
	-- Cursor on open bracket so find returns the pair
	local match = rules_paren.find({ row = 0, col = 3 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "[i]")
	end
end

paren_tests["paren_brace_find"] = function()
	local buf = create_test_buf({ "obj{x}" })
	-- Cursor on open brace so find returns the pair
	local match = rules_paren.find({ row = 0, col = 3 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "{x}")
	end
end

paren_tests["paren_multiple_on_line"] = function()
	local buf = create_test_buf({ "func(x) + arr[y]" })
	-- Cursor on first paren
	local match1 = rules_paren.find({ row = 0, col = 4 })
	expect.equality(match1 ~= nil, true)
	if match1 then
		expect.equality(match1.metadata.text, "(x)")
	end
	-- Cursor on bracket
	local match2 = rules_paren.find({ row = 0, col = 13 })
	expect.equality(match2 ~= nil, true)
	if match2 then
		expect.equality(match2.metadata.text, "[y]")
	end
end

T["paren"] = paren_tests

return T
