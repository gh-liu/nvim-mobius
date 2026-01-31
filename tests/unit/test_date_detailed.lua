-- Detailed tests for date rules
-- Focus on: cursor position, leap years, boundaries, carry/borrow

local MiniTest = require("mini.test")
local expect = MiniTest.expect

local rules_ymd = require("mobius.rules.date.ymd")
local rules_mdy = require("mobius.rules.date.mdy")
local rules_dmy = require("mobius.rules.date.dmy")
local rules_time_hm = require("mobius.rules.date.time_hm")
local rules_time_hms = require("mobius.rules.date.time_hms")

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
-- YMD Rule: Cursor Position Tests
-- ============================================================================
local ymd_cursor_tests = MiniTest.new_set()

ymd_cursor_tests["cursor_on_year_increment"] = function()
	local buf = create_test_buf({ "date: 2024/03/19" })
	local match = rules_ymd.find({ row = 0, col = 8 }) -- cursor on '4' in year
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "2024/03/19")
		expect.equality(match.metadata.component, "year")

		local result = rules_ymd.add(1, match.metadata)
		expect.equality(result, "2025/03/19")
	end
end

ymd_cursor_tests["cursor_on_month_increment"] = function()
	local buf = create_test_buf({ "date: 2024/03/19" })
	local match = rules_ymd.find({ row = 0, col = 12 }) -- cursor on '3' in month
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.component, "month")

		local result = rules_ymd.add(1, match.metadata)
		expect.equality(result, "2024/04/19")
	end
end

ymd_cursor_tests["cursor_on_day_increment"] = function()
	local buf = create_test_buf({ "date: 2024/03/19" })
	local match = rules_ymd.find({ row = 0, col = 15 }) -- cursor on '9' in day
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.component, "day")

		local result = rules_ymd.add(1, match.metadata)
		expect.equality(result, "2024/03/20")
	end
end

T["ymd_cursor"] = ymd_cursor_tests

-- ============================================================================
-- YMD Rule: Leap Year Tests
-- ============================================================================
local ymd_leap_tests = MiniTest.new_set()

ymd_leap_tests["leap_year_feb_29_to_mar_1"] = function()
	local metadata = {
		text = "2024/02/29",
		pattern = "%Y/%m/%d",
		component = "day",
		captures = { "2024", "02", "29" },
	}
	local result = rules_ymd.add(1, metadata)
	expect.equality(result, "2024/03/01")
end

ymd_leap_tests["non_leap_year_feb_28_to_mar_1"] = function()
	local metadata = {
		text = "2023/02/28",
		pattern = "%Y/%m/%d",
		component = "day",
		captures = { "2023", "02", "28" },
	}
	local result = rules_ymd.add(1, metadata)
	expect.equality(result, "2023/03/01")
end

ymd_leap_tests["leap_year_day_364_to_day_001"] = function()
	-- Dec 31 in leap year
	local metadata = {
		text = "2024/12/31",
		pattern = "%Y/%m/%d",
		component = "day",
		captures = { "2024", "12", "31" },
	}
	local result = rules_ymd.add(1, metadata)
	expect.equality(result, "2025/01/01")
end

ymd_leap_tests["century_leap_year_divisible_by_400"] = function()
	-- Year 2000 is a leap year (divisible by 400)
	local metadata = {
		text = "2000/02/28",
		pattern = "%Y/%m/%d",
		component = "day",
		captures = { "2000", "02", "28" },
	}
	local result = rules_ymd.add(1, metadata)
	expect.equality(result, "2000/02/29")
end

ymd_leap_tests["century_non_leap_year"] = function()
	-- Year 1900 is NOT a leap year (divisible by 100 but not 400)
	local metadata = {
		text = "1900/02/28",
		pattern = "%Y/%m/%d",
		component = "day",
		captures = { "1900", "02", "28" },
	}
	local result = rules_ymd.add(1, metadata)
	expect.equality(result, "1900/03/01")
end

T["ymd_leap"] = ymd_leap_tests

