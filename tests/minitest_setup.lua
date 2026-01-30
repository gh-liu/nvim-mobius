-- Setup file for mini.test (native API only, no busted describe/it)
-- Usage: nvim --headless -u tests/minitest_setup.lua -c "lua MiniTest.run()" -c "qa"

local plugin_path = vim.fn.fnamemodify(vim.fn.expand("<sfile>"), ":p:h:h")
local deps_mini = plugin_path .. "/.deps/mini.nvim"
vim.opt.runtimepath:prepend(deps_mini)
vim.opt.runtimepath:prepend(plugin_path)

local MiniTest = require("mini.test")

MiniTest.setup({
	collect = {
		emulate_busted = false,
		find_files = function()
			-- Auto-discover all test_*.lua files in tests directory and subdirectories
			local tests_dir = plugin_path .. "/tests"
			local test_files = {}
			
			local function scan_dir(dir)
				local entries = vim.fn.readdir(dir)
				for _, name in ipairs(entries) do
					if name:match("^test_.*%.lua$") then
						table.insert(test_files, dir .. "/" .. name)
					elseif vim.fn.isdirectory(dir .. "/" .. name) == 1 and not name:match("^%.") then
						scan_dir(dir .. "/" .. name)
					end
				end
			end
			
			scan_dir(tests_dir)
			table.sort(test_files)
			return test_files
		end,
		filter_cases = function(case)
			return true
		end,
	},
	execute = {
		hooks = {
			pre_once = function()
				print("Starting nvim-mobius tests...")
			end,
			post_once = function()
				print("Tests completed!")
			end,
		},
		reporter = MiniTest.gen_reporter.stdout(),
		stop_on_error = false,
	},
	script_path = "scripts/minitest.lua",
	silent = false,
})

return MiniTest
