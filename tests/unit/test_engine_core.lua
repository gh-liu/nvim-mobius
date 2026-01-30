-- Unit tests for engine core: execution modes, priority, caching, boundary conditions
-- Tests engine.execute() and rule loading logic

local MiniTest = require("mini.test")
local expect = MiniTest.expect

local engine = require("mobius.engine")

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
		pre_case = function()
			vim.g.mobius_rules = {
				"mobius.rules.numeric.integer",
				"mobius.rules.numeric.hex",
				"mobius.rules.constant.bool",
			}
		end,
		post_case = function()
			vim.g.mobius_rules = nil
			vim.b.mobius_rules = nil
		end,
	},
})

-- ============================================================================
-- Normal Mode (single increment/decrement)
-- ============================================================================
local normal_mode_tests = MiniTest.new_set()

normal_mode_tests["normal_increment"] = function()
	local buf = create_test_buf({ "foo 5 bar" })
	vim.api.nvim_win_set_cursor(0, { 1, 4 })
	engine.execute("increment", { visual = false, seqadd = false, step = 1 })
	-- Oracle: content check
	expect.equality(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "foo 6 bar")
	-- Oracle: cursor should stay on modified element (at col 4)
	local cursor_after = vim.api.nvim_win_get_cursor(0)
	expect.equality(cursor_after[2], 4)
end

normal_mode_tests["normal_decrement"] = function()
	local buf = create_test_buf({ "foo 5 bar" })
	vim.api.nvim_win_set_cursor(0, { 1, 4 })
	engine.execute("decrement", { visual = false, seqadd = false, step = 1 })
	expect.equality(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "foo 4 bar")
	-- Oracle: cursor should stay on modified element (at col 4)
	local cursor_after = vim.api.nvim_win_get_cursor(0)
	expect.equality(cursor_after[2], 4)
end

normal_mode_tests["normal_custom_step"] = function()
	local buf = create_test_buf({ "foo 10 bar" })
	vim.api.nvim_win_set_cursor(0, { 1, 4 })
	engine.execute("increment", { visual = false, seqadd = false, step = 5 })
	expect.equality(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "foo 15 bar")
	-- Oracle: cursor should stay on modified element (at col 4)
	local cursor_after = vim.api.nvim_win_get_cursor(0)
	expect.equality(cursor_after[2], 4)
end

