-- Unit tests for advanced scenarios: LSP enum, custom rules, rule composition
-- Tests less common but important features and integration patterns

local MiniTest = require("mini.test")
local expect = MiniTest.expect

local engine = require("mobius.engine")
local constant = require("mobius.rules.constant")

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
-- Custom Rules: Pattern-Based Helper
-- ============================================================================
local custom_rule_tests = MiniTest.new_set()

custom_rule_tests["pattern_helper_basic"] = function()
	local Rules = require("mobius.rules")
	local custom = Rules.pattern({
		id = "custom_number",
		pattern = "num_(%d+)",
		word = false,
		add = function(metadata, addend)
			local num = tonumber(metadata.text:match("%d+")) + addend
			return "num_" .. tostring(num)
		end,
		cyclic = false,
	})
	expect.equality(custom ~= nil, true)
	expect.equality(custom.id, "custom_number")
end

custom_rule_tests["custom_rule_creation"] = function()
	-- Test that pattern helper creates valid rule
	local custom = require("mobius.rules").pattern({
		id = "prefix_number",
		pattern = "item%d+",
		word = false,
		add = function(metadata, addend)
			local num = tonumber(metadata.text:match("%d+")) + addend
			return "item" .. tostring(num)
		end,
		cyclic = false,
	})

	-- Verify rule structure
	expect.equality(custom.id, "prefix_number")
	expect.equality(custom.priority, 50)
	expect.equality(type(custom.find), "function")
	expect.equality(type(custom.add), "function")
end

T["custom_rule"] = custom_rule_tests

-- ============================================================================
-- Rule Composition: Multiple Related Rules
-- ============================================================================
local composition_tests = MiniTest.new_set()

composition_tests["enum_basic_cycle"] = function()
	local keywords = constant({ elements = { "function", "const", "let" }, word = true })
	expect.equality(keywords.add(1, { text = "function" }), "const")
	expect.equality(keywords.add(1, { text = "const" }), "let")
	expect.equality(keywords.add(1, { text = "let" }), "function")
end

composition_tests["enum_grouped_variants"] = function()
	local casings = constant({
		elements = {
			{ "yes", "no" },
			{ "Yes", "No" },
			{ "YES", "NO" },
		},
	})
	-- Different groups should NOT mix
	expect.equality(casings.add(1, { text = "yes" }), "no")
	expect.equality(casings.add(-1, { text = "Yes" }), "No")
end

composition_tests["enum_large_list"] = function()
	local colors = constant({
		elements = { "red", "green", "blue", "yellow", "orange", "purple" },
		word = true,
	})
	expect.equality(colors.add(1, { text = "red" }), "green")
	expect.equality(colors.add(5, { text = "red" }), "purple") -- +5 steps
	expect.equality(colors.add(-1, { text = "red" }), "purple") -- Wrap backward
end

T["composition"] = composition_tests

-- ============================================================================
-- Buffer-Local Rule Override and Inheritance
-- ============================================================================
local buffer_override_tests = MiniTest.new_set()

buffer_override_tests["buffer_rules_inherit_true"] = function()
	vim.g.mobius_rules = {
		"mobius.rules.numeric.integer",
		"mobius.rules.constant.bool",
	}

	local buf = create_test_buf({ "42" })
	vim.b.mobius_rules = { true, "mobius.rules.constant.yes_no" } -- Inherit global + add yes_no

	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	engine.execute("increment", { visual = false, step = 1 })

	-- Should match integer (from inherited global rules)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	expect.equality(lines[1], "43")
end

buffer_override_tests["buffer_rules_no_inherit"] = function()
	vim.g.mobius_rules = { "mobius.rules.numeric.integer" }

	local buf = create_test_buf({ "yes" })
	vim.b.mobius_rules = { "mobius.rules.constant.yes_no" } -- No inherit

	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	engine.execute("increment", { visual = false, step = 1 })

	-- Should match yes_no (integer rule not available)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	expect.equality(lines[1], "no")

	-- Cleanup
	vim.b.mobius_rules = nil
end

buffer_override_tests["buffer_rules_priority_override"] = function()
	vim.g.mobius_rules = {
		require("mobius.rules.numeric.hex")({ priority = 50 }),
		require("mobius.rules.numeric.integer")({ priority = 60 }),
	}

	local buf = create_test_buf({ "0xFF" })
	-- Override with higher hex priority
	vim.b.mobius_rules = {
		require("mobius.rules.numeric.hex")({ priority = 70 }),
		require("mobius.rules.numeric.integer")({ priority = 50 }),
	}

	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	engine.execute("increment", { visual = false, step = 1 })

	-- Should match hex despite integer having high priority globally
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	expect.equality(lines[1], "0x100")

	vim.b.mobius_rules = nil
end

T["buffer_override"] = buffer_override_tests

-- ============================================================================
-- Rule Caching and Invalidation
-- ============================================================================
local caching_tests = MiniTest.new_set()

