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

-- ============================================================================
-- Cursor Position Component Tests
-- ============================================================================
local cursor_component_tests = MiniTest.new_set()

cursor_component_tests["decimal_cursor_before_dot"] = function()
	-- Cursor before dot should modify integer part
	local result = rules_decimal_fraction.add(1, { text = "1.5", value = 1.5, cursor_offset = 0 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "2.5")
end

cursor_component_tests["decimal_cursor_first_decimal_place"] = function()
	-- Cursor in fraction: add 1 in smallest unit (last digit). "1.23" + 0.01 = "1.24"
	local result = rules_decimal_fraction.add(1, { text = "1.23", value = 1.23, cursor_offset = 2 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "1.24")
end

cursor_component_tests["decimal_cursor_second_decimal_place"] = function()
	-- Same: add in smallest unit. "1.23" + 0.01 = "1.24"
	local result = rules_decimal_fraction.add(1, { text = "1.23", value = 1.23, cursor_offset = 3 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "1.24")
end

cursor_component_tests["decimal_cursor_many_places"] = function()
	-- "1.234" + 0.001 (smallest unit) = "1.235"
	local result = rules_decimal_fraction.add(1, { text = "1.234", value = 1.234, cursor_offset = 4 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "1.235")
end

cursor_component_tests["decimal_cursor_before_dot_decrement"] = function()
	-- Cursor before dot, decrement integer part
	local result = rules_decimal_fraction.add(-1, { text = "5.5", value = 5.5, cursor_offset = 0 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "4.5")
end

cursor_component_tests["decimal_negative_cursor_before_dot"] = function()
	-- Negative number: cursor before dot
	-- "-3.5" with cursor before dot, -1 integer = -4.5
	local result = rules_decimal_fraction.add(-1, { text = "-3.5", value = -3.5, cursor_offset = 1 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "-4.5")
end

cursor_component_tests["decimal_negative_cursor_before_dot_increment"] = function()
	-- Negative number: cursor before dot, increment towards zero
	-- "-3.5" with cursor before dot, +1 integer = -2.5
	local result = rules_decimal_fraction.add(1, { text = "-3.5", value = -3.5, cursor_offset = 1 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "-2.5")
end

cursor_component_tests["decimal_positive_sign_preserved"] = function()
	-- Integer part increment; preserve positive sign
	local result = rules_decimal_fraction.add(1, { text = "+1.5", value = 1.5, cursor_offset = 1 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "+2.5")
end

cursor_component_tests["decimal_cursor_on_dot"] = function()
	-- Cursor on dot should modify integer part (treated as before dot)
	local result = rules_decimal_fraction.add(1, { text = "1.5", value = 1.5, cursor_offset = 1 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "2.5")
end

cursor_component_tests["decimal_cursor_after_add_7_not_on_dot"] = function()
	-- 2.7 + 7 with cursor on integer part: result "9.7", cursor must be on "9" (index 0), not on "." (index 1)
	local result = rules_decimal_fraction.add(7, { text = "2.7", value = 2.7, cursor_offset = 0 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "9.7")
	expect.equality(result.cursor, 0)
end

cursor_component_tests["decimal_cursor_on_7_add_one_19_73"] = function()
	-- 19.72 with cursor on "7": add 1 in smallest unit -> 19.73 (not 19.82)
	local result = rules_decimal_fraction.add(1, { text = "19.72", value = 19.72, cursor_offset = 3 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "19.73")
	expect.equality(result.cursor, 4)
end

cursor_component_tests["decimal_cursor_fraction_decrement"] = function()
	-- Cursor in fraction: add -1 in smallest unit. "2.30" - 0.01 = "2.29"
	local result = rules_decimal_fraction.add(-1, { text = "2.30", value = 2.30, cursor_offset = 2 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "2.29")
end

cursor_component_tests["decimal_cursor_fraction_with_carry"] = function()
	-- Cursor on fraction part causing carry to integer
	-- "2.99" with cursor on hundredths +1 = "3.00"
	local result = rules_decimal_fraction.add(1, { text = "2.99", value = 2.99, cursor_offset = 3 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "3.00")
end

cursor_component_tests["decimal_cursor_fraction_borrow"] = function()
	-- Cursor on fraction part causing borrow from integer
	-- "3.00" with cursor on hundredths -1 = "2.99"
	local result = rules_decimal_fraction.add(-1, { text = "3.00", value = 3.00, cursor_offset = 3 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "2.99")
end

cursor_component_tests["decimal_cursor_returns_table_with_cursor"] = function()
	-- Verify that cursor position tests return table with cursor field
	local result = rules_decimal_fraction.add(1, { text = "1.5", value = 1.5, cursor_offset = 0 })
	expect.equality(type(result), "table")
	expect.equality(type(result.cursor), "number")
end

T["cursor_component"] = cursor_component_tests

-- ============================================================================
-- Fraction Operations: Detailed Cursor Position Tests
-- ============================================================================
local fraction_ops_tests = MiniTest.new_set()

-- One decimal place with cursor on fraction
fraction_ops_tests["one_decimal_increment_cursor_on_fraction"] = function()
	local result = rules_decimal_fraction.add(1, { text = "1.5", value = 1.5, cursor_offset = 2 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "1.6")
	expect.equality(result.cursor, 2) -- cursor on "6" (last decimal digit)
end

fraction_ops_tests["one_decimal_decrement_cursor_on_fraction"] = function()
	local result = rules_decimal_fraction.add(-1, { text = "1.5", value = 1.5, cursor_offset = 2 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "1.4")
	expect.equality(result.cursor, 2) -- cursor on "4"
end

-- Two decimal places with cursor at different positions
fraction_ops_tests["two_decimal_cursor_first_place_increment"] = function()
	-- "1.23" cursor on first decimal (2), +0.01 -> "1.24"
	local result = rules_decimal_fraction.add(1, { text = "1.23", value = 1.23, cursor_offset = 2 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "1.24")
	expect.equality(result.cursor, 3) -- cursor on last digit "4" (index 3)
end

fraction_ops_tests["two_decimal_cursor_second_place_increment"] = function()
	-- "1.23" cursor on second decimal (3), +0.01 -> "1.24"
	local result = rules_decimal_fraction.add(1, { text = "1.23", value = 1.23, cursor_offset = 3 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "1.24")
	expect.equality(result.cursor, 3) -- cursor on last digit "4" (index 3)
end

fraction_ops_tests["two_decimal_cursor_first_place_decrement"] = function()
	-- "2.56" cursor on first decimal, -0.01 -> "2.55"
	local result = rules_decimal_fraction.add(-1, { text = "2.56", value = 2.56, cursor_offset = 2 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "2.55")
	expect.equality(result.cursor, 3) -- cursor on last digit "5" (index 3)
end

fraction_ops_tests["two_decimal_cursor_second_place_decrement"] = function()
	-- "2.56" cursor on second decimal, -0.01 -> "2.55"
	local result = rules_decimal_fraction.add(-1, { text = "2.56", value = 2.56, cursor_offset = 3 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "2.55")
	expect.equality(result.cursor, 3) -- cursor on last digit "5" (index 3)
end

-- Three decimal places
fraction_ops_tests["three_decimal_cursor_third_place_increment"] = function()
	-- "3.141" cursor on third decimal, +0.001 -> "3.142"
	local result = rules_decimal_fraction.add(1, { text = "3.141", value = 3.141, cursor_offset = 5 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "3.142")
	expect.equality(result.cursor, 4) -- cursor on last digit "2" (index 4)
end

fraction_ops_tests["three_decimal_cursor_middle_increment"] = function()
	-- "3.141" cursor on first decimal (1), +0.001 -> "3.142"
	local result = rules_decimal_fraction.add(1, { text = "3.141", value = 3.141, cursor_offset = 2 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "3.142")
	expect.equality(result.cursor, 4) -- cursor on last digit "2" (index 4)
end

fraction_ops_tests["three_decimal_decrement_with_borrow"] = function()
	-- "5.200" cursor on third decimal, -0.001 -> "5.199"
	local result = rules_decimal_fraction.add(-1, { text = "5.200", value = 5.200, cursor_offset = 4 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "5.199")
	expect.equality(result.cursor, 4) -- cursor on last digit "9" (index 4)
end

-- Many decimal places
fraction_ops_tests["six_decimal_increment"] = function()
	-- "1.123456" + 0.000001 -> "1.123457"
	local result = rules_decimal_fraction.add(1, { text = "1.123456", value = 1.123456, cursor_offset = 4 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "1.123457")
	expect.equality(result.cursor, 7) -- cursor on last digit "7" (index 7)
end

fraction_ops_tests["six_decimal_decrement"] = function()
	-- "2.100000" - 0.000001 -> "2.099999"
	local result = rules_decimal_fraction.add(-1, { text = "2.100000", value = 2.100000, cursor_offset = 7 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "2.099999")
	expect.equality(result.cursor, 7) -- cursor on last digit "9" (index 7)
end

T["fraction_operations"] = fraction_ops_tests

-- ============================================================================
-- Carry and Borrow: Cursor Position on Boundary Transitions
-- ============================================================================
local carry_borrow_tests = MiniTest.new_set()

-- Carry from fraction to integer
carry_borrow_tests["carry_to_integer_one_nine_nine"] = function()
	-- "9.99" + 0.01 -> "10.00", cursor should be on last "0"
	local result = rules_decimal_fraction.add(1, { text = "9.99", value = 9.99, cursor_offset = 3 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "10.00")
	expect.equality(result.cursor, 4) -- cursor on last decimal digit "0" (index 4)
end

carry_borrow_tests["carry_to_integer_ninety_nine"] = function()
	-- "99.99" + 0.01 -> "100.00", cursor should be on last "0"
	local result = rules_decimal_fraction.add(1, { text = "99.99", value = 99.99, cursor_offset = 4 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "100.00")
	expect.equality(result.cursor, 5) -- cursor on last decimal digit "0" (index 5)
end

carry_borrow_tests["carry_multiple_integer_digits"] = function()
	-- "199.99" + 0.01 -> "200.00", cursor on last "0"
	local result = rules_decimal_fraction.add(1, { text = "199.99", value = 199.99, cursor_offset = 5 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "200.00")
	expect.equality(result.cursor, 5) -- cursor on last decimal digit "0" (index 5)
end

-- Borrow from integer to fraction
carry_borrow_tests["borrow_from_integer_ten"] = function()
	-- "10.00" - 0.01 -> "9.99", cursor on last "9"
	local result = rules_decimal_fraction.add(-1, { text = "10.00", value = 10.00, cursor_offset = 4 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "9.99")
	expect.equality(result.cursor, 3) -- cursor on last decimal digit "9" (index 3)
end

carry_borrow_tests["borrow_from_integer_hundred"] = function()
	-- "100.00" - 0.01 -> "99.99", cursor on last "9"
	local result = rules_decimal_fraction.add(-1, { text = "100.00", value = 100.00, cursor_offset = 5 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "99.99")
	expect.equality(result.cursor, 4) -- cursor on last decimal digit "9" (index 4)
end

carry_borrow_tests["borrow_multiple_integer_digits"] = function()
	-- "200.00" - 0.01 -> "199.99", cursor on last "9"
	local result = rules_decimal_fraction.add(-1, { text = "200.00", value = 200.00, cursor_offset = 5 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "199.99")
	expect.equality(result.cursor, 5) -- cursor on last decimal digit "9" (index 5)
end

-- Carry/borrow with negative numbers
carry_borrow_tests["carry_negative_to_zero"] = function()
	-- "-9.99" + 0.01 -> "-9.98", moving toward zero
	local result = rules_decimal_fraction.add(1, { text = "-9.99", value = -9.99, cursor_offset = 4 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "-9.98")
	expect.equality(result.cursor, 4) -- cursor on last decimal digit "8" (index 4)
end

carry_borrow_tests["borrow_negative_from_integer"] = function()
	-- "-10.00" - 0.01 -> "-10.01", moving away from zero
	local result = rules_decimal_fraction.add(-1, { text = "-10.00", value = -10.00, cursor_offset = 5 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "-10.01")
	expect.equality(result.cursor, 5) -- cursor on last decimal digit "1" (index 5)
end

T["carry_borrow"] = carry_borrow_tests

-- ============================================================================
-- Cursor Position: Comprehensive Coverage
-- ============================================================================
local cursor_comprehensive_tests = MiniTest.new_set()

-- Cursor on sign position
cursor_comprehensive_tests["cursor_on_positive_sign"] = function()
	-- "+1.5" cursor at offset 0 (on '+'), integer increment
	local result = rules_decimal_fraction.add(1, { text = "+1.5", value = 1.5, cursor_offset = 0 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "+2.5")
	expect.equality(result.cursor, 1) -- cursor on "2" (index 1, "+" at index 0)
end

cursor_comprehensive_tests["cursor_on_negative_sign"] = function()
	-- "-1.5" cursor at offset 0 (on '-'), integer increment
	-- Integer part: -1 + 1 = 0, so result is "0.5"
	local result = rules_decimal_fraction.add(1, { text = "-1.5", value = -1.5, cursor_offset = 0 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "0.5")
	expect.equality(result.cursor, 0) -- cursor on "0" (index 0)
end

-- Cursor on each digit of integer part
cursor_comprehensive_tests["cursor_on_first_integer_digit"] = function()
	-- "12.34" cursor on "1" (offset 0), integer increment
	local result = rules_decimal_fraction.add(1, { text = "12.34", value = 12.34, cursor_offset = 0 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "13.34")
	expect.equality(result.cursor, 1) -- cursor on "3" (index 1)
end

cursor_comprehensive_tests["cursor_on_second_integer_digit"] = function()
	-- "12.34" cursor on "2" (offset 1), integer increment
	local result = rules_decimal_fraction.add(1, { text = "12.34", value = 12.34, cursor_offset = 1 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "13.34")
	expect.equality(result.cursor, 1) -- cursor on "3"
end

cursor_comprehensive_tests["cursor_on_multi_digit_integer"] = function()
	-- "123.45" cursor on middle digit "2" (offset 1), integer increment
	local result = rules_decimal_fraction.add(1, { text = "123.45", value = 123.45, cursor_offset = 1 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "124.45")
	expect.equality(result.cursor, 2) -- cursor on "4" (index 2)
end

-- Cursor on decimal point
cursor_comprehensive_tests["cursor_on_decimal_point"] = function()
	-- "5.67" cursor on "." (offset 1), integer increment
	local result = rules_decimal_fraction.add(1, { text = "5.67", value = 5.67, cursor_offset = 1 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "6.67")
	expect.equality(result.cursor, 0) -- cursor on "6"
end

cursor_comprehensive_tests["cursor_on_decimal_point_negative"] = function()
	-- "-5.67" cursor on "." (offset 2), integer increment
	local result = rules_decimal_fraction.add(1, { text = "-5.67", value = -5.67, cursor_offset = 2 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "-4.67")
	expect.equality(result.cursor, 1) -- cursor on "4"
end

-- Cursor on each decimal digit
cursor_comprehensive_tests["cursor_on_first_decimal_only"] = function()
	-- "8.9" cursor on "9" (offset 2), fraction increment +0.1
	local result = rules_decimal_fraction.add(1, { text = "8.9", value = 8.9, cursor_offset = 2 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "9.0")
	expect.equality(result.cursor, 2) -- cursor on "0"
end

cursor_comprehensive_tests["cursor_on_first_of_two_decimals"] = function()
	-- "7.89" cursor on "8" (offset 2), fraction increment +0.01
	local result = rules_decimal_fraction.add(1, { text = "7.89", value = 7.89, cursor_offset = 2 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "7.90")
	expect.equality(result.cursor, 3) -- cursor on last digit "0" (index 3)
end

cursor_comprehensive_tests["cursor_on_second_of_two_decimals"] = function()
	-- "7.89" cursor on "9" (offset 3), fraction increment +0.01
	local result = rules_decimal_fraction.add(1, { text = "7.89", value = 7.89, cursor_offset = 3 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "7.90")
	expect.equality(result.cursor, 3) -- cursor on last digit "0" (index 3)
end

-- Special result formats
cursor_comprehensive_tests["result_single_digit_integer"] = function()
	-- "9.99" cursor on integer, +1 -> "10.99"
	local result = rules_decimal_fraction.add(1, { text = "9.99", value = 9.99, cursor_offset = 0 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "10.99")
	expect.equality(result.cursor, 1) -- cursor on "0" (index 1)
end

cursor_comprehensive_tests["result_triple_digit_integer"] = function()
	-- "99.99" cursor on integer, +1 -> "100.99"
	local result = rules_decimal_fraction.add(1, { text = "99.99", value = 99.99, cursor_offset = 0 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "100.99")
	expect.equality(result.cursor, 2) -- cursor on last "0" (index 2)
end

cursor_comprehensive_tests["result_negative_to_positive"] = function()
	-- "-0.5" cursor on integer (0), +1 -> "1.5"
	-- Integer part: 0 + 1 = 1, so result is "1.5"
	local result = rules_decimal_fraction.add(1, { text = "-0.5", value = -0.5, cursor_offset = 1 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "1.5")
	expect.equality(result.cursor, 0) -- cursor on "1" (index 0)
end

T["cursor_comprehensive"] = cursor_comprehensive_tests

-- ============================================================================
-- Edge Cases: Boundary Values and Zero
-- ============================================================================
local edge_boundary_tests = MiniTest.new_set()

-- Zero value variations
edge_boundary_tests["zero_two_decimals_increment"] = function()
	local result = rules_decimal_fraction.add(1, { text = "0.00", value = 0.00, cursor_offset = 2 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "0.01")
	expect.equality(result.cursor, 3) -- cursor on "1" (index 3)
end

edge_boundary_tests["zero_two_decimals_decrement"] = function()
	local result = rules_decimal_fraction.add(-1, { text = "0.00", value = 0.00, cursor_offset = 3 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "-0.01")
	expect.equality(result.cursor, 4) -- cursor on "1" (index 4)
end

edge_boundary_tests["zero_three_decimals_integer_increment"] = function()
	-- "0.001" cursor on integer (0), +1 -> "1.001"
	local result = rules_decimal_fraction.add(1, { text = "0.001", value = 0.001, cursor_offset = 0 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "1.001")
	expect.equality(result.cursor, 0) -- cursor on "1" (index 0)
end

edge_boundary_tests["zero_with_positive_sign_increment"] = function()
	local result = rules_decimal_fraction.add(1, { text = "+0.00", value = 0.00, cursor_offset = 1 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "+1.00")
	expect.equality(result.cursor, 1) -- cursor on "1" (index 1, "+" at index 0)
end

edge_boundary_tests["zero_with_positive_sign_fraction_increment"] = function()
	local result = rules_decimal_fraction.add(1, { text = "+0.00", value = 0.00, cursor_offset = 3 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "+0.01")
	expect.equality(result.cursor, 4) -- cursor on "1" (index 4, "+" at index 0)
end

-- Very small values
edge_boundary_tests["very_small_positive_increment"] = function()
	local result = rules_decimal_fraction.add(1, { text = "0.0001", value = 0.0001, cursor_offset = 5 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "0.0002")
	expect.equality(result.cursor, 5) -- cursor on "2" (index 5)
end

edge_boundary_tests["very_small_negative_increment"] = function()
	local result = rules_decimal_fraction.add(-1, { text = "0.0001", value = 0.0001, cursor_offset = 5 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "0.0000")
	expect.equality(result.cursor, 5) -- cursor on last "0" (index 5)
end

edge_boundary_tests["very_small_negative_decrement"] = function()
	local result = rules_decimal_fraction.add(1, { text = "-0.0001", value = -0.0001, cursor_offset = 6 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "0.0000")
	expect.equality(result.cursor, 5) -- cursor on last "0" (index 5, zero has no sign)
end

-- Sign transition boundaries
edge_boundary_tests["positive_to_negative_via_zero"] = function()
	-- "+0.01" -1 on fraction -> "+0.00", -1 again -> "-0.01"
	local result1 = rules_decimal_fraction.add(-1, { text = "+0.01", value = 0.01, cursor_offset = 3 })
	expect.equality(type(result1), "table")
	expect.equality(result1.text, "+0.00")
	expect.equality(result1.cursor, 4)

	local result2 = rules_decimal_fraction.add(-1, { text = "+0.00", value = 0.00, cursor_offset = 4 })
	expect.equality(type(result2), "table")
	expect.equality(result2.text, "-0.01")
	expect.equality(result2.cursor, 4)
end

edge_boundary_tests["negative_to_positive_via_zero"] = function()
	-- "-0.01" +1 on fraction -> "0.00" (zero has no sign), +1 again -> "0.01"
	local result1 = rules_decimal_fraction.add(1, { text = "-0.01", value = -0.01, cursor_offset = 4 })
	expect.equality(type(result1), "table")
	expect.equality(result1.text, "0.00")
	expect.equality(result1.cursor, 3)

	local result2 = rules_decimal_fraction.add(1, { text = "0.00", value = 0.00, cursor_offset = 4 })
	expect.equality(type(result2), "table")
	expect.equality(result2.text, "0.01")
	expect.equality(result2.cursor, 3)
end

-- Preserving trailing zeros
edge_boundary_tests["preserve_trailing_zeros_on_increment"] = function()
	local result = rules_decimal_fraction.add(1, { text = "1.500", value = 1.500, cursor_offset = 4 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "1.501")
	expect.equality(result.cursor, 4) -- cursor on "1" (index 4)
end

edge_boundary_tests["preserve_trailing_zeros_on_decrement"] = function()
	local result = rules_decimal_fraction.add(-1, { text = "2.3000", value = 2.3000, cursor_offset = 5 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "2.2999")
	expect.equality(result.cursor, 5) -- cursor on last "9" (index 5)
end

-- Large decimal places
edge_boundary_tests["ten_decimal_places_increment"] = function()
	local result = rules_decimal_fraction.add(1, { text = "0.1234567890", value = 0.1234567890, cursor_offset = 10 })
	expect.equality(type(result), "table")
	expect.equality(result.text, "0.1234567891")
	expect.equality(result.cursor, 11) -- cursor on "1" (index 11)
end

T["edge_boundary"] = edge_boundary_tests

return T
