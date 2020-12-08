" Maintainer: obcat <obcat@icloud.com>
" License:    MIT License


" SYAZAI {{{
function! s:catch_obsolete_and_apologize() abort "{{{
  let fmt_fmt_changed   = 'Sorry, the "%s" option''s format has been changed.'
  let fmt_see_help      = 'Please see `:h %s`.'
  let fmt_not_supported = 'Sorry, the "%s" option is no longer supported.'
  let fmt_renamed       = 'Sorry, "%s" is renamed to "%s".'

  let name = 'g:sclow_block_filetypes'
  if exists(name) && type({name}) == v:t_string
    let msg  = printf(fmt_fmt_changed, name)
    let msg .= "\<Space>" . printf(fmt_see_help, name)
    call s:echoerr(msg)
    unlet {name}
  endif

  let name = 'g:sclow_block_bufnames'
  if exists(name)
    let msg = printf(fmt_not_supported, name)
    call s:echoerr(msg)
  endif

  let name = 'g:sclow_block_buftypes'
  if exists(name) && type({name}) == v:t_string
    let msg  = printf(fmt_fmt_changed, name)
    let msg .= "\<Space>" . printf(fmt_see_help, name)
    call s:echoerr(msg)
    unlet {name}
  endif

  let name     = 'g:sclow_show_full_length_sbar'
  let new_name = 'g:sclow_hide_full_length'
  if exists(name)
    let msg = printf(fmt_renamed, name, new_name)
    call s:echoerr(msg)
  endif
endfunction "}}}


function! s:echoerr(msg) abort "{{{
  echohl WarningMsg
  echomsg '[sclow]' a:msg
  echohl None
endfunction "}}}


call s:catch_obsolete_and_apologize()
"}}}


function! s:init() "{{{
  let s:block_filetypes = get(g:, 'sclow_block_filetypes', [])
  let s:block_buftypes  = get(g:, 'sclow_block_buftypes', [])
  let s:sbar_text         = get(g:, 'sclow_sbar_text', "\<Space>")
  let s:sbar_right_offset = get(g:, 'sclow_sbar_right_offset', 0)
  let s:sbar_zindex       = get(g:, 'sclow_sbar_zindex', 20)
  let s:hide_full_length = get(g:, 'sclow_hide_full_length', 0)
  hi default link SclowSbar Pmenu

  let s:sbar_width = strwidth(s:sbar_text)
endfunction "}}}


call s:init()


" This function is called on BufEnter and WinEnter
function! sclow#create() abort "{{{
  if get(b:, 'sclow_is_blocked')
    return
  endif

  if s:is_blocked()
    let b:sclow_is_blocked = 1
    return
  endif

  if s:sbar_exists()
    return
  endif

  call s:create_sbar()

  call s:save_info()
endfunction "}}}


" This function is called on CursorMoved, CursorMovedI, and CursorHold
function! sclow#update() abort "{{{
  if !s:sbar_exists()
    return
  endif

  call s:update_sbar()

  call s:save_info()
endfunction "}}}


" This function is called on BufLeave and WinLeave
function! sclow#delete() abort "{{{
  " Avoid E994 (cf. https://github.com/obcat/vim-hitspop/issues/5)
  if win_gettype() == 'popup'
    return
  endif

  if s:sbar_exists()
    call s:delete_sbar()
  endif
endfunction "}}}


function! s:create_sbar() abort "{{{
  let [line, col] = win_screenpos(0)
  let col += winwidth(0) - s:sbar_right_offset - 1

  let w:sclow_sbar_id = popup_create(repeat([s:sbar_text], winheight(0)), #{
    \ pos: 'topright',
    \ line: line,
    \ col:  col,
    \ mask: s:get_masks(),
    \ zindex: s:sbar_zindex,
    \ highlight: 'SclowSbar',
    \ callback: 's:unlet_sbar_id',
    \})
endfunction "}}}


function! s:update_sbar() abort "{{{
  let pos = popup_getpos(w:sclow_sbar_id)
  let [line, col] = win_screenpos(0)
  let col += winwidth(0) - s:sbar_right_offset - 1

  if [pos.line, pos.col] != [line, col]
    call s:move_sbar_base(line, col)
  endif

  let win_height  = winheight(0)
  let base_height = winheight(w:sclow_sbar_id)

  if base_height != win_height
    call s:update_base_height(win_height)
  endif

  if s:scrolled()
    call s:update_sbar_masks()
  endif
endfunction "}}}


function! s:delete_sbar() abort "{{{
  call popup_close(w:sclow_sbar_id)
endfunction "}}}


function! s:move_sbar_base(line, col) abort "{{{
  call popup_move(w:sclow_sbar_id, #{line: a:line, col: a:col})
endfunction "}}}


function! s:update_sbar_masks() abort "{{{
  call popup_setoptions(w:sclow_sbar_id, #{
    \ mask: s:get_masks(),
    \ })
