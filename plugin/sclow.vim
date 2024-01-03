" Maintainer: obcat <obcat@icloud.com>
" License:    MIT License

if exists('g:loaded_sclow')
  finish
endif

let g:sclow_auto_hide = get(g:, 'sclow_auto_hide', 0)

function s:register_autocmds() abort
  augroup sclow-autocmds
    autocmd!
    autocmd BufEnter,WinEnter * call sclow#create()
    autocmd CursorMoved,CursorMovedI,TextChanged,TextChangedI * call sclow#update()
    autocmd BufLeave,WinLeave * call sclow#delete()
  augroup END
endfunction

command! SclowEnable  call sclow#create() | call s:register_autocmds()
command! SclowDisable call sclow#delete() | autocmd! sclow-autocmds

call s:register_autocmds()


let g:loaded_sclow = 1
