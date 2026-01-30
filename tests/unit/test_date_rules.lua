-- Unit tests for date rules
-- Tests focus on find() and add() functions in isolation

local MiniTest = require("mini.test")
local expect = MiniTest.expect

local rules_ymd = require("mobius.rules.date.ymd")
local rules_mdy = require("mobius.rules.date.mdy")
local rules_dmy = require("mobius.rules.date.dmy")

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
-- YMD Rule (YYYY/MM/DD)
-- ============================================================================
local ymd_tests = MiniTest.new_set()

ymd_tests["find_basic"] = function()
	local buf = create_test_buf({ "date: 2024/03/19" })
	local match = rules_ymd.find({ row = 0, col = 6 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "2024/03/19")
		expect.equality(match.metadata.pattern, "%Y/%m/%d")
	end
end

ymd_tests["add_day_increment"] = function()
	local metadata = {
		text = "2024/03/19",
		pattern = "%Y/%m/%d",
		component = "day",
		captures = { "2024", "03", "19" },
	}
	local result = rules_ymd.add(1, metadata)
	expect.equality(type(result), "string")
	expect.equality(result, "2024/03/20")
end

ymd_tests["add_day_decrement"] = function()
	local metadata = {
		text = "2024/03/19",
		pattern = "%Y/%m/%d",
		component = "day",
		captures = { "2024", "03", "19" },
	}
	local result = rules_ymd.add(-1, metadata)
	expect.equality(result, "2024/03/18")
end

ymd_tests["add_month_increment"] = function()
	local metadata = {
		text = "2024/03/19",
		pattern = "%Y/%m/%d",
		component = "month",
		captures = { "2024", "03", "19" },
	}
	local result = rules_ymd.add(1, metadata)
	expect.equality(result, "2024/04/19")
end

ymd_tests["add_year_increment"] = function()
	local metadata = {
		text = "2024/03/19",
		pattern = "%Y/%m/%d",
		component = "year",
		captures = { "2024", "03", "19" },
	}
	local result = rules_ymd.add(1, metadata)
	expect.equality(result, "2025/03/19")
end

-- ============================================================================
-- Critical Issue: 2011/11/11
-- ============================================================================
ymd_tests["issue_2011_11_11_find"] = function()
	local buf = create_test_buf({ "date: 2011/11/11" })
	local match = rules_ymd.find({ row = 0, col = 6 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "2011/11/11")
	end
end

ymd_tests["issue_2011_11_11_day_increment"] = function()
	local metadata = {
		text = "2011/11/11",
		pattern = "%Y/%m/%d",
		component = "day",
		captures = { "2011", "11", "11" },
	}
	-- This should increment day from 11 to 12
	local result = rules_ymd.add(1, metadata)
	expect.equality(result, "2011/11/12")
end

ymd_tests["issue_2011_11_11_month_increment"] = function()
	local metadata = {
		text = "2011/11/11",
		pattern = "%Y/%m/%d",
		component = "month",
		captures = { "2011", "11", "11" },
	}
	-- This should increment month from 11 to 12
	local result = rules_ymd.add(1, metadata)
	expect.equality(result, "2011/12/11")
end

ymd_tests["issue_2011_11_11_year_increment"] = function()
	local metadata = {
		text = "2011/11/11",
		pattern = "%Y/%m/%d",
		component = "year",
		captures = { "2011", "11", "11" },
	}
	-- This should increment year from 2011 to 2012
	local result = rules_ymd.add(1, metadata)
	expect.equality(result, "2012/11/11")
end

ymd_tests["issue_2011_11_11_month_decrement"] = function()
	local metadata = {
		text = "2011/11/11",
		pattern = "%Y/%m/%d",
		component = "month",
		captures = { "2011", "11", "11" },
	}
	-- This should decrement month from 11 to 10
	local result = rules_ymd.add(-1, metadata)
	expect.equality(result, "2011/10/11")
end

ymd_tests["issue_2011_11_11_day_to_next_month"] = function()
	local metadata = {
		text = "2011/11/30",
		pattern = "%Y/%m/%d",
		component = "day",
		captures = { "2011", "11", "30" },
	}
	-- This should overflow to next month
	local result = rules_ymd.add(1, metadata)
	expect.equality(result, "2011/12/01")
end

ymd_tests["issue_2011_11_11_day_to_prev_month"] = function()
	local metadata = {
		text = "2011/11/01",
		pattern = "%Y/%m/%d",
		component = "day",
		captures = { "2011", "11", "01" },
	}
	-- This should underflow to previous month
	local result = rules_ymd.add(-1, metadata)
	expect.equality(result, "2011/10/31")
end

-- ============================================================================
-- Edge cases: Month boundaries
-- ============================================================================
ymd_tests["edge_feb_28_to_29_leap"] = function()
	local metadata = {
		text = "2020/02/28",
		pattern = "%Y/%m/%d",
		component = "day",
		captures = { "2020", "02", "28" },
	}
	-- 2020 is leap year, so Feb 29 exists
	local result = rules_ymd.add(1, metadata)
	expect.equality(result, "2020/02/29")
end

ymd_tests["edge_feb_29_to_mar_nonleap"] = function()
	local metadata = {
		text = "2019/02/28",
		pattern = "%Y/%m/%d",
		component = "day",
		captures = { "2019", "02", "28" },
	}
	-- 2019 is not leap year, so next day is Mar 1
	local result = rules_ymd.add(1, metadata)
	expect.equality(result, "2019/03/01")
end

-- ============================================================================
-- Cursor position tracking
-- ============================================================================
ymd_tests["add_returns_cursor_on_day_change"] = function()
	local metadata = {
		text = "2024/03/19",
		pattern = "%Y/%m/%d",
		component = "day",
		captures = { "2024", "03", "19" },
	}
	local result = rules_ymd.add(1, metadata)
	expect.equality(type(result), "string")
	-- Result should have cursor info if needed
	if type(result) == "table" then
		expect.equality(result.text, "2024/03/20")
	end
end

-- ============================================================================
-- MDY Rule (MM/DD/YYYY)
-- ============================================================================
local mdy_tests = MiniTest.new_set()

mdy_tests["find_basic"] = function()
	local buf = create_test_buf({ "date: 03/19/2024" })
	local match = rules_mdy.find({ row = 0, col = 6 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "03/19/2024")
	end
end

mdy_tests["add_day_increment"] = function()
	local metadata = {
		text = "03/19/2024",
		pattern = "%m/%d/%Y",
		component = "day",
		captures = { "03", "19", "2024" },
	}
	local result = rules_mdy.add(1, metadata)
	expect.equality(result, "03/20/2024")
end

-- ============================================================================
-- DMY Rule (DD/MM/YYYY)
-- ============================================================================
local dmy_tests = MiniTest.new_set()

dmy_tests["find_basic"] = function()
	local buf = create_test_buf({ "date: 19/03/2024" })
	local match = rules_dmy.find({ row = 0, col = 6 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "19/03/2024")
	end
end

dmy_tests["add_day_increment"] = function()
	local metadata = {
		text = "19/03/2024",
		pattern = "%d/%m/%Y",
		component = "day",
		captures = { "19", "03", "2024" },
	}
	local result = rules_dmy.add(1, metadata)
	expect.equality(result, "20/03/2024")
end

-- ============================================================================
-- Stress tests with multiple same digits
-- ============================================================================
ymd_tests["stress_all_ones"] = function()
	local metadata = {
		text = "1111/11/11",
		pattern = "%Y/%m/%d",
		component = "day",
		captures = { "1111", "11", "11" },
	}
	local result = rules_ymd.add(1, metadata)
	expect.equality(result, "1111/11/12")
end

ymd_tests["stress_all_twos"] = function()
	local metadata = {
		text = "2222/02/22",
		pattern = "%Y/%m/%d",
		component = "month",
		captures = { "2222", "02", "22" },
	}
	-- February, so next is March
	local result = rules_ymd.add(1, metadata)
	expect.equality(result, "2222/03/22")
end

-- ============================================================================
-- Register tests
-- ============================================================================
T["YMD"] = ymd_tests
T["MDY"] = mdy_tests
T["DMY"] = dmy_tests

return T
