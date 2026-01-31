-- Unit tests for constant rules: bool, yes_no, on_off, constant factory
-- Tests focus on find() and add() functions in isolation

local MiniTest = require("mini.test")
local expect = MiniTest.expect

local rules_bool = require("mobius.rules.constant.bool")
local rules_yes_no = require("mobius.rules.constant.yes_no")
local rules_on_off = require("mobius.rules.constant.on_off")
local rules_constant = require("mobius.rules.constant")
local rules_http_method = require("mobius.rules.constant.http_method")
local rules_and_or = require("mobius.rules.constant.and_or")

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

local T = MiniTest.new_set({
	hooks = {
		pre_case = function() end,
		post_case = function() end,
	},
})

-- ============================================================================
-- Boolean Rule
-- ============================================================================
local bool_tests = MiniTest.new_set()

bool_tests["toggle"] = function()
	expect.equality(rules_bool.add(1, { text = "true" }), "false")
	expect.equality(rules_bool.add(1, { text = "false" }), "true")
end

bool_tests["toggle_preserve_case_true"] = function()
	expect.equality(rules_bool.add(1, { text = "True" }), "False")
	expect.equality(rules_bool.add(1, { text = "TRUE" }), "FALSE")
end

bool_tests["toggle_preserve_case_false"] = function()
	expect.equality(rules_bool.add(1, { text = "False" }), "True")
	expect.equality(rules_bool.add(1, { text = "FALSE" }), "TRUE")
end

bool_tests["find_lowercase"] = function()
	local buf = create_test_buf({ "x true y" })
	local match = rules_bool.find({ row = 0, col = 2 })
	expect.equality(match ~= nil, true)
	expect.equality(match.metadata.text, "true")
end

bool_tests["find_mixed_case"] = function()
	local buf = create_test_buf({ "x True y FALSE z" })
	expect.equality(rules_bool.find({ row = 0, col = 2 }).metadata.text, "True")
	expect.equality(rules_bool.find({ row = 0, col = 10 }).metadata.text, "FALSE")
end

bool_tests["find_word_boundary"] = function()
	local buf = create_test_buf({ "let x = trueValue" })
	expect.equality(rules_bool.find({ row = 0, col = 9 }), nil)
end

T["bool"] = bool_tests

-- ============================================================================
-- Yes/No Rule
-- ============================================================================
local yes_no_tests = MiniTest.new_set()

yes_no_tests["toggle"] = function()
	expect.equality(rules_yes_no.add(1, { text = "yes" }), "no")
	expect.equality(rules_yes_no.add(1, { text = "no" }), "yes")
end

yes_no_tests["toggle_preserve_case"] = function()
	expect.equality(rules_yes_no.add(1, { text = "Yes" }), "No")
	expect.equality(rules_yes_no.add(1, { text = "YES" }), "NO")
end

yes_no_tests["find_case_variants"] = function()
	local buf = create_test_buf({ "x Yes y NO z" })
	expect.equality(rules_yes_no.find({ row = 0, col = 2 }).metadata.text, "Yes")
	expect.equality(rules_yes_no.find({ row = 0, col = 8 }).metadata.text, "NO")
end

T["yes_no"] = yes_no_tests

-- ============================================================================
-- On/Off Rule
-- ============================================================================
local on_off_tests = MiniTest.new_set()

on_off_tests["toggle"] = function()
	expect.equality(rules_on_off.add(1, { text = "on" }), "off")
	expect.equality(rules_on_off.add(1, { text = "off" }), "on")
end

T["on_off"] = on_off_tests

-- ============================================================================
-- Constant Factory (Enum)
-- ============================================================================
local constant_tests = MiniTest.new_set()

constant_tests["cycle_basic"] = function()
	local rule = rules_constant({ elements = { "let", "const", "var" }, word = true })
	expect.equality(rule.add(1, { text = "let" }), "const")
	expect.equality(rule.add(1, { text = "const" }), "var")
	expect.equality(rule.add(1, { text = "var" }), "let")
end

