-- Detailed tests for decimal_fraction rule edge cases
-- Focus on: decimal places calculation, sign handling, cursor positioning

local MiniTest = require("mini.test")
local expect = MiniTest.expect

local rules_decimal_fraction = require("mobius.rules.numeric.decimal_fraction")

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
-- Decimal Places Calculation
-- ============================================================================
local decimal_places_tests = MiniTest.new_set()

decimal_places_tests["add_simple_one_decimal_place"] = function()
	local result = rules_decimal_fraction.add(1, { text = "1.5", value = 1.5 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "2.5")
end

decimal_places_tests["add_two_decimal_places"] = function()
	local result = rules_decimal_fraction.add(1, { text = "1.25", value = 1.25 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "2.25")
end

decimal_places_tests["add_three_decimal_places"] = function()
	local result = rules_decimal_fraction.add(1, { text = "3.125", value = 3.125 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "4.125")
end

decimal_places_tests["add_many_decimal_places"] = function()
	local result = rules_decimal_fraction.add(1, { text = "1.123456", value = 1.123456 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "2.123456")
end

-- Negative numbers with decimal places
decimal_places_tests["add_negative_with_one_decimal"] = function()
	local result = rules_decimal_fraction.add(1, { text = "-1.5", value = -1.5 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "-0.5")
end

decimal_places_tests["add_negative_with_two_decimals"] = function()
	local result = rules_decimal_fraction.add(2, { text = "-1.25", value = -1.25 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "0.75")
end

-- Positive sign with decimal places
decimal_places_tests["add_positive_sign_one_decimal"] = function()
	local result = rules_decimal_fraction.add(1, { text = "+1.5", value = 1.5 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "+2.5")
end

decimal_places_tests["add_positive_sign_two_decimals"] = function()
	local result = rules_decimal_fraction.add(1, { text = "+0.75", value = 0.75 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "+1.75")
end

-- Leading zeros in fractional part
decimal_places_tests["add_with_leading_zero_fractional"] = function()
	local result = rules_decimal_fraction.add(1, { text = "1.05", value = 1.05 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "2.05")
end

decimal_places_tests["add_with_trailing_zeros"] = function()
	local result = rules_decimal_fraction.add(1, { text = "1.50", value = 1.5 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "2.50")
end

-- Edge case: what if decimal_places calculation is wrong?
-- If sign is not excluded from decimal places count:
-- "-1.5" has 2 chars after '.', not 1
decimal_places_tests["negative_sign_not_counted"] = function()
	-- The issue: if we count "-1.5"[2:] = "5", that's correct (1 place)
	-- But if "-1.5".find(".") returns position of '.', then .sub(pos+1) is correct
	-- The bug would happen if we naively count all after '.', including '-'
	-- which shouldn't happen since '-' comes before '.'
	local result = rules_decimal_fraction.add(1, { text = "-1.5", value = -1.5 })
	local text = type(result) == "table" and result.text or result
	-- Should be "-0.5" (1 decimal place), not "-0.5000000000" (wrong precision)
	expect.equality(text, "-0.5")
end

T["decimal_places"] = decimal_places_tests

-- ============================================================================
-- Cursor Position
-- ============================================================================
local cursor_tests = MiniTest.new_set()

cursor_tests["cursor_position_returned"] = function()
	local result = rules_decimal_fraction.add(1, { text = "1.5", value = 1.5 })
	-- add() should return a table with text and cursor
	expect.equality(type(result), "table")
	expect.equality(result.text, "2.5")
	-- cursor should be a number
	expect.equality(type(result.cursor), "number")
end

cursor_tests["cursor_position_matches_text_length"] = function()
	local result = rules_decimal_fraction.add(1, { text = "1.5", value = 1.5 })
	-- cursor = #new_text - 1
	-- For "2.5" (3 chars), cursor should be 2 (0-indexed last position)
	expect.equality(result.cursor, 2)
end

cursor_tests["cursor_position_for_longer_decimal"] = function()
	local result = rules_decimal_fraction.add(1, { text = "1.25", value = 1.25 })
	-- For "2.25" (4 chars), cursor should be 3
	expect.equality(result.cursor, 3)
end

cursor_tests["cursor_position_with_negative"] = function()
	local result = rules_decimal_fraction.add(1, { text = "-1.5", value = -1.5 })
	-- For "-0.5" (4 chars), cursor should be 3
	expect.equality(result.cursor, 3)
end

T["cursor"] = cursor_tests

-- ============================================================================
-- Find and Integration
-- ============================================================================
local integration_tests = MiniTest.new_set()

integration_tests["find_decimal_at_cursor"] = function()
	local buf = create_test_buf({ "value = 3.14" })
	local match = rules_decimal_fraction.find({ row = 0, col = 9 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "3.14")
		expect.equality(match.metadata.value, 3.14)
	end
end

integration_tests["find_decimal_with_negative"] = function()
	local buf = create_test_buf({ "amount = -5.99" })
	local match = rules_decimal_fraction.find({ row = 0, col = 10 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "-5.99")
	end
end

integration_tests["find_decimal_with_positive_sign"] = function()
	local buf = create_test_buf({ "delta = +2.5" })
	local match = rules_decimal_fraction.find({ row = 0, col = 8 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "+2.5")
	end
end

integration_tests["find_decimal_multiple_on_line"] = function()
	local buf = create_test_buf({ "x = 1.5, y = 2.5" })
	-- Cursor at first decimal
	local match1 = rules_decimal_fraction.find({ row = 0, col = 4 })
	expect.equality(match1 ~= nil, true)
	if match1 then
		expect.equality(match1.metadata.text, "1.5")
	end
	-- Cursor at second decimal
	local match2 = rules_decimal_fraction.find({ row = 0, col = 13 })
	expect.equality(match2 ~= nil, true)
	if match2 then
		expect.equality(match2.metadata.text, "2.5")
	end
end

T["integration"] = integration_tests

-- ============================================================================
-- Edge Cases: Precision and Rounding
-- ============================================================================
local precision_tests = MiniTest.new_set()

precision_tests["zero_increment_preserves_decimal_places"] = function()
	local result = rules_decimal_fraction.add(0, { text = "1.50", value = 1.5 })
	local text = type(result) == "table" and result.text or result
	-- 1.5 + 0 = 1.5, but preserve 2 decimal places from "1.50"
	expect.equality(text, "1.50")
end

precision_tests["small_decimal_increment"] = function()
	local result = rules_decimal_fraction.add(1, { text = "0.01", value = 0.01 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "1.01")
end

precision_tests["small_decimal_decrement"] = function()
	local result = rules_decimal_fraction.add(-1, { text = "0.01", value = 0.01 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "-0.99")
end

precision_tests["cross_integer_boundary"] = function()
	local result = rules_decimal_fraction.add(1, { text = "9.99", value = 9.99 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "10.99")
end

precision_tests["negative_to_positive_transition"] = function()
	local result = rules_decimal_fraction.add(2, { text = "-0.50", value = -0.5 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "1.50")
end

precision_tests["very_large_number"] = function()
	local result = rules_decimal_fraction.add(1, { text = "999999.5", value = 999999.5 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "1000000.5")
end

T["precision"] = precision_tests

-- ============================================================================
-- Floating Point Edge Cases
-- ============================================================================
local float_edge_tests = MiniTest.new_set()

float_edge_tests["binary_fraction_precision"] = function()
	-- 0.1 in binary is repeating, so 0.1 + 0.1 + 0.1 != 0.3
	-- But we format to 1 decimal place, so it should work
	local result = rules_decimal_fraction.add(1, { text = "0.1", value = 0.1 })
	local text = type(result) == "table" and result.text or result
	-- 0.1 + 1 = 1.1
	expect.equality(text, "1.1")
end

float_edge_tests["many_decimal_places_preserved"] = function()
	local result = rules_decimal_fraction.add(0, { text = "1.333333", value = 1.333333 })
	local text = type(result) == "table" and result.text or result
	-- Should preserve all 6 decimal places
	expect.equality(text, "1.333333")
end

float_edge_tests["positive_sign_preserved_on_increment"] = function()
	local result = rules_decimal_fraction.add(1, { text = "+1.5", value = 1.5 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "+2.5")
end

float_edge_tests["positive_sign_lost_on_decrement_to_negative"] = function()
	local result = rules_decimal_fraction.add(-2, { text = "+0.5", value = 0.5 })
	local text = type(result) == "table" and result.text or result
	-- Should be "-1.5" (no + sign on negative)
	expect.equality(text, "-1.5")
end

float_edge_tests["positive_sign_not_added_if_not_present"] = function()
	local result = rules_decimal_fraction.add(1, { text = "1.5", value = 1.5 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "2.5")
end

T["float_edge"] = float_edge_tests

return T
