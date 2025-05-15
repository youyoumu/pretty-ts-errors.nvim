local M = {}

M.config = {
	executable = "pretty-ts-errors-markdown",
	float_opts = {
		border = "rounded",
		max_width = 80,
		max_height = 20,
	},
	auto_open = true,
}

-- Merge user options with defaults
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

function M.get()
	return M.config
end

return M
