local function setup_autocommands(add_xp_callback, pulse_send_callback)
    local group = vim.api.nvim_create_augroup("codestats_track", { clear = true })

    vim.api.nvim_create_autocmd({ "InsertCharPre", "TextChanged" }, {
        group = group,
        pattern = "*",
        callback = function()
            if add_xp_callback then
                add_xp_callback(vim.bo.filetype)
            end
        end,
    })

    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = group,
        pattern = "*",
        callback = function()
            if pulse_send_callback then
                pulse_send_callback()
            end
        end,
    })

    vim.api.nvim_create_autocmd({ "BufWrite", "BufLeave" }, {
        group = group,
        pattern = "*",
        callback = function()
            if pulse_send_callback then
                pulse_send_callback()
            end
        end,
    })
end

return {
    setup_autocommands = setup_autocommands,
}
