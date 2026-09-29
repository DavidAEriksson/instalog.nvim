vim.api.nvim_create_user_command('InstalogInsert', function()
  require('instalog').insert_log()
end, {})