constant_tests["cycle_grouped"] = function()
	local rule = rules_constant({
		elements = {
			{ "yes", "no" },
			{ "Yes", "No" },
			{ "YES", "NO" },
		},
	})
	-- In grouped mode, cycling stays within the same group
	expect.equality(rule.add(1, { text = "yes" }), "no")
	expect.equality(rule.add(1, { text = "no" }), "yes") -- cycle within group 1
	expect.equality(rule.add(1, { text = "Yes" }), "No") -- cycle within group 2
	expect.equality(rule.add(1, { text = "NO" }), "YES") -- cycle within group 3
end

constant_tests["decrement"] = function()
	local rule = rules_constant({ elements = { "let", "const", "var" }, word = true })
	expect.equality(rule.add(-1, { text = "let" }), "var")
	expect.equality(rule.add(-1, { text = "const" }), "let")
end

T["constant"] = constant_tests

-- ============================================================================
-- HTTP Methods Tests
-- ============================================================================
local http_tests = MiniTest.new_set()

http_tests["http_full_cycle_forward"] = function()
	-- GET -> POST -> PUT -> PATCH -> DELETE -> HEAD -> OPTIONS -> GET
	expect.equality(rules_http_method.add(1, { text = "GET" }), "POST")
	expect.equality(rules_http_method.add(1, { text = "POST" }), "PUT")
	expect.equality(rules_http_method.add(1, { text = "PUT" }), "PATCH")
	expect.equality(rules_http_method.add(1, { text = "PATCH" }), "DELETE")
	expect.equality(rules_http_method.add(1, { text = "DELETE" }), "HEAD")
	expect.equality(rules_http_method.add(1, { text = "HEAD" }), "OPTIONS")
	expect.equality(rules_http_method.add(1, { text = "OPTIONS" }), "GET")
end

http_tests["http_full_cycle_backward"] = function()
	-- GET -> OPTIONS -> HEAD -> DELETE -> PATCH -> PUT -> POST -> GET
	expect.equality(rules_http_method.add(-1, { text = "GET" }), "OPTIONS")
	expect.equality(rules_http_method.add(-1, { text = "OPTIONS" }), "HEAD")
	expect.equality(rules_http_method.add(-1, { text = "HEAD" }), "DELETE")
	expect.equality(rules_http_method.add(-1, { text = "DELETE" }), "PATCH")
	expect.equality(rules_http_method.add(-1, { text = "PATCH" }), "PUT")
	expect.equality(rules_http_method.add(-1, { text = "PUT" }), "POST")
	expect.equality(rules_http_method.add(-1, { text = "POST" }), "GET")
end

http_tests["http_large_increment"] = function()
	-- GET + 7 wraps (cycle length 7: GET,POST,PUT,PATCH,DELETE,HEAD,OPTIONS)
	expect.equality(rules_http_method.add(7, { text = "GET" }), "GET")
end

http_tests["http_large_decrement"] = function()
	-- POST - 5 (order: GET,POST,PUT,PATCH,DELETE,HEAD,OPTIONS)
	expect.equality(rules_http_method.add(-5, { text = "POST" }), "PATCH")
end

