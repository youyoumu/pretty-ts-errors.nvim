local M = {}
local api = vim.api

-- for debugging
-- local function log_to_file(msg)
--   local log_file = "/tmp/nvim_plugin.log" -- Change this path as needed
--   local file = io.open(log_file, "a") -- Open file in append mode
--   if file then
--     file:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. msg .. "\n")
--     file:close()
--   else
--     vim.api.nvim_echo({ { "Failed to open log file: " .. log_file, "ErrorMsg" } }, true, {})
--   end
-- end

-- Configure plugin options with defaults
M.config = {
	executable = "pretty-ts-errors-markdown",
	float_opts = {
		border = "rounded",
		max_width = 80,
		max_height = 20,
	},
	auto_open = true,
}

local cache = {}

local function update_buffer(buf, contents)
	if api.nvim_buf_is_valid(buf) then
		api.nvim_set_option_value("modifiable", true, { buf = buf })
		api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(contents, "\n"))
		api.nvim_set_option_value("modifiable", false, { buf = buf })
	end
end

local function is_ts_source(source)
	return source == "tsserver" or source == "ts"
end

local function format_error_async(diagnostic, callback)
	if not is_ts_source(diagnostic.source) then
		callback(nil)
		return
	end

	-- Check cache first
	local cache_key = diagnostic.code .. diagnostic.message
	if cache[cache_key] then
		callback(cache[cache_key])
		return
	end

	local lsp_data = diagnostic.user_data.lsp

	-- Convert to JSON string and escape for shell
	local json_str = vim.fn.json_encode(lsp_data)
	local cmd = M.config.executable

	-- Use jobstart to run command asynchronously
	local job_id = vim.fn.jobstart(cmd, {
		on_stdout = function(_, data)
			if not data or #data < 1 or (data[1] == "" and #data == 1) then
				return
			end

			local result = table.concat(data, "\n")
			-- Cache the result
			cache[cache_key] = result
			callback(result)
		end,
		on_stderr = function(_, data)
			if not data or #data < 1 or (data[1] == "" and #data == 1) then
				return
			end

			local error_msg = table.concat(data, "\n")
			vim.schedule(function()
				vim.notify("Error formatting TypeScript error: " .. error_msg, vim.log.levels.ERROR)
			end)
			callback(nil)
		end,
		on_exit = function(_, code)
			if code ~= 0 then
				vim.schedule(function()
					vim.notify("Failed to format TypeScript error. Exit code: " .. code, vim.log.levels.ERROR)
				end)
				callback(nil)
			end
		end,
	})
	vim.fn.chansend(job_id, json_str)
	vim.fn.chanclose(job_id, "stdin")
end

