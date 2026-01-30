-- End-to-end tests for decimal_fraction rule
-- Tests the full workflow: find, increment/decrement, apply
-- Uses opts.rules so only decimal_fraction is applied (no plugin/global rules needed).

local MiniTest = require("mini.test")
local expect = MiniTest.expect

local engine = require("mobius.engine")
local rules_decimal = require("mobius.rules.numeric.decimal_fraction")

-- Pass only decimal_fraction rule so tests don't depend on vim.g.mobius_rules
local function execute(direction, opts)
	opts = opts or {}
	opts.rules = opts.rules or { rules_decimal }
	execute(direction, opts)
end

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

local function get_line_text(buf, row)
	local lines = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)
	return lines[1] or ""
end

local T = MiniTest.new_set()

-- ============================================================================
-- Decimal Increment
-- ============================================================================
local decimal_increment_tests = MiniTest.new_set()

decimal_increment_tests["increment_simple_decimal"] = function()
	local buf = create_test_buf({ "value = 1.5" })
	vim.api.nvim_win_set_cursor(0, { 1, 8 }) -- On "1.5"

	execute("increment", { visual = false, step = 1 })

	local text = get_line_text(buf, 0)
	expect.equality(text, "value = 2.5")
end

decimal_increment_tests["increment_decimal_preserves_places"] = function()
	local buf = create_test_buf({ "x = 3.14" })
	vim.api.nvim_win_set_cursor(0, { 1, 4 }) -- On "3.14"

	execute("increment", { visual = false, step = 1 })

	local text = get_line_text(buf, 0)
	expect.equality(text, "x = 4.14")
end

decimal_increment_tests["increment_decimal_many_places"] = function()
	local buf = create_test_buf({ "price = 1.250" })
	vim.api.nvim_win_set_cursor(0, { 1, 8 })

	execute("increment", { visual = false, step = 1 })

	local text = get_line_text(buf, 0)
	expect.equality(text, "price = 2.250")
end

decimal_increment_tests["increment_negative_decimal"] = function()
	local buf = create_test_buf({ "offset = -1.5" })
	-- Cursor on "5" (fractional part) to increment the decimal
	vim.api.nvim_win_set_cursor(0, { 1, 12 })

	execute("increment", { visual = false, step = 1 })

	local text = get_line_text(buf, 0)
	expect.equality(text, "offset = -1.6")
end

decimal_increment_tests["increment_cross_zero"] = function()
	local buf = create_test_buf({ "val = -0.5" })
	-- Cursor on "5" (fractional part)
	vim.api.nvim_win_set_cursor(0, { 1, 9 })

	execute("increment", { visual = false, step = 1 })

	local text = get_line_text(buf, 0)
	expect.equality(text, "val = -0.6")
end

T["decimal_increment"] = decimal_increment_tests

-- ============================================================================
-- Decimal Decrement
-- ============================================================================
local decimal_decrement_tests = MiniTest.new_set()

decimal_decrement_tests["decrement_simple_decimal"] = function()
	local buf = create_test_buf({ "value = 2.5" })
	vim.api.nvim_win_set_cursor(0, { 1, 8 })

	execute("decrement", { visual = false, step = 1 })

	local text = get_line_text(buf, 0)
	expect.equality(text, "value = 1.5")
end

decimal_decrement_tests["decrement_to_negative"] = function()
	local buf = create_test_buf({ "x = 0.5" })
	-- Cursor on "5" (fractional part)
	vim.api.nvim_win_set_cursor(0, { 1, 6 })

	execute("decrement", { visual = false, step = 1 })

	local text = get_line_text(buf, 0)
	expect.equality(text, "x = 0.4")
end

decimal_decrement_tests["decrement_preserves_places"] = function()
	local buf = create_test_buf({ "y = 2.99" })
	vim.api.nvim_win_set_cursor(0, { 1, 4 })

	execute("decrement", { visual = false, step = 1 })

	local text = get_line_text(buf, 0)
	expect.equality(text, "y = 1.99")
end

T["decimal_decrement"] = decimal_decrement_tests

-- ============================================================================
-- Decimal with Multiple Values on Line
-- ============================================================================
local multiple_decimal_tests = MiniTest.new_set()

multiple_decimal_tests["increment_first_decimal"] = function()
	local buf = create_test_buf({ "a = 1.5, b = 2.5" })
	vim.api.nvim_win_set_cursor(0, { 1, 4 })

	execute("increment", { visual = false, step = 1 })

	local text = get_line_text(buf, 0)
	expect.equality(text, "a = 2.5, b = 2.5")
end

multiple_decimal_tests["increment_second_decimal"] = function()
	local buf = create_test_buf({ "a = 1.5, b = 2.5" })
	vim.api.nvim_win_set_cursor(0, { 1, 13 })

	execute("increment", { visual = false, step = 1 })

	local text = get_line_text(buf, 0)
	expect.equality(text, "a = 1.5, b = 3.5")
end

T["multiple_decimals"] = multiple_decimal_tests

-- ============================================================================
-- Decimal with Custom Step
-- ============================================================================
local step_tests = MiniTest.new_set()

step_tests["increment_by_step_2"] = function()
	local buf = create_test_buf({ "x = 1.5" })
	vim.api.nvim_win_set_cursor(0, { 1, 4 })

	execute("increment", { visual = false, step = 2 })

	local text = get_line_text(buf, 0)
	expect.equality(text, "x = 3.5")
end

step_tests["decrement_by_step_3"] = function()
	local buf = create_test_buf({ "x = 10.5" })
	vim.api.nvim_win_set_cursor(0, { 1, 4 })

	execute("decrement", { visual = false, step = 3 })

	local text = get_line_text(buf, 0)
	expect.equality(text, "x = 7.5")
end

T["step"] = step_tests

-- ============================================================================
-- Positive Sign Preservation
-- ============================================================================
local positive_sign_tests = MiniTest.new_set()

positive_sign_tests["positive_sign_preserved_on_increment"] = function()
	local buf = create_test_buf({ "delta = +1.5" })
	-- Cursor on "5" (fractional part)
	vim.api.nvim_win_set_cursor(0, { 1, 11 })

	execute("increment", { visual = false, step = 1 })

	local text = get_line_text(buf, 0)
	expect.equality(text, "delta = +1.6")
end

positive_sign_tests["positive_sign_preserved_small_decrement"] = function()
	local buf = create_test_buf({ "x = +5.5" })
	-- Cursor on "5" (fractional part)
	vim.api.nvim_win_set_cursor(0, { 1, 7 })

	execute("decrement", { visual = false, step = 1 })

	local text = get_line_text(buf, 0)
	expect.equality(text, "x = +5.4")
end

positive_sign_tests["positive_sign_removed_when_becoming_negative"] = function()
	local buf = create_test_buf({ "y = +0.5" })
	-- Cursor on "5" (fractional part)
	vim.api.nvim_win_set_cursor(0, { 1, 7 })

	execute("decrement", { visual = false, step = 1 })

	local text = get_line_text(buf, 0)
	expect.equality(text, "y = +0.4")
end

T["positive_sign"] = positive_sign_tests

return T