http_tests["http_find_basic"] = function()
	local buf = create_test_buf({ "GET /api/users" })
	local match = rules_http_method.find({ row = 0, col = 2 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "GET")
	end
end

http_tests["http_find_post"] = function()
	local buf = create_test_buf({ "POST /api/data" })
	local match = rules_http_method.find({ row = 0, col = 3 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "POST")
	end
end

http_tests["http_no_match_lowercase"] = function()
	-- HTTP methods are uppercase, lowercase should not match
	local buf = create_test_buf({ "get /api/users" })
	local match = rules_http_method.find({ row = 0, col = 1 })
	expect.equality(match, nil)
end

T["http_method"] = http_tests

-- ============================================================================
-- And/Or Operators Tests
-- ============================================================================
local and_or_tests = MiniTest.new_set()

and_or_tests["and_or_toggle_symbol"] = function()
	-- && <-> ||
	expect.equality(rules_and_or.add(1, { text = "&&" }), "||")
	expect.equality(rules_and_or.add(1, { text = "||" }), "&&")
end

and_or_tests["and_or_text_toggle"] = function()
	-- and <-> or
	expect.equality(rules_and_or.add(1, { text = "and" }), "or")
	expect.equality(rules_and_or.add(1, { text = "or" }), "and")
end

and_or_tests["and_or_uppercase_toggle"] = function()
	-- AND <-> OR
	expect.equality(rules_and_or.add(1, { text = "AND" }), "OR")
	expect.equality(rules_and_or.add(1, { text = "OR" }), "AND")
end

and_or_tests["and_or_mixed_case_not_supported"] = function()
	-- Mixed case like "And" should not match (only exact groups)
	-- The rule defines: {{"&&", "||"}, {"and", "or"}, {"AND", "OR"}}
	local buf = create_test_buf({ "if And Or" })
	-- "And" is not in any defined group
	local match = rules_and_or.find({ row = 0, col = 3 })
	expect.equality(match, nil)
end

and_or_tests["and_or_spacing_preserved"] = function()
	-- && with spacing should match the operator
	local buf = create_test_buf({ "a && b" })
	local match = rules_and_or.find({ row = 0, col = 3 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "&&")
	end
end

and_or_tests["and_or_find_symbol"] = function()
	local buf = create_test_buf({ "if (a && b)" })
	local match = rules_and_or.find({ row = 0, col = 7 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "&&")
	end
end

and_or_tests["and_or_find_text"] = function()
	local buf = create_test_buf({ "if a and b" })
	local match = rules_and_or.find({ row = 0, col = 4 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "and")
	end
end

and_or_tests["and_or_find_uppercase"] = function()
	local buf = create_test_buf({ "if A AND B" })
	local match = rules_and_or.find({ row = 0, col = 4 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "AND")
	end
end

and_or_tests["and_or_word_boundary"] = function()
	-- "and" inside "android" should not match
	local buf = create_test_buf({ "android phone" })
	local match = rules_and_or.find({ row = 0, col = 2 })
	expect.equality(match, nil)
end

and_or_tests["and_or_decrement"] = function()
	-- Decrement should cycle backwards
	expect.equality(rules_and_or.add(-1, { text = "||" }), "&&")
	expect.equality(rules_and_or.add(-1, { text = "or" }), "and")
	expect.equality(rules_and_or.add(-1, { text = "OR" }), "AND")
end

T["and_or"] = and_or_tests

-- ============================================================================
-- Constant Rules: Cursor and Edge Cases
-- ============================================================================
local constant_cursor_tests = MiniTest.new_set()

constant_cursor_tests["bool_cursor_on_true"] = function()
	local buf = create_test_buf({ "let is_valid = true" })
	local match = rules_bool.find({ row = 0, col = 16 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "true")
		-- Cursor position is tracked but bool rule doesn't modify based on it
	end
end

constant_cursor_tests["yes_no_cursor_on_yes"] = function()
	local buf = create_test_buf({ "confirmed: yes" })
	local match = rules_yes_no.find({ row = 0, col = 12 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "yes")
	end
end

constant_cursor_tests["on_off_cursor_on_on"] = function()
	local buf = create_test_buf({ "enabled: on" })
	local match = rules_on_off.find({ row = 0, col = 10 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "on")
	end
end

constant_cursor_tests["bool_case_preserved_on_toggle"] = function()
	-- True -> False (case preserved)
	expect.equality(rules_bool.add(1, { text = "True" }), "False")
	-- FALSE -> TRUE (case preserved)
	expect.equality(rules_bool.add(1, { text = "FALSE" }), "TRUE")
end

constant_cursor_tests["yes_no_case_preserved_on_toggle"] = function()
	expect.equality(rules_yes_no.add(1, { text = "Yes" }), "No")
	expect.equality(rules_yes_no.add(1, { text = "NO" }), "YES")
end

constant_cursor_tests["multiple_toggles_cycle_back"] = function()
	-- true -> false -> true -> false
	expect.equality(rules_bool.add(1, { text = "true" }), "false")
	expect.equality(rules_bool.add(1, { text = "false" }), "true")
	expect.equality(rules_bool.add(1, { text = "true" }), "false")
end

constant_cursor_tests["http_method_full_cycle_with_large_addend"] = function()
	-- Addend larger than cycle length should wrap
	local cycle_len = 7 -- GET,POST,PUT,PATCH,DELETE,HEAD,OPTIONS
	expect.equality(rules_http_method.add(14, { text = "GET" }), "GET") -- 2 full cycles
end

T["constant_cursor"] = constant_cursor_tests

return T
