-- Unit tests for constant rules: bool, yes_no, on_off, constant factory
-- Tests focus on find() and add() functions in isolation

local MiniTest = require("mini.test")
local expect = MiniTest.expect

local rules_bool = require("mobius.rules.constant.bool")
local rules_yes_no = require("mobius.rules.constant.yes_no")
local rules_on_off = require("mobius.rules.constant.on_off")
local rules_constant = require("mobius.rules.constant")

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

return T