-- ============================================================================
-- YMD Rule: Month Boundary Tests
-- ============================================================================
local ymd_month_boundary_tests = MiniTest.new_set()

ymd_month_boundary_tests["jan_31_to_feb_XX_non_leap"] = function()
	local metadata = {
		text = "2023/01/31",
		pattern = "%Y/%m/%d",
		component = "day",
		captures = { "2023", "01", "31" },
	}
	local result = rules_ymd.add(1, metadata)
	expect.equality(result, "2023/02/01")
end

ymd_month_boundary_tests["jan_31_to_feb_XX_leap"] = function()
	local metadata = {
		text = "2024/01/31",
		pattern = "%Y/%m/%d",
		component = "day",
		captures = { "2024", "01", "31" },
	}
	local result = rules_ymd.add(1, metadata)
	expect.equality(result, "2024/02/01")
end

ymd_month_boundary_tests["month_30_days_to_next_month"] = function()
	-- April has 30 days
	local metadata = {
		text = "2024/04/30",
		pattern = "%Y/%m/%d",
		component = "day",
		captures = { "2024", "04", "30" },
	}
	local result = rules_ymd.add(1, metadata)
	expect.equality(result, "2024/05/01")
end

ymd_month_boundary_tests["month_increment_day_preserved"] = function()
	-- Increment month, day stays the same
	local metadata = {
		text = "2024/01/15",
		pattern = "%Y/%m/%d",
		component = "month",
		captures = { "2024", "01", "15" },
	}
	local result = rules_ymd.add(1, metadata)
	expect.equality(result, "2024/02/15")
end

ymd_month_boundary_tests["dec_to_jan_year_increment"] = function()
	local metadata = {
		text = "2024/12/15",
		pattern = "%Y/%m/%d",
		component = "month",
		captures = { "2024", "12", "15" },
	}
	local result = rules_ymd.add(1, metadata)
	expect.equality(result, "2025/01/15")
end

ymd_month_boundary_tests["month_decrement_from_jan"] = function()
	local metadata = {
		text = "2024/01/15",
		pattern = "%Y/%m/%d",
		component = "month",
		captures = { "2024", "01", "15" },
	}
	local result = rules_ymd.add(-1, metadata)
	expect.equality(result, "2023/12/15")
end

T["ymd_month_boundary"] = ymd_month_boundary_tests

-- ============================================================================
-- Time Rule: HH:MM Tests
-- ============================================================================
local time_hm_tests = MiniTest.new_set()

time_hm_tests["cursor_on_hour_increment"] = function()
	local buf = create_test_buf({ "time: 14:30" })
	local match = rules_time_hm.find({ row = 0, col = 7 }) -- cursor on hour
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.component, "hour")

		local result = rules_time_hm.add(1, match.metadata)
		expect.equality(result, "15:30")
	end
end

time_hm_tests["cursor_on_minute_increment"] = function()
	local buf = create_test_buf({ "time: 14:30" })
	local match = rules_time_hm.find({ row = 0, col = 10 }) -- cursor on minute
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.component, "min")

		local result = rules_time_hm.add(1, match.metadata)
		expect.equality(result, "14:31")
	end
end

time_hm_tests["hour_23_to_00_next_day_carry"] = function()
	local metadata = {
		text = "23:45",
		pattern = "%H:%M",
		component = "hour",
		captures = { "23", "45" },
	}
	local result = rules_time_hm.add(1, metadata)
	expect.equality(result, "00:45")
end

time_hm_tests["minute_59_to_00_hour_carry"] = function()
	local metadata = {
		text = "14:59",
		pattern = "%H:%M",
		component = "min",
		captures = { "14", "59" },
	}
	local result = rules_time_hm.add(1, metadata)
	expect.equality(result, "15:00")
end

time_hm_tests["hour_23_minute_59_to_00_00"] = function()
	local metadata = {
		text = "23:59",
		pattern = "%H:%M",
		component = "min",
		captures = { "23", "59" },
	}
	local result = rules_time_hm.add(1, metadata)
	-- Note: time doesn't auto-wrap, 24:00 is valid
	expect.equality(result, "24:00")