normal_mode_tests["normal_no_match"] = function()
	local buf = create_test_buf({ "foo bar" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	local before = vim.api.nvim_buf_get_lines(buf, 0, 1, false)
	engine.execute("increment", { visual = false, seqadd = false, step = 1 })
	local after = vim.api.nvim_buf_get_lines(buf, 0, 1, false)
	expect.equality(before, after)
end

-- Cursor inside paren content must NOT trigger paren (only ( or ) should)
normal_mode_tests["paren_no_change_when_cursor_inside_content"] = function()
	vim.g.mobius_rules = { "mobius.rules.paren" }
	local buf = create_test_buf({ "(balabalabala)" })
	vim.api.nvim_win_set_cursor(0, { 1, 5 })
	engine.execute("increment", { visual = false, seqadd = false, step = 1 })
	expect.equality(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "(balabalabala)")
	-- Oracle: cursor should remain at same position (no match, no move)
	local cursor_after = vim.api.nvim_win_get_cursor(0)
	expect.equality(cursor_after[2], 5)
end

T["normal_mode"] = normal_mode_tests

-- ============================================================================
-- Visual Mode (same addend for all selections)
-- ============================================================================
local visual_mode_tests = MiniTest.new_set()

visual_mode_tests["visual_same_addend_two_lines"] = function()
	local buf = create_test_buf({ "1", "2" })
	vim.api.nvim_buf_set_mark(buf, "<", 1, 0, {})
	vim.api.nvim_buf_set_mark(buf, ">", 2, 0, {})
	engine.execute("increment", { visual = true, seqadd = false, step = 1 })
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	expect.equality(lines[1], "2")
	expect.equality(lines[2], "3")
	-- Oracle: cursor should be on first match (row 1, col 0)
	local cursor_after = vim.api.nvim_win_get_cursor(0)
	expect.equality(cursor_after[1], 1)
	expect.equality(cursor_after[2], 0)
end

visual_mode_tests["visual_same_addend_three_lines"] = function()
	local buf = create_test_buf({ "10", "10", "10" })
	vim.api.nvim_buf_set_mark(buf, "<", 1, 0, {})
	vim.api.nvim_buf_set_mark(buf, ">", 3, 0, {})
	engine.execute("increment", { visual = true, seqadd = false, step = 1 })
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	expect.equality(lines[1], "11")
	expect.equality(lines[2], "11")
	expect.equality(lines[3], "11")
	-- Oracle: cursor should be on first match (row 1, col 0)
	local cursor_after = vim.api.nvim_win_get_cursor(0)
	expect.equality(cursor_after[1], 1)
	expect.equality(cursor_after[2], 0)
end

visual_mode_tests["visual_single_line_multiple_matches"] = function()
	local buf = create_test_buf({ "1 2 3" })
	vim.api.nvim_buf_set_mark(buf, "<", 1, 0, {})
	vim.api.nvim_buf_set_mark(buf, ">", 1, 4, {})
	engine.execute("increment", { visual = true, seqadd = false, step = 1 })
	expect.equality(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "2 3 4")
	-- Oracle: cursor should be on first match (col 0, which is "2")
	local cursor_after = vim.api.nvim_win_get_cursor(0)
	expect.equality(cursor_after[2], 0)
end

T["visual_mode"] = visual_mode_tests

-- ============================================================================
-- Visual Sequential (seqadd=true: addend = step * index)
-- ============================================================================
local seqadd_tests = MiniTest.new_set()

seqadd_tests["seqadd_two_lines"] = function()
	local buf = create_test_buf({ "1", "1" })
	vim.api.nvim_buf_set_mark(buf, "<", 1, 0, {})
	vim.api.nvim_buf_set_mark(buf, ">", 2, 0, {})
	engine.execute("increment", { visual = true, seqadd = true, step = 1 })
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	expect.equality(lines[1], "2")
	expect.equality(lines[2], "3")
	-- Oracle: cursor should be on first match (row 1, col 0)
	local cursor_after = vim.api.nvim_win_get_cursor(0)
	expect.equality(cursor_after[1], 1)
	expect.equality(cursor_after[2], 0)
end

seqadd_tests["seqadd_three_lines"] = function()
	local buf = create_test_buf({ "0", "0", "0" })
	vim.api.nvim_buf_set_mark(buf, "<", 1, 0, {})
	vim.api.nvim_buf_set_mark(buf, ">", 3, 0, {})
	engine.execute("increment", { visual = true, seqadd = true, step = 1 })
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	expect.equality(lines[1], "1")
	expect.equality(lines[2], "2")
	expect.equality(lines[3], "3")
	-- Oracle: cursor should be on first match (row 1, col 0)
	local cursor_after = vim.api.nvim_win_get_cursor(0)
	expect.equality(cursor_after[1], 1)
	expect.equality(cursor_after[2], 0)
end

seqadd_tests["seqadd_single_line_multiple_matches"] = function()
	local buf = create_test_buf({ "1 2 3" })
	vim.api.nvim_buf_set_mark(buf, "<", 1, 0, {})
	vim.api.nvim_buf_set_mark(buf, ">", 1, 4, {})
	engine.execute("increment", { visual = true, seqadd = true, step = 1 })
	expect.equality(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "2 4 6")
	-- Oracle: cursor should be on first match (col 0, which is "2")
	local cursor_after = vim.api.nvim_win_get_cursor(0)
	expect.equality(cursor_after[2], 0)
end

T["seqadd"] = seqadd_tests

-- ============================================================================
-- Priority and Match Selection
-- ============================================================================
local priority_tests = MiniTest.new_set()

priority_tests["priority_hex_matches_first"] = function()
	vim.g.mobius_rules = {
		require("mobius.rules.numeric.hex")({ priority = 60 }),
		require("mobius.rules.numeric.integer")({ priority = 50 }),
	}
	local buf = create_test_buf({ "0x10" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	engine.execute("increment", { visual = false, seqadd = false, step = 1 })
	-- Hex has priority, should match 0x10 -> 0x11
	expect.equality(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "0x11")
	-- Oracle: cursor should stay on match (at col 0)
	local cursor_after = vim.api.nvim_win_get_cursor(0)
	expect.equality(cursor_after[2], 0)
end

T["priority"] = priority_tests

-- ============================================================================
-- Buffer-Local Rules
-- ============================================================================
local buffer_local_tests = MiniTest.new_set()

buffer_local_tests["buffer_local_inherit_global"] = function()
	vim.g.mobius_rules = { "mobius.rules.numeric.integer" }
	local buf = create_test_buf({ "5" })
	vim.b.mobius_rules = { true, "mobius.rules.constant.bool" }
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	-- Should match integer (from global)
	engine.execute("increment", { visual = false, seqadd = false, step = 1 })
	expect.equality(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "6")
	-- Oracle: cursor should stay on modified element (at col 0)
	local cursor_after = vim.api.nvim_win_get_cursor(0)
	expect.equality(cursor_after[2], 0)
end

buffer_local_tests["buffer_local_override"] = function()
	vim.g.mobius_rules = { "mobius.rules.numeric.integer" }
	local buf = create_test_buf({ "true" })
	vim.b.mobius_rules = { "mobius.rules.constant.bool" } -- No inherit
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	-- Should match bool (not integer)
	engine.execute("increment", { visual = false, seqadd = false, step = 1 })
	expect.equality(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "false")
	-- Oracle: cursor should stay on modified element (at col 0)
	local cursor_after = vim.api.nvim_win_get_cursor(0)
	expect.equality(cursor_after[2], 0)
end

T["buffer_local"] = buffer_local_tests

-- ============================================================================
-- Custom Rules via opts.rules
-- ============================================================================
local opts_rules_tests = MiniTest.new_set()

opts_rules_tests["opts_rules_override_global"] = function()
	vim.g.mobius_rules = { "mobius.rules.numeric.integer" }
	local buf = create_test_buf({ "true" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	-- Passing only integer rule should not match bool
	engine.execute("increment", { visual = false, seqadd = false, step = 1, rules = { "mobius.rules.numeric.integer" } })
	expect.equality(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "true")
end

opts_rules_tests["opts_rules_custom_inline"] = function()
	local custom_rule = {
		id = "custom_enum",
		priority = 50,
		find = function(cursor)
			local row, col = cursor.row, cursor.col
			local b = vim.api.nvim_get_current_buf()
			local lines = vim.api.nvim_buf_get_lines(b, row, row + 1, false)
			local line = lines[1] or ""
			local pattern = "foo"
			local start, end_pos = line:find(pattern)
			if start and end_pos >= col + 1 then
				return { col = start - 1, end_col = end_pos - 1, metadata = { text = line:sub(start, end_pos) } }
			end
			return nil
		end,
		add = function(addend, metadata)
			if metadata.text == "foo" then
				return "bar"
			elseif metadata.text == "bar" then
				return "baz"
			else
				return "foo"
			end
		end,
	}
	local buf = create_test_buf({ "foo bar baz" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	engine.execute("increment", { visual = false, seqadd = false, step = 1, rules = { custom_rule } })
	expect.equality(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "bar bar baz")
	-- Oracle: cursor should stay on modified element (at col 0)
	local cursor_after = vim.api.nvim_win_get_cursor(0)
	expect.equality(cursor_after[2], 0)
end

T["opts_rules"] = opts_rules_tests

-- ============================================================================
-- Caching and Invalidation
-- ============================================================================
local cache_tests = MiniTest.new_set()

cache_tests["cache_clear_manual"] = function()
	local buf = create_test_buf({ "5" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	-- First execute (loads cache)
	engine.execute("increment", { visual = false, seqadd = false, step = 1 })
	expect.equality(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "6")
	-- Oracle: cursor should be on element (at col 0)
	local cursor_mid = vim.api.nvim_win_get_cursor(0)
	expect.equality(cursor_mid[2], 0)
	-- Manual cache clear
	engine.clear_cache(buf)
	-- Should still work
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	engine.execute("increment", { visual = false, seqadd = false, step = 1 })
	expect.equality(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "7")
	-- Oracle: cursor should be on element (at col 0)
	local cursor_after = vim.api.nvim_win_get_cursor(0)
	expect.equality(cursor_after[2], 0)
end

T["cache"] = cache_tests

-- ============================================================================
-- Boundary and Error Conditions
-- ============================================================================
local boundary_tests = MiniTest.new_set()

boundary_tests["empty_buffer"] = function()
	local buf = create_test_buf({ "" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	local before = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	engine.execute("increment", { visual = false, seqadd = false, step = 1 })
	local after = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	expect.equality(before, after)
end

boundary_tests["cursor_at_end_of_line"] = function()
	local buf = create_test_buf({ "5" })
	vim.api.nvim_win_set_cursor(0, { 1, 1 }) -- cursor after "5"
	engine.execute("increment", { visual = false, seqadd = false, step = 1 })
	-- Should still find the number
	expect.equality(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "6")
end

boundary_tests["rule_returns_nil"] = function()
	-- cyclic=false rule at boundary returns nil
	local buf = create_test_buf({ "# Header" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	engine.execute("decrement", { visual = false, seqadd = false, step = 1 })
	-- Markdown header at level 1, decrement returns nil → no change
	expect.equality(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "# Header")
end

boundary_tests["find_returns_nil"] = function()
	local buf = create_test_buf({ "no match" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	local before = vim.api.nvim_buf_get_lines(buf, 0, 1, false)
	engine.execute("increment", { visual = false, seqadd = false, step = 1 })
	local after = vim.api.nvim_buf_get_lines(buf, 0, 1, false)
	expect.equality(before, after)
end

boundary_tests["find_invalid_metadata"] = function()
	local buf = create_test_buf({ "123" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	local bad_rule = {
		id = "bad_find",
		priority = 50,
		find = function(cursor)
			local row, col = cursor.row, cursor.col
			local b = vim.api.nvim_get_current_buf()
			local lines = vim.api.nvim_buf_get_lines(b, row, row + 1, false)
			local line = lines[1] or ""
			local start, end_pos = line:find("%d+")
			if start and end_pos >= col + 1 then
				return { col = start - 1, end_col = end_pos - 1, metadata = {} } -- missing text
			end
			return nil
		end,
		add = function(addend, metadata)
			return "0"
		end,
	}
	vim.g.mobius_rules = { bad_rule }
	local before = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	engine.execute("increment", { visual = false, seqadd = false, step = 1 })
	local after = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	expect.equality(before, after)
end

boundary_tests["cursor_in_middle_of_multi_digit_number"] = function()
	-- Oracle: cursor in middle of multi-digit match should maintain relative position
	-- "foo 123 bar" with cursor at col=5 (on second "2")
	-- After increment: "foo 124 bar", cursor should be at col=5 (on second "2" of new "124")
	local buf = create_test_buf({ "foo 123 bar" })
	vim.api.nvim_win_set_cursor(0, { 1, 5 })
	engine.execute("increment", { visual = false, seqadd = false, step = 1 })
	expect.equality(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "foo 124 bar")
	-- Oracle: cursor offset from match start was 1 (col 5 - match col 4)
	-- New text "124" has length 3, so offset 1 should be valid, cursor at col=5
	local cursor_after = vim.api.nvim_win_get_cursor(0)
	expect.equality(cursor_after[2], 5)
end

T["boundary"] = boundary_tests

return T