endfunction "}}}


function! s:update_base_height(height) abort "{{{
  call popup_settext(w:sclow_sbar_id, repeat([s:sbar_text], a:height))
endfunction "}}}


function! s:is_blocked() abort "{{{
  return index(s:block_filetypes, &filetype) >= 0
    \ || index(s:block_buftypes,  &buftype)  >= 0
endfunction "}}}


function! s:sbar_exists() abort "{{{
  return exists('w:sclow_sbar_id')
endfunction "}}}


function! s:unlet_sbar_id(id, result) abort "{{{
  unlet w:sclow_sbar_id
endfunction "}}}


function! s:scrolled() abort "{{{
  return w:sclow_saved_lines != [line('w0'), line('w$')]
endfunction "}}}


function! s:save_info() abort "{{{
  let w:sclow_saved_lines = [line('w0'), line('w$')]
endfunction "}}}


" Return popup masks. See `:h |popup-mask|`.
" +--------------------+
" |                    | <--+                   <---+
" |                    |    | mask top (sbar_ptop)  |
" |                    | <--+                       |
" |                   || <--+                       |
" |                   ||    | gripper (sbar_height) | base (sbar_total)
" |       window      || <--+                       |
" |                    | <--+                       |
" |                    |    |                       |
" |                    |    | mask bot (sbar_pbot)  |
" |                    |    |                       |
" |                    | <--+                   <---+
" +--------------------+
" NOTE: ptop and pbot stand for padding top and padding bottom respectively.
"
" Requirements:
"   * Gripper length is not 0.
"   * Gripper length is constant.
"   * Padding top is not 0 if buffer's first line is not in the window.
"   * Padding bottom is not 0 if buffer's last line is not in the window.
function! s:get_masks() abort "{{{
  let ptop   = line('w0') - 1
  let height = winheight(0)
  let pbot   = line('$') - line('w$')
  let sbar_total = height

  if sbar_total <= 2
    " Cannot meet all requirements. Mask all.
    return [s:mask(sbar_total, 'top')]
  endif

  if ptop && pbot "{{{
    let total = ptop + height + pbot
    let scale = 1.0 * sbar_total / total
    let sbar_ptop   = float2nr(ptop * scale)
    let sbar_height = float2nr(ceil(height * scale))

    if !sbar_ptop
      let sbar_ptop = 1

      if sbar_ptop + sbar_height == sbar_total + 1
        let sbar_height -= 1
      endif
    endif

    if sbar_ptop + sbar_height == sbar_total
      let sbar_ptop -= 1
    endif

    let sbar_pbot = sbar_total - (sbar_ptop + sbar_height)

    return [
      \ s:mask(sbar_ptop, 'top'),
      \ s:mask(sbar_pbot, 'bot'),
      \ ]
  endif "}}}


  if pbot "{{{
    let total = height + pbot
    let scale = 1.0 * sbar_total / total
    let sbar_ptop   = float2nr(ptop * scale)
    let sbar_height = float2nr(ceil(height * scale))
    let sbar_pbot   = sbar_total - (sbar_ptop + sbar_height)

    if !sbar_pbot
      let sbar_pbot = 1
    endif

    return [s:mask(sbar_pbot, 'bot')]
  endif "}}}


  if ptop "{{{
    let total = ptop + s:bufheight()
    let scale = 1.0 * sbar_total / total
    let sbar_ptop = float2nr(ptop * scale)

    if !sbar_ptop
      let sbar_ptop = 1
    endif

    return [s:mask(sbar_ptop, 'top')]
  endif "}}}


  return s:hide_full_length
    \ ? [s:mask(sbar_total, 'top')]
    \ : []
endfunction "}}}


" Return formatted popup mask.
function! s:mask(height, pos) abort "{{{
  return a:pos == 'top'
    \ ? [1, s:sbar_width,  1,  a:height]
    \ : [1, s:sbar_width, -a:height, -1]
endfunction "}}}


" If buffer's last line is in the current window, this function returns height
" of the buffer in the window.
" +--------------------+
" |.....               | <--+
" |...                 |    |
" |.........           |    | returns this height
" |....                |    |
" |.............       | <--+
" |~                   | <--+
" |~                   |    |
" |~                   |    | end of buffer
" |~                   |    |
" |~                   |    |
" |~                   | <--+
" +--------------------+
" NOTE: `line('w$') - line('w0') + 1` is not equal to this height when there are
" foldings or wrapped lines in the window.
function! s:bufheight() abort "{{{
  let save_curpos = getcurpos()
  keepjumps normal! G
  let line = winline()
  keepjumps call setpos('.', save_curpos)
  return line
endfunction "}}}
