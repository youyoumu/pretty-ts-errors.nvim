local M = {}
local api = vim.api

function M.log_to_file(msg)
	local log_file = "/tmp/nvim_plugin.log" -- Change this path as needed
	local file = io.open(log_file, "a") -- Open file in append mode
	if file then
		local formatted_msg
		if type(msg) == "table" then
			formatted_msg = vim.inspect(msg)
		else
			formatted_msg = tostring(msg)
		end
		file:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. formatted_msg .. "\n")
		file:close()
	else
		vim.api.nvim_echo({ { "Failed to open log file: " .. log_file, "ErrorMsg" } }, true, {})
	end
end

function M.update_buffer(buf, contents)
	if api.nvim_buf_is_valid(buf) then
		api.nvim_set_option_value("modifiable", true, { buf = buf })
		api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(contents, "\n"))
		api.nvim_set_option_value("modifiable", false, { buf = buf })
	end
end

function M.is_ts_source(source)
	return source == "tsserver" or source == "ts"
end

function M.is_windows()
	return vim.loop.os_uname().version:match("Windows") ~= nil
end

-- Normalize command for jobstart on Windows (.cmd support)
-- Accepts string or array of strings
function M.normalize_cmd(cmd)
	if type(cmd) == "string" then
		cmd = { cmd }
	end

	if M.is_windows() then
		local exe = cmd[1]

		if not exe:match("%.cmd$") and vim.fn.executable(exe .. ".cmd") == 1 then
			cmd[1] = exe .. ".cmd"
		end
	end

	return cmd
end

return M
