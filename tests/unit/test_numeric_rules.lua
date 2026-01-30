-- Unit tests for numeric rules: integer, hex, octal, decimal_fraction
-- Tests focus on find() and add() functions in isolation

local MiniTest = require("mini.test")
local expect = MiniTest.expect

local rules_integer = require("mobius.rules.numeric.integer")
local rules_hex = require("mobius.rules.numeric.hex")
local rules_octal = require("mobius.rules.numeric.octal")
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

local T = MiniTest.new_set({
	hooks = {
		pre_case = function() end,
		post_case = function() end,
	},
})

-- ============================================================================
-- Integer Rule
-- ============================================================================
local integer_tests = MiniTest.new_set()

integer_tests["add_basic"] = function()
	expect.equality(rules_integer.add(1, { text = "123" }), "124")
	expect.equality(rules_integer.add(-1, { text = "123" }), "122")
end

integer_tests["add_negative"] = function()
	expect.equality(rules_integer.add(-1, { text = "-1" }), "-2")
	expect.equality(rules_integer.add(1, { text = "-1" }), "0")
end

integer_tests["add_positive_sign"] = function()
	expect.equality(rules_integer.add(-1, { text = "+1" }), "0")
	expect.equality(rules_integer.add(-2, { text = "+1" }), "-1")
end

integer_tests["add_large"] = function()
	expect.equality(rules_integer.add(1, { text = "999999999" }), "1000000000")
	expect.equality(rules_integer.add(-1, { text = "1000000000" }), "999999999")
end

integer_tests["find_basic"] = function()
	local buf = create_test_buf({ "foo 123 bar" })
	local match = rules_integer.find({ row = 0, col = 4 })
	expect.equality(match ~= nil, true)
	expect.equality(match.metadata.text, "123")
end

integer_tests["find_negative"] = function()
	local buf = create_test_buf({ "x -1 y" })
	local match = rules_integer.find({ row = 0, col = 3 })
	expect.equality(match ~= nil, true)
	expect.equality(match.metadata.text, "-1")
end

integer_tests["find_positive"] = function()
	local buf = create_test_buf({ "x +1 y" })
	local match = rules_integer.find({ row = 0, col = 3 })
	expect.equality(match ~= nil, true)
	expect.equality(match.metadata.text, "+1")
end

integer_tests["find_no_match"] = function()
	local buf = create_test_buf({ "foo bar" })
	expect.equality(rules_integer.find({ row = 0, col = 0 }), nil)
end

T["integer"] = integer_tests

-- ============================================================================
-- Hex Rule
-- ============================================================================
local hex_tests = MiniTest.new_set()

hex_tests["add_basic"] = function()
	expect.equality(rules_hex.add(1, { text = "0xFF", value = 255 }), "0x100")
	expect.equality(rules_hex.add(1, { text = "0XFF", value = 255 }), "0X100")
end

hex_tests["add_uppercase_consistency"] = function()
	expect.equality(rules_hex.add(1, { text = "0XFF", value = 255 }), "0X100")
end

hex_tests["add_lowercase_consistency"] = function()
	expect.equality(rules_hex.add(1, { text = "0xff", value = 255 }), "0x100")
end

hex_tests["add_decrement_wrap_single_digit"] = function()
	-- 0x8 (1 digit): 0 - 1 wraps to 0xf, not 0xffffffffffffffff
	expect.equality(rules_hex.add(-1, { text = "0x0", value = 0 }), "0xf")
	expect.equality(rules_hex.add(-8, { text = "0x8", value = 8 }), "0x0")
	expect.equality(rules_hex.add(-9, { text = "0x8", value = 8 }), "0xf")
end

hex_tests["add_decrement_wrap_double_digit"] = function()
	-- 0x00 (2 digits): 0 - 1 wraps to 0xff
	expect.equality(rules_hex.add(-1, { text = "0x00", value = 0 }), "0xff")
end

hex_tests["add_single_digit_wrap"] = function()
	expect.equality(rules_hex.add(-6, { text = "0x5", value = 5 }), "0xf")
end

hex_tests["find_basic"] = function()
	local buf = create_test_buf({ "color: 0xFF" })
	local match = rules_hex.find({ row = 0, col = 8 })
	expect.equality(match ~= nil, true)
	expect.equality(match.metadata.text, "0xFF")
	expect.equality(match.metadata.value, 255)
