local M = {}

-- Default configuration options
local default_opts = {
	width = 40, -- Width of the vertical split
	buf_name = "fixedspace", -- Name of the scratch buffer
	winfixwidth = true, -- Prevent resizing the window
	modifiable = false, -- Make buffer read-only
	buftype = "nofile", -- Make it a scratch buffer
	bufhidden = "wipe", -- Auto-remove buffer when closed
	swapfile = false, -- No swap file
	enterable = false, -- Prevent entering the window
}

-- User-defined options
local opts = {}

-- Setup function for user configuration
function M.setup(user_opts)
	opts = vim.tbl_deep_extend("force", default_opts, user_opts or {})
end

-- Create a real vertical split with a scratch buffer
function M.create_fixedspace()
	-- Check if the buffer already exists
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == opts.buf_name then
			return buf
		end
	end

	-- Store current window to move cursor back later
	local current_win = vim.api.nvim_get_current_win()

	-- Open a new vertical split
	vim.cmd("vnew")

	-- Get the window ID of the newly created split
	local win_id = vim.api.nvim_get_current_win()

	-- Move the split to the rightmost position
	vim.cmd("wincmd L")

	-- Resize the split width correctly
	vim.api.nvim_win_set_width(win_id, opts.width)

	-- Get the buffer ID
	local buf = vim.api.nvim_get_current_buf()

	-- Set buffer name
	vim.api.nvim_buf_set_name(buf, opts.buf_name)

	-- Apply buffer options
	vim.bo[buf].buftype = opts.buftype
	vim.bo[buf].bufhidden = opts.bufhidden
	vim.bo[buf].swapfile = opts.swapfile
	vim.bo[buf].modifiable = opts.modifiable

	-- Prevent resizing of the window
	if opts.winfixwidth then
		vim.wo[win_id].winfixwidth = true
	end

	-- Prevent entering the window (move back immediately if entered)
	if not opts.enterable then
		vim.api.nvim_create_autocmd("WinEnter", {
			buffer = buf,
			callback = function()
				--if vim.api.nvim_get_current_win() == win_id then
				--	vim.api.nvim_set_current_win(current_win)
				--end
				-- Ensure the previous window is still valid
				if vim.api.nvim_win_is_valid(current_win) then
					vim.api.nvim_set_current_win(current_win)
				end
			end,
		})
	end

	-- Set autocmd to clean up when closed
	vim.api.nvim_create_autocmd("WinClosed", {
		callback = function(event)
			local closed_win_id = tonumber(event.match)
			-- Check if the buffer is still valid before deleting
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == opts.buf_name then
					-- Ensure the buffer is not being displayed in another window
					local buf_still_open = false
					for _, win in ipairs(vim.api.nvim_list_wins()) do
						if vim.api.nvim_win_get_buf(win) == buf then
							buf_still_open = true
							break
						end
					end
					-- If no other windows show the buffer, delete it
					if not buf_still_open then
						vim.api.nvim_buf_delete(buf, { force = true })
					end
					return
				end
			end
		end,
	})

	-- Move cursor back to the previous window
	vim.api.nvim_set_current_win(current_win)

	return buf
end
-- Enable function to ensure the fixed space buffer is open
function M.enable()
	-- Check if a buffer named "fixedspace" already exists
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == opts.buf_name then
			-- Ensure it's displayed in a window
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				if vim.api.nvim_win_get_buf(win) == buf then
					return -- The buffer is already open in a window
				end
			end
			-- If buffer exists but not displayed, create a new window for it
			vim.cmd("vnew") -- Open a vertical split
			vim.api.nvim_set_current_buf(buf)
			vim.cmd("wincmd L") -- Move to the rightmost position
			vim.api.nvim_win_set_width(0, opts.width)
			return
		end
	end

	-- If the buffer doesn't exist, create it
	M.create_fixedspace()
end

-- Disable function to close and remove the fixed space buffer
function M.disable()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == opts.buf_name then
			-- Check if it's displayed in any window and close it
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				if vim.api.nvim_win_get_buf(win) == buf then
					vim.api.nvim_win_close(win, true)
				end
			end
			-- Delete the buffer
			vim.api.nvim_buf_delete(buf, { force = true })
			return
		end
	end
end
-- Toggle function to open/close the buffer
function M.toggle()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == opts.buf_name then
			vim.api.nvim_win_close(win, true)
			return
		end
	end
	M.create_fixedspace()
end

return M
