--[[
  Operator callbacks for g@ (normal-mode increment/decrement with dot-repeat).
  operatorfunc is set to v:lua._G.mobius_operator_callback so g@ can invoke
  us without require() in the operator context (avoids resolution issues in some setups).
]]

local M = {}

local last_step = 1

local function step_for_count(count)
	-- Dot-repeat replays "g@l" with no count prefix, so v:count1 is 1; reuse last step.
	if count == 1 and last_step > 1 then
		return last_step
	end
	last_step = count
	return count
end

--- Restore cursor to motion start ('[) so engine runs at the position where user pressed <C-a>.
--- g@ invokes us after motion "l", so the cursor has already moved one char right.
local function restore_cursor_to_motion_start()
	local buf = vim.api.nvim_get_current_buf()
	local mark = vim.api.nvim_buf_get_mark(buf, "[")
	-- (1,0)-indexed; (0,0) means mark not set
	if mark and mark[1] and mark[1] >= 1 then
		vim.api.nvim_win_set_cursor(0, { mark[1], mark[2] })
	end
end

---@param _ "line"|"char"|"block" motion type from g@ (unused; we use '[ for position)
function M.operator_increment(_)
	local direction = vim.g.mobius_operator_direction or "increment"
	local cumulative = vim.g.mobius_operator_cumulative or false
	local count = step_for_count(vim.v.count1)

	restore_cursor_to_motion_start()

	local ok, err = pcall(require("mobius.engine").execute, direction, {
		visual = false,
		seqadd = false,
		step = count,
		cumulative = cumulative,
	})
	if not ok then
		vim.notify("[mobius] " .. tostring(err), vim.log.levels.ERROR)
	end
end

---@param vmode "line"|"char"|"block"
function M.operator_decrement(vmode)
	vim.g.mobius_operator_direction = "decrement"
	return M.operator_increment(vmode)
end

--- Returns a keymap callback: set operator state, register callback in _G, set operatorfunc, feed g@l.
---@param direction "increment"|"decrement"
---@param cumulative boolean
---@return fun()
function M.operator_trigger(direction, cumulative)
	return function()
		vim.g.mobius_operator_direction = direction
		vim.g.mobius_operator_cumulative = cumulative
		_G.mobius_operator_callback = (direction == "decrement" and M.operator_decrement or M.operator_increment)
		vim.opt.operatorfunc = "v:lua._G.mobius_operator_callback"
		vim.api.nvim_feedkeys("g@l", "n", false)
	end
end

return M