end

hex_tests["find_lowercase"] = function()
	local buf = create_test_buf({ "0xabcd" })
	local match = rules_hex.find({ row = 0, col = 3 })
	expect.equality(match ~= nil, true)
	expect.equality(match.metadata.text, "0xabcd")
	expect.equality(match.metadata.value, 43981)
end

hex_tests["find_no_match"] = function()
	local buf = create_test_buf({ "no hex" })
	expect.equality(rules_hex.find({ row = 0, col = 0 }), nil)
end

T["hex"] = hex_tests

-- ============================================================================
-- Octal Rule
-- ============================================================================
local octal_tests = MiniTest.new_set()

octal_tests["add_basic"] = function()
	expect.equality(rules_octal.add(1, { text = "0o755", value = 493 }), "0o756")
	expect.equality(rules_octal.add(-1, { text = "0o755", value = 493 }), "0o754")
end

octal_tests["add_zero"] = function()
	expect.equality(rules_octal.add(1, { text = "0o0", value = 0 }), "0o1")
end

octal_tests["add_uppercase"] = function()
	expect.equality(rules_octal.add(1, { text = "0O755", value = 493 }), "0O756")
end

octal_tests["add_wrap_single_digit"] = function()
	-- 0o0 (1 digit): 0 - 1 wraps to 0o7
	expect.equality(rules_octal.add(-1, { text = "0o0", value = 0 }), "0o7")
	expect.equality(rules_octal.add(-8, { text = "0o10", value = 8 }), "0o0")
end

octal_tests["find_basic"] = function()
	local buf = create_test_buf({ "chmod 0o755 file" })
	local match = rules_octal.find({ row = 0, col = 6 })
	expect.equality(match ~= nil, true)
	expect.equality(match.metadata.text, "0o755")
	expect.equality(match.metadata.value, 493) -- 0o755 in decimal
end

octal_tests["find_uppercase"] = function()
	local buf = create_test_buf({ "mode: 0O644" })
	local match = rules_octal.find({ row = 0, col = 7 })
	expect.equality(match ~= nil, true)
	expect.equality(match.metadata.text, "0O644")
	expect.equality(match.metadata.value, 420)
end

T["octal"] = octal_tests

-- ============================================================================
-- Decimal Fraction Rule
-- ============================================================================
local decimal_tests = MiniTest.new_set()

decimal_tests["add_basic"] = function()
	local result1 = rules_decimal_fraction.add(1, { text = "1.5", value = 1.5 })
	local result2 = rules_decimal_fraction.add(-1, { text = "1.5", value = 1.5 })
	-- add() can return string or table; extract text if table
	local text1 = type(result1) == "table" and result1.text or result1
	local text2 = type(result2) == "table" and result2.text or result2
	expect.equality(text1, "2.5")
	expect.equality(text2, "0.5")
end

decimal_tests["add_preserve_decimal_places"] = function()
	local result1 = rules_decimal_fraction.add(1, { text = "1.25", value = 1.25 })
	local result2 = rules_decimal_fraction.add(1, { text = "1.250", value = 1.250 })
	local text1 = type(result1) == "table" and result1.text or result1
	local text2 = type(result2) == "table" and result2.text or result2
	expect.equality(text1, "2.25")
	expect.equality(text2, "2.250")
end

decimal_tests["find_basic"] = function()
	local buf = create_test_buf({ "price 1.5 usd" })
	local match = rules_decimal_fraction.find({ row = 0, col = 6 })
	expect.equality(match ~= nil, true)
	expect.equality(match.metadata.text, "1.5")
end

decimal_tests["add_negative_cross_zero"] = function()
	local result = rules_decimal_fraction.add(-2, { text = "0.5", value = 0.5 })
	local text = type(result) == "table" and result.text or result
	expect.equality(text, "-1.5")
end

decimal_tests["add_large_decimal"] = function()
	local result = rules_decimal_fraction.add(10, { text = "0.1", value = 0.1 })
	local text = type(result) == "table" and result.text or result
	-- 0.1 + 10 = 10.1
	expect.equality(text, "10.1")
end

T["decimal_fraction"] = decimal_tests

return T
