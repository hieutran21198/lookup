local M = {}

M.get_filetype = function(buf)
  local selected_buf = buf
  if buf == nil then selected_buf = vim.api.nvim_get_current_buf() end

  return vim.api.nvim_buf_get_options(selected_buf, "filetype")
end

return M