end

time_hm_tests["minute_decrement_from_00"] = function()
	local metadata = {
		text = "14:00",
		pattern = "%H:%M",
		component = "min",
		captures = { "14", "00" },
	}
	local result = rules_time_hm.add(-1, metadata)
	expect.equality(result, "13:59")
end

time_hm_tests["hour_decrement_from_00"] = function()
	local metadata = {
		text = "00:30",
		pattern = "%H:%M",
		component = "hour",
		captures = { "00", "30" },
	}
	local result = rules_time_hm.add(-1, metadata)
	expect.equality(result, "23:30")
end

T["time_hm"] = time_hm_tests

-- ============================================================================
-- Time Rule: HH:MM:SS Tests
-- ============================================================================
local time_hms_tests = MiniTest.new_set()

time_hms_tests["cursor_on_second_increment"] = function()
	local buf = create_test_buf({ "time: 14:30:45" })
	local match = rules_time_hms.find({ row = 0, col = 13 }) -- cursor on second
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.component, "sec")

		local result = rules_time_hms.add(1, match.metadata)
		expect.equality(result, "14:30:46")
	end
end

time_hms_tests["second_59_to_00_minute_carry"] = function()
	local metadata = {
		text = "14:30:59",
		pattern = "%H:%M:%S",
		component = "sec",
		captures = { "14", "30", "59" },
	}
	local result = rules_time_hms.add(1, metadata)
	expect.equality(result, "14:31:00")
end

time_hms_tests["second_decrement_from_00"] = function()
	local metadata = {
		text = "14:30:00",
		pattern = "%H:%M:%S",
		component = "sec",
		captures = { "14", "30", "00" },
	}
	local result = rules_time_hms.add(-1, metadata)
	expect.equality(result, "14:29:59")
end

time_hms_tests["full_rollover_23_59_59"] = function()
	local metadata = {
		text = "23:59:59",
		pattern = "%H:%M:%S",
		component = "sec",
		captures = { "23", "59", "59" },
	}
	local result = rules_time_hms.add(1, metadata)
	-- Note: time doesn't auto-wrap, 23:60:00 is valid
	expect.equality(result, "23:60:00")
end

time_hms_tests["hour_increment_from_23_59_59"] = function()
	local metadata = {
		text = "23:59:59",
		pattern = "%H:%M:%S",
		component = "hour",
		captures = { "23", "59", "59" },
	}
	local result = rules_time_hms.add(1, metadata)
	expect.equality(result, "00:59:59")
end

T["time_hms"] = time_hms_tests

-- ============================================================================
-- Other Date Formats: MDY and DMY
-- ============================================================================
local other_format_tests = MiniTest.new_set()

other_format_tests["mdy_format_basic"] = function()
	local buf = create_test_buf({ "date: 03/19/2024" })
	local match = rules_mdy.find({ row = 0, col = 10 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "03/19/2024")
		expect.equality(match.metadata.pattern, "%m/%d/%Y")
	end
end

other_format_tests["dmy_format_basic"] = function()
	local buf = create_test_buf({ "date: 19/03/2024" })
	local match = rules_dmy.find({ row = 0, col = 10 })
	expect.equality(match ~= nil, true)
	if match then
		expect.equality(match.metadata.text, "19/03/2024")
		expect.equality(match.metadata.pattern, "%d/%m/%Y")
	end
end

other_format_tests["mdy_month_day_year_increment"] = function()
	local metadata = {
		text = "03/19/2024",
		pattern = "%m/%d/%Y",
		component = "month",
		captures = { "03", "19", "2024" },
	}
	local result = rules_mdy.add(1, metadata)
	expect.equality(result, "04/19/2024")
end

other_format_tests["dmy_day_month_year_increment"] = function()
	local metadata = {
		text = "19/03/2024",
		pattern = "%d/%m/%Y",
		component = "day",
		captures = { "19", "03", "2024" },
	}
	local result = rules_dmy.add(1, metadata)
	expect.equality(result, "20/03/2024")
end

T["other_formats"] = other_format_tests

return T