local floating_win_visible = false
-- get errors under the cursor and show formatted error as floating window near the cursor
function M.show_formatted_error()
	-- If we already have a floating window open, don't create another one
	if floating_win_visible then
		return
	end

	-- Get diagnostics under cursor
	local current_line = api.nvim_win_get_cursor(0)[1] - 1
	local ts_diagnostics = {}
	for _, diagnostic in ipairs(vim.diagnostic.get(0, { lnum = current_line })) do
		if is_ts_source(diagnostic.source) then
			table.insert(ts_diagnostics, diagnostic)
		end
	end

	if #ts_diagnostics == 0 then
		vim.notify("No TypeScript errors under cursor", vim.log.levels.INFO)
		return
	end

	local main_buf = api.nvim_get_current_buf()
	local floating_buf = api.nvim_create_buf(false, true)
	api.nvim_set_option_value("filetype", "markdown", { buf = floating_buf })

	-- Add loading content to buffer
	api.nvim_buf_set_lines(floating_buf, 0, -1, false, {
		"# Loading TypeScript Error",
		"",
		"Please wait while the error is being formatted...",
	})

	-- Configure initial floating window
	local opts = {
		relative = "cursor",
		width = 50,
		height = 5,
		row = 1,
		col = 0,
		style = "minimal",
		border = M.config.float_opts.border,
	}

	-- Open floating window immediately with loading message
	local win = api.nvim_open_win(floating_buf, false, opts)
	floating_win_visible = true

	-- Add 'q' key mapping to close the window
	api.nvim_buf_set_keymap(floating_buf, "n", "q", "", {
		noremap = true,
		silent = true,
		callback = function()
			if api.nvim_win_is_valid(win) then
				api.nvim_win_close(win, true)
				floating_win_visible = false
			end
		end,
	})

	-- Set up an autocmd to reset `floating_win_visible` when the floating window is closed
	api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(win), -- Trigger when this specific window is closed
		callback = function()
			floating_win_visible = false
		end,
	})

	-- Set up autocmds to close window
	local group = api.nvim_create_augroup("PrettyTsErrorsClose", { clear = true })
	for _, buf in ipairs({ floating_buf, main_buf }) do
		api.nvim_create_autocmd({ "CursorMoved", "BufEnter", "InsertEnter" }, {
			buffer = buf,
			group = group,
			callback = function()
				local current_buf = api.nvim_get_current_buf()
				if buf == floating_buf and current_buf == floating_buf then
					return
				end
				if api.nvim_win_is_valid(win) then
					api.nvim_win_close(win, true)
					floating_win_visible = false
					api.nvim_del_augroup_by_id(group)
				end
			end,
		})
	end

	local contents = ""

	for _, diagnostic in ipairs(ts_diagnostics) do
		-- Format the diagnostic asynchronously
		format_error_async(diagnostic, function(formatted)
			-- This callback runs when the formatting is complete
			vim.schedule(function()
				-- Make sure window is still valid
				if not api.nvim_win_is_valid(win) or not api.nvim_buf_is_valid(floating_buf) then
					floating_win_visible = false
					return
				end

				if formatted then
					contents = contents .. formatted .. "\n\n"
				else
					contents = contents .. "Could not format this error.\n\n"
				end

				-- Update the buffer after each error is processed
				update_buffer(floating_buf, contents)

				-- Recalculate window size for formatted content
				local lines = vim.split(contents, "\n")
				local width = 0
				for _, line in ipairs(lines) do
					width = math.max(width, #line)
				end
				width = math.min(width, M.config.float_opts.max_width)
				local height = math.min(#lines, M.config.float_opts.max_height)

				-- Resize the window with new content
				api.nvim_win_set_config(win, {
					relative = "cursor",
					width = width,
					height = height,
					row = 1,
					col = 0,
				})
			end)
		end)
	end

	return win, floating_buf
end

local error_buf = nil -- Store the buffer reference
-- format all errors in the current buffer and open a full buffer window as split
function M.open_all_errors()
	-- Get all diagnostics in the current buffer
	local all_diagnostics = vim.diagnostic.get(0)
	local ts_diagnostics = {}

	for _, diagnostic in ipairs(all_diagnostics) do
		if is_ts_source(diagnostic.source) then
			table.insert(ts_diagnostics, diagnostic)
		end
	end

	if #ts_diagnostics == 0 then
		vim.notify("No TypeScript errors in this file", vim.log.levels.INFO)
		return
	end

	-- Create a new buffer
	local buf
	if error_buf then
		buf = error_buf
		api.nvim_buf_set_name(buf, "TypeScript-Errors")
	else
		buf = api.nvim_create_buf(true, true)
	end

	api.nvim_set_option_value("filetype", "markdown", { buf = buf })

	-- Set initial content
	api.nvim_buf_set_lines(buf, 0, -1, false, { "# TypeScript Errors", "", "Loading errors..." })

	-- Open the buffer in a new window
	api.nvim_command("vsplit")
	local win = api.nvim_get_current_win()
	api.nvim_win_set_buf(win, buf)

	-- Process diagnostics asynchronously
	local processed_count = 0
	local contents = "# TypeScript Errors\n"

	-- Process each diagnostic asynchronously
	for i, diagnostic in ipairs(ts_diagnostics) do
		format_error_async(diagnostic, function(formatted)
			vim.schedule(function()
				processed_count = processed_count + 1

				if formatted then
					local location =
						string.format("## Error %d (Line %d, Col %d)\n\n", i, diagnostic.lnum + 1, diagnostic.col + 1)
					contents = contents .. location
					contents = contents .. formatted .. "\n\n---\n"
				else
					local location =
						string.format("## Error %d (Line %d, Col %d)\n\n", i, diagnostic.lnum + 1, diagnostic.col + 1)
					contents = contents .. location
					contents = contents .. "Could not format this error.\n\n---\n"
				end

				-- Update the buffer after each error is processed
				update_buffer(buf, contents)

				-- When all diagnostics are processed, finalize the buffer
				if processed_count == #ts_diagnostics then
					vim.schedule(function()
						if api.nvim_buf_is_valid(buf) then
							-- Add key mappings for the buffer
							api.nvim_buf_set_keymap(buf, "n", "q", ":bdelete<CR>", { noremap = true, silent = true })
						end
					end)
				end
			end)
		end)
	end

	return buf
end

function M.enable_auto_open()
	local group = api.nvim_create_augroup("PrettyTsErrorsAuto", { clear = true })
	api.nvim_create_autocmd("CursorHold", {
		pattern = { "*.ts", "*.tsx", "*.js", "*.jsx" },
		group = group,
		callback = function()
			local line = api.nvim_win_get_cursor(0)[1] - 1
			local has_ts_error = false

			for _, diagnostic in ipairs(vim.diagnostic.get(0, { lnum = line })) do
				if is_ts_source(diagnostic.source) then
					has_ts_error = true
					break
				end
			end

			if has_ts_error then
				M.show_formatted_error()
			end
		end,
	})
end

function M.toggle_auto_open()
	-- Toggle the auto_open setting
	M.config.auto_open = not M.config.auto_open

	-- Clear existing autocommand group if it exists
	api.nvim_create_augroup("PrettyTsErrorsAuto", { clear = true })

	-- If auto_open is now enabled, recreate the autocommands
	if M.config.auto_open then
		M.enable_auto_open()
		vim.notify("TypeScript error auto-display on hover: Enabled", vim.log.levels.INFO)
	else
		vim.notify("TypeScript error auto-display on hover: Disabled", vim.log.levels.INFO)
	end
end

-- Setup function to initialize the plugin
function M.setup(opts)
	-- Merge user options with defaults
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	api.nvim_create_user_command("PrettyTsError", function()
		M.show_formatted_error()
	end, {})

	api.nvim_create_user_command("PrettyTsErrors", function()
		M.open_all_errors()
	end, {})

	api.nvim_create_user_command("PrettyTsToggleAuto", function()
		M.toggle_auto_open()
	end, {})

	if M.config.auto_open then
		M.enable_auto_open()
	end
end

return M