caching_tests["rule_cache_per_buffer"] = function()
	-- After first execute, rules should be cached
	local buf1 = create_test_buf({ "1" })
	vim.g.mobius_rules = { "mobius.rules.numeric.integer" }

	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	engine.execute("increment", { visual = false, step = 1 })

	local lines = vim.api.nvim_buf_get_lines(buf1, 0, -1, false)
	expect.equality(lines[1], "2")

	-- Cache should be per-buffer; different buffer should work independently
	local buf2 = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf2, 0, -1, false, { "5" })
	vim.api.nvim_set_current_buf(buf2)

	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	engine.execute("increment", { visual = false, step = 1 })

	local lines2 = vim.api.nvim_buf_get_lines(buf2, 0, -1, false)
	expect.equality(lines2[1], "6")
end

caching_tests["cache_clear_on_rule_change"] = function()
	local buf = create_test_buf({ "5" })
	vim.g.mobius_rules = { "mobius.rules.numeric.integer" }

	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	engine.execute("increment", { visual = false, step = 1 })
	expect.equality(vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1], "6")

	-- Change global rules
	vim.g.mobius_rules = { "mobius.rules.constant.bool" }
	-- Cache should be invalid; but buf still has "6" which is not a bool
	-- So next increment on "6" should fail to match
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "true" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	engine.execute("increment", { visual = false, step = 1 })

	expect.equality(vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1], "false")
end

T["caching"] = caching_tests

-- ============================================================================
-- Engine Options: Custom Rules via opts Parameter
-- ============================================================================
local engine_opts_tests = MiniTest.new_set()

engine_opts_tests["execute_with_custom_rules_opts"] = function()
	vim.g.mobius_rules = { "mobius.rules.numeric.integer" }

	local buf = create_test_buf({ "true" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })

	-- Override rules via opts
	engine.execute("increment", {
		visual = false,
		step = 1,
		rules = { "mobius.rules.constant.bool" },
	})

	-- Should match bool (from opts), not integer (from global)
	expect.equality(vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1], "false")
end

engine_opts_tests["execute_step_parameter"] = function()
	local buf = create_test_buf({ "5" })
	vim.g.mobius_rules = { "mobius.rules.numeric.integer" }
	vim.api.nvim_win_set_cursor(0, { 1, 0 })

	engine.execute("increment", { visual = false, step = 10 })
	expect.equality(vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1], "15")
end

T["engine_opts"] = engine_opts_tests

-- ============================================================================
-- String References vs Direct Modules
-- ============================================================================
local module_loading_tests = MiniTest.new_set()

module_loading_tests["string_reference_lazy_loads"] = function()
	-- Using string reference should lazy-load the module
	vim.g.mobius_rules = { "mobius.rules.numeric.integer" } -- String ref

	local buf = create_test_buf({ "7" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	engine.execute("increment", { visual = false, step = 1 })

	expect.equality(vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1], "8")
end

module_loading_tests["direct_module_reference"] = function()
	-- Direct module require should also work
	local integer_rule = require("mobius.rules.numeric.integer")
	vim.g.mobius_rules = { integer_rule }

	local buf = create_test_buf({ "7" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	engine.execute("increment", { visual = false, step = 1 })

	expect.equality(vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1], "8")
end

T["module_loading"] = module_loading_tests

-- ============================================================================
-- Complex Metadata Flow: Multi-Component Rules
-- ============================================================================
local metadata_flow_tests = MiniTest.new_set()

metadata_flow_tests["metadata_preservation_through_cycle"] = function()
	-- Ensure metadata round-trips correctly through find/add
	local rule = constant({ elements = { "alpha", "beta", "gamma" } })

	-- Simulate find result
	local fake_match = { text = "alpha", index = 1 }
	expect.equality(rule.add(1, fake_match), "beta")

	fake_match.text = "beta"
	expect.equality(rule.add(1, fake_match), "gamma")

	fake_match.text = "gamma"
	expect.equality(rule.add(1, fake_match), "alpha")
end

T["metadata_flow"] = metadata_flow_tests

-- ============================================================================
-- Direction and Sign Semantics
-- ============================================================================
local direction_tests = MiniTest.new_set()

direction_tests["increment_positive_step"] = function()
	local buf = create_test_buf({ "10" })
	vim.g.mobius_rules = { "mobius.rules.numeric.integer" }
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	engine.execute("increment", { step = 3 })
	expect.equality(vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1], "13")
end

direction_tests["decrement_negative_step"] = function()
	local buf = create_test_buf({ "10" })
	vim.g.mobius_rules = { "mobius.rules.numeric.integer" }
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	engine.execute("decrement", { step = 3 })
	expect.equality(vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1], "7")
end

T["direction"] = direction_tests

-- ============================================================================
-- No Match Scenarios: Graceful Degradation
-- ============================================================================
local no_match_tests = MiniTest.new_set()

no_match_tests["no_match_preserves_buffer"] = function()
	local buf = create_test_buf({ "foo bar baz" })
	vim.g.mobius_rules = { "mobius.rules.numeric.integer" }
	local before = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	engine.execute("increment", { step = 1 })

	local after = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	expect.equality(before, after)
end

no_match_tests["no_match_preserves_cursor"] = function()
	local buf = create_test_buf({ "foo bar" })
	vim.g.mobius_rules = { "mobius.rules.numeric.integer" }

	vim.api.nvim_win_set_cursor(0, { 1, 2 })
	engine.execute("increment", { step = 1 })

	local cursor = vim.api.nvim_win_get_cursor(0)
	expect.equality({ cursor[1], cursor[2] }, { 1, 2 })
end

T["no_match"] = no_match_tests

return T
