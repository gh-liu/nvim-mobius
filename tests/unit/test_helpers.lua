-- Unit tests for shared helper modules: match_scorer, word_boundary, rule_result

local MiniTest = require("mini.test")
local expect = MiniTest.expect

local match_scorer = require("mobius.engine.match_scorer")
local word_boundary = require("mobius.engine.word_boundary")
local rule_result = require("mobius.engine.rule_result")

local T = MiniTest.new_set({
	hooks = {
		pre_case = function() end,
		post_case = function() end,
	},
})

-- ============================================================================
-- Match Scorer
-- ============================================================================
local scorer_tests = MiniTest.new_set()

scorer_tests["calculate_score_cursor_at_match"] = function()
	-- Match at cursor should have highest score
	-- match_start=5, match_end=10 (1-indexed), cursor_col=6 (0-indexed), match_length=6
	local score1 = match_scorer.calculate_score(5, 10, 6, 6) -- cursor in match [5..10]
	local score2 = match_scorer.calculate_score(5, 10, 0, 6) -- cursor before match
	expect.equality(score1 > score2, true)
end

scorer_tests["calculate_score_proximity"] = function()
	-- Closer match should score higher (same category)
	-- Both after cursor, but different distances
	local score1 = match_scorer.calculate_score(6, 10, 0, 5) -- close after cursor
	local score2 = match_scorer.calculate_score(20, 25, 0, 6) -- far after cursor
	expect.equality(score1 > score2, true)
end

scorer_tests["calculate_score_length"] = function()
	-- Longer match should score higher within same category
	local score1 = match_scorer.calculate_score(5, 10, 0, 6) -- 6 chars, before cursor
	local score2 = match_scorer.calculate_score(5, 8, 0, 4) -- 4 chars, before cursor
	expect.equality(score1 > score2, true)
end

scorer_tests["find_all_matches_basic"] = function()
	local line = "foo 123 bar 456 baz"
	local matches = match_scorer.find_all_matches(line, "%d+")
	expect.equality(#matches, 2)
	expect.equality(matches[1][1], 5) -- "123" starts at 1-indexed position 5
	expect.equality(matches[2][1], 13) -- "456" starts at 1-indexed position 13
end

scorer_tests["find_best_match_cursor_in_match"] = function()
	local line = "foo 123 bar"
	local matches = match_scorer.find_all_matches(line, "%d+")
	-- metadata_extractor should extract text from the line and match
	local metadata_extractor = function(text, match)
		return { text = text }
	end
	local best = match_scorer.find_best_match(line, matches, 5, metadata_extractor)
	expect.equality(best ~= nil, true)
	expect.equality(best.metadata.text, "123")
end

T["match_scorer"] = scorer_tests

-- ============================================================================
-- Word Boundary
-- ============================================================================
local boundary_tests = MiniTest.new_set()

boundary_tests["find_word_matches_basic"] = function()
	local line = "true and false"
	local matches = word_boundary.find_word_matches(line, "true")
	expect.equality(#matches, 1)
end

boundary_tests["find_word_matches_not_substring"] = function()
	local line = "trueValue"
	local matches = word_boundary.find_word_matches(line, "true")
	expect.equality(#matches, 0)
end

boundary_tests["find_pattern_matches_basic"] = function()
	local line = "foo 123 bar 456"
	local matches = word_boundary.find_pattern_matches(line, "%d+")
	expect.equality(#matches, 2)
end

boundary_tests["find_frontier_matches_word"] = function()
	local line = "let x = true"
	local pattern = "%f[%w]true%f[^%w]"
	local matches = word_boundary.find_frontier_matches(line, pattern)
	expect.equality(#matches >= 1, true)
end

T["word_boundary"] = boundary_tests

-- ============================================================================
-- Rule Result
-- ============================================================================
local result_tests = MiniTest.new_set()

result_tests["match_converts_1indexed_to_0indexed"] = function()
	local match = rule_result.match(5, 8, "text", { foo = "bar" })
	expect.equality(match.col, 4) -- 5 - 1
	expect.equality(match.end_col, 7) -- 8 - 1
	expect.equality(match.metadata.text, "text")
	expect.equality(match.metadata.foo, "bar")
end

result_tests["match_includes_metadata"] = function()
	local match = rule_result.match(1, 3, "xyz", { value = 42, component = "test" })
	expect.equality(match.metadata.text, "xyz")
	expect.equality(match.metadata.value, 42)
	expect.equality(match.metadata.component, "test")
end

result_tests["validate_accepts_valid_result"] = function()
	local result = { col = 0, end_col = 5, metadata = { text = "hello" } }
	local ok, err = rule_result.validate(result)
	expect.equality(ok, true)
	expect.equality(err, nil)
end

result_tests["validate_rejects_missing_metadata_text"] = function()
	local result = { col = 0, end_col = 5, metadata = {} }
	local ok, err = rule_result.validate(result)
	expect.equality(ok, false)
	expect.equality(err ~= nil, true)
end

T["rule_result"] = result_tests

return T
