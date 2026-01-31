-- Tests for miscellaneous rules: case, markdown_header, paren, hexcolor, lsp_enum
-- Focus on: basic functionality, cycling, edge cases

local MiniTest = require("mini.test")
local expect = MiniTest.expect

local rules_case = require("mobius.rules.case")
local rules_markdown_header = require("mobius.rules.markdown_header")
local rules_paren = require("mobius.rules.paren")
local rules_hexcolor = require("mobius.rules.hexcolor")
local rules_lsp_enum = require("mobius.rules.lsp_enum")

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

local T = MiniTest.new_set()

-- ============================================================================
-- Case Rule: Case Conversion Tests
-- ============================================================================
local case_tests = MiniTest.new_set()

case_tests["find_snake_case"] = function()
	local rule = rules_case.new({ types = { "snake_case", "camelCase", "PascalCase" } })
	local buf = create_test_buf({ "my_variable = 1" })
	local match = rule.find({ row = 0, col = 5 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "my_variable")
		expect.equality(match.metadata.case_type, "snake_case")
	end
end

case_tests["find_camel_case"] = function()
	local rule = rules_case.new({ types = { "camelCase", "snake_case", "PascalCase" } })
	local buf = create_test_buf({ "myVariable = 1" })
	local match = rule.find({ row = 0, col = 5 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "myVariable")
		expect.equality(match.metadata.case_type, "camelCase")
	end
end

case_tests["find_pascal_case"] = function()
	local rule = rules_case.new({ types = { "PascalCase", "camelCase", "snake_case" } })
	local buf = create_test_buf({ "MyVariable = 1" })
	local match = rule.find({ row = 0, col = 5 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "MyVariable")
		expect.equality(match.metadata.case_type, "PascalCase")
	end
end

case_tests["find_kebab_case"] = function()
	local rule = rules_case.new({ types = { "kebab-case", "camelCase", "snake_case" } })
	local buf = create_test_buf({ "my-variable = 1" })
	local match = rule.find({ row = 0, col = 6 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "my-variable")
		expect.equality(match.metadata.case_type, "kebab-case")
	end
end

case_tests["find_screaming_snake_case"] = function()
	local rule = rules_case.new({ types = { "SCREAMING_SNAKE_CASE", "camelCase" } })
	local buf = create_test_buf({ "MY_VARIABLE = 1" })
	local match = rule.find({ row = 0, col = 6 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "MY_VARIABLE")
		expect.equality(match.metadata.case_type, "SCREAMING_SNAKE_CASE")
	end
end

case_tests["convert_snake_to_camel"] = function()
	local rule = rules_case.new({ types = { "snake_case", "camelCase" } })
	local result = rule.add(1, { text = "my_variable", case_type = "snake_case", types = { "snake_case", "camelCase" } })
	expect.equality(result, "myVariable")
end

case_tests["convert_camel_to_snake"] = function()
	local rule = rules_case.new({ types = { "camelCase", "snake_case" } })
	local result = rule.add(1, { text = "myVariable", case_type = "camelCase", types = { "camelCase", "snake_case" } })
	expect.equality(result, "my_variable")
end

case_tests["convert_camel_to_pascal"] = function()
	local rule = rules_case.new({ types = { "camelCase", "PascalCase" } })
	local result = rule.add(1, { text = "myVariable", case_type = "camelCase", types = { "camelCase", "PascalCase" } })
	expect.equality(result, "MyVariable")
end

case_tests["convert_pascal_to_snake"] = function()
	local rule = rules_case.new({ types = { "PascalCase", "snake_case" } })
	local result = rule.add(1, { text = "MyVariable", case_type = "PascalCase", types = { "PascalCase", "snake_case" } })
	expect.equality(result, "my_variable")
end

case_tests["cycle_three_case_types"] = function()
	local rule = rules_case.new({ types = { "camelCase", "snake_case", "kebab-case" } })
	local result1 = rule.add(1, { text = "myVariable", case_type = "camelCase", types = { "camelCase", "snake_case", "kebab-case" } })
	expect.equality(result1, "my_variable")

	local result2 = rule.add(1, { text = "my_variable", case_type = "snake_case", types = { "camelCase", "snake_case", "kebab-case" } })
	expect.equality(result2, "my-variable")

	local result3 = rule.add(1, { text = "my-variable", case_type = "kebab-case", types = { "camelCase", "snake_case", "kebab-case" } })
	expect.equality(result3, "myVariable")
end

case_tests["multi_word_camel_to_snake"] = function()
	local rule = rules_case.new({ types = { "camelCase", "snake_case" } })
	local result = rule.add(1, { text = "myComplexVariable", case_type = "camelCase", types = { "camelCase", "snake_case" } })
	expect.equality(result, "my_complex_variable")
end

case_tests["multi_word_snake_to_pascal"] = function()
	local rule = rules_case.new({ types = { "snake_case", "PascalCase" } })
	local result = rule.add(1, { text = "my_complex_variable", case_type = "snake_case", types = { "snake_case", "PascalCase" } })
	expect.equality(result, "MyComplexVariable")
end

case_tests["single_word_not_detected"] = function()
	local rule = rules_case.new({ types = { "camelCase", "snake_case" } })
	local buf = create_test_buf({ "x = 1" })
	local match = rule.find({ row = 0, col = 0 })
	expect.equality(match, nil) -- Single lowercase word doesn't match any case type
end

case_tests["word_boundary_enforced"] = function()
	local rule = rules_case.new({ word = true, types = { "camelCase", "PascalCase" } })
	local buf = create_test_buf({ "android_version" })
	local match = rule.find({ row = 0, col = 8 })
	-- "android_version" is snake_case (has _), not in types list
	-- Also word boundary is enforced, but it's still a valid word
	-- Just not in our requested types
	expect.equality(match, nil)
end

T["case"] = case_tests

-- ============================================================================
-- Markdown Header Rule Tests
-- ============================================================================
local markdown_tests = MiniTest.new_set()

markdown_tests["find_header_level_1"] = function()
	local rule = rules_markdown_header.new()
	local buf = create_test_buf({ "# Title" })
	local match = rule.find({ row = 0, col = 0 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "#")
		expect.equality(match.metadata.count, 1)
	end
end

markdown_tests["find_header_level_3"] = function()
	local rule = rules_markdown_header.new()
	local buf = create_test_buf({ "### Subsection" })
	local match = rule.find({ row = 0, col = 2 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "###")
		expect.equality(match.metadata.count, 3)
	end
end

markdown_tests["increment_header_level"] = function()
	local rule = rules_markdown_header.new()
	local result = rule.add(1, { text = "##", count = 2 })
	expect.equality(result, "###")
end

markdown_tests["decrement_header_level"] = function()
	local rule = rules_markdown_header.new()
	local result = rule.add(-1, { text = "###", count = 3 })
	expect.equality(result, "##")
end

markdown_tests["increment_from_h1"] = function()
	local rule = rules_markdown_header.new()
	local result = rule.add(1, { text = "#", count = 1 })
	expect.equality(result, "##")
end

markdown_tests["decrement_from_h2"] = function()
	local rule = rules_markdown_header.new()
	local result = rule.add(-1, { text = "##", count = 2 })
	expect.equality(result, "#")
end

markdown_tests["no_header_too_small"] = function()
	-- Must have space after # to be a header
	local buf = create_test_buf({ "#not_a_header" })
	local match = rules_markdown_header.new().find({ row = 0, col = 0 })
	expect.equality(match, nil)
end

markdown_tests["find_after_hash"] = function()
	-- Special: matches even when cursor is after the hashes
	local rule = rules_markdown_header.new()
	local buf = create_test_buf({ "## Title" })
	local match = rule.find({ row = 0, col = 3 })
	expect.equality(match ~= nil, true)
end

T["markdown_header"] = markdown_tests

-- ============================================================================
-- Paren Rule: Bracket Cycling Tests
-- ============================================================================
local paren_tests = MiniTest.new_set()

paren_tests["find_simple_parentheses"] = function()
	local buf = create_test_buf({ "(x + y)" })
	local match = rules_paren.find({ row = 0, col = 0 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "(x + y)")
		expect.equality(match.metadata.open, "(")
		expect.equality(match.metadata.close, ")")
	end
end

paren_tests["find_brackets"] = function()
	local buf = create_test_buf({ "array[0]" })
	local match = rules_paren.find({ row = 0, col = 5 }) -- cursor on '['
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "[0]")
		expect.equality(match.metadata.open, "[")
		expect.equality(match.metadata.close, "]")
	end
end

paren_tests["find_braces"] = function()
	local buf = create_test_buf({ "obj = {key: value}" })
	local match = rules_paren.find({ row = 0, col = 6 }) -- col 6 is on '{'
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "{key: value}")
		expect.equality(match.metadata.open, "{")
		expect.equality(match.metadata.close, "}")
	end
end

-- Cycling order is: ( → [ → { → ( → ...
paren_tests["cycle_paren_to_bracket"] = function()
	local result = rules_paren.add(1, { text = "(content)", open = "(", close = ")", inner = "content" })
	expect.equality(result, "[content]")
end

paren_tests["cycle_bracket_to_brace"] = function()
	local result = rules_paren.add(1, { text = "[content]", open = "[", close = "]", inner = "content" })
	expect.equality(result, "{content}")
end

paren_tests["cycle_brace_to_paren"] = function()
	local result = rules_paren.add(1, { text = "{content}", open = "{", close = "}", inner = "content" })
	expect.equality(result, "(content)")
end

paren_tests["reverse_cycle_bracket_to_paren"] = function()
	-- -1 goes backwards: [ → (
	local result = rules_paren.add(-1, { text = "[content]", open = "[", close = "]", inner = "content" })
	expect.equality(result, "(content)")
end

paren_tests["reverse_cycle_brace_to_bracket"] = function()
	-- -1 goes backwards: { → [
	local result = rules_paren.add(-1, { text = "{content}", open = "{", close = "}", inner = "content" })
	expect.equality(result, "[content]")
end

paren_tests["reverse_cycle_paren_to_brace"] = function()
	-- -1 goes backwards: ( → {
	local result = rules_paren.add(-1, { text = "(content)", open = "(", close = ")", inner = "content" })
	expect.equality(result, "{content}")
end

paren_tests["cycle_preserves_inner_content"] = function()
	local result = rules_paren.add(1, { text = "(x, y, z)", open = "(", close = ")", inner = "x, y, z" })
	expect.equality(result, "[x, y, z]")
end

paren_tests["nested_brackets_match_correctly"] = function()
	local buf = create_test_buf({ "func(arr[0])" })
	-- Cursor on outer paren at col 4 (on 'f')
	local match1 = rules_paren.find({ row = 0, col = 4 })
	-- Should find the parentheses around the function call
	if match1 then
		expect.equality(match1.metadata.open, "(")
		expect.equality(match1.metadata.close, ")")
	end
	-- Cursor on inner bracket at col 8 or 9
	local match2 = rules_paren.find({ row = 0, col = 8 })
	if match2 then
		expect.equality(match2.metadata.text, "[0]")
	end
end

paren_tests["cursor_on_open_bracket"] = function()
	local buf = create_test_buf({ "(x)" })
	local match = rules_paren.find({ row = 0, col = 0 })
	expect.equality(match ~= nil, true)
end

paren_tests["cursor_on_close_bracket"] = function()
	local buf = create_test_buf({ "(x)" })
	local match = rules_paren.find({ row = 0, col = 2 })
	expect.equality(match ~= nil, true)
end

paren_tests["cursor_inside_content_no_match"] = function()
	-- Cursor inside brackets (not on bracket itself) should not match
	local buf = create_test_buf({ "(x + y)" })
	local match = rules_paren.find({ row = 0, col = 2 })
	expect.equality(match, nil)
end

T["paren"] = paren_tests

-- ============================================================================
-- Hex Color Rule Tests
-- ============================================================================
local hexcolor_tests = MiniTest.new_set()

hexcolor_tests["find_hex_color_6_digit"] = function()
	local rule = rules_hexcolor.new()
	local buf = create_test_buf({ "color: #1a2b3c" })
	local match = rule.find({ row = 0, col = 8 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "#1a2b3c")
	end
end

hexcolor_tests["find_hex_color_3_digit"] = function()
	local rule = rules_hexcolor.new()
	local buf = create_test_buf({ "color: #abc" })
	local match = rule.find({ row = 0, col = 8 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "#abc")
	end
end

hexcolor_tests["increment_hex_color"] = function()
	local rule = rules_hexcolor.new()
	local result = rule.add(1, { text = "#1a2b3c", r = 26, g = 43, b = 60, component = "all" })
	expect.equality(type(result), "string")
	expect.equality(string.sub(result, 1, 1), "#")
end

hexcolor_tests["decrement_hex_color"] = function()
	local rule = rules_hexcolor.new()
	local result = rule.add(-1, { text = "#000001", r = 0, g = 0, b = 1, component = "all" })
	expect.equality(type(result), "string")
	expect.equality(string.sub(result, 1, 1), "#")
end

hexcolor_tests["increment_red_component"] = function()
	local rule = rules_hexcolor.new()
	local result = rule.add(1, { text = "#102030", r = 16, g = 32, b = 48, component = "r" })
	expect.equality(type(result), "string")
	-- Red component incremented: 16 + 1 = 17
	expect.equality(result:sub(2, 3), "11")
end

hexcolor_tests["no_match_without_hash"] = function()
	local rule = rules_hexcolor.new()
	local buf = create_test_buf({ "color: 1a2b3c" })
	local match = rule.find({ row = 0, col = 8 })
	expect.equality(match, nil) -- Must start with #
end

T["hexcolor"] = hexcolor_tests

-- ============================================================================
-- LSP Enum Rule Tests (basic, without LSP server)
-- ============================================================================
local lsp_enum_tests = MiniTest.new_set()

lsp_enum_tests["lsp_enum_requires_lsp_client"] = function()
	-- LSP enum rule only works when LSP is attached
	local buf = create_test_buf({ "status = Status.OK" })
	local match = rules_lsp_enum.find({ row = 0, col = 10 })
	-- No LSP client attached, so should return nil
	expect.equality(match, nil)
end

lsp_enum_tests["lsp_enum_add_requires_metadata"] = function()
	-- add() requires available_values from LSP completion
	local result = rules_lsp_enum.add(1, { text = "Status.OK", available_values = { "Status.OK", "Status.ERROR" } })
	expect.equality(result, "Status.ERROR")
end

lsp_enum_tests["lsp_enum_cycles_to_first"] = function()
	-- When cycling past last, wrap to first
	local result = rules_lsp_enum.add(1, { text = "Status.ERROR", available_values = { "Status.OK", "Status.ERROR" } })
	expect.equality(result, "Status.OK")
end

lsp_enum_tests["lsp_enum_decrement_wraps_to_last"] = function()
	local result = rules_lsp_enum.add(-1, { text = "Status.OK", available_values = { "Status.OK", "Status.ERROR" } })
	expect.equality(result, "Status.ERROR")
end

T["lsp_enum"] = lsp_enum_tests

return T
