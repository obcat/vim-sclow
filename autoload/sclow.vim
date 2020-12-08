" Maintainer: obcat <obcat@icloud.com>
" License:    MIT License


" SYAZAI {{{
function! s:sorry() abort "{{{
  let fmt_fmtchanged   = 'Sorry, the "%s" option''s format has been changed.'
  let fmt_seehelp      = 'Please see `:h %s`.'
  let fmt_notsupported = 'Sorry, the "%s" option is no longer supported.'
  let fmt_renamed       = 'Sorry, "%s" is renamed to "%s".'

  let name = 'g:sclow_block_filetypes'
  if exists(name) && type({name}) == v:t_string
    let msg  = printf(fmt_fmtchanged, name)
    let msg .= "\<Space>" . printf(fmt_seehelp, name)
    call s:echoerr(msg)
    unlet {name}
  endif

  let name = 'g:sclow_block_bufnames'
  if exists(name)
    let msg = printf(fmt_notsupported, name)
    call s:echoerr(msg)
  endif

  let name = 'g:sclow_block_buftypes'
  if exists(name) && type({name}) == v:t_string
    let msg  = printf(fmt_fmtchanged, name)
    let msg .= "\<Space>" . printf(fmt_seehelp, name)
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


call s:sorry()
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
  let s:sbar_basic_options = #{
    \ pos: 'topright',
    \ zindex: s:sbar_zindex,
    \ highlight: 'SclowSbar',
    \ callback: 's:unlet_sbar_id',
    \}
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

  let [line, col] = s:get_basepos()
  let winheight = winheight(0)
  let lnums = s:get_lnums()
  let options = extend(s:sbar_basic_options, #{
    \ line: line,
    \ col:  col,
    \ mask: s:get_masks(winheight, lnums),
    \ })

  " Create scrollbar
  let s:sbar_id = popup_create([s:sbar_text]->repeat(winheight), options)
  let s:savelnums = lnums
endfunction "}}}


" This function is called on CursorMoved, CursorMovedI, and CursorHold
function! sclow#update() abort "{{{
  if !s:sbar_exists()
    return
  endif

  let pos = popup_getpos(s:sbar_id)
  let [line, col] = s:get_basepos()
  if [pos.line, pos.col] != [line, col]
    call s:move_base(line, col)
  endif

  let baseheight = winheight(s:sbar_id)
  let winheight  = winheight(0)
  if baseheight != winheight
    call s:update_baseheight(winheight)
  endif

  let lnums = s:get_lnums()
  if lnums != s:savelnums
    call s:update_masks(winheight, lnums)
  endif
  let s:savelnums = lnums
endfunction "}}}


" This function is called on BufLeave and WinLeave
function! sclow#delete() abort "{{{
  " Avoid E994 (cf. https://github.com/obcat/vim-hitspop/issues/5)
  if win_gettype() == 'popup'
    return
  endif

  if s:sbar_exists()
    " Delete scrollbar
    call popup_close(s:sbar_id)
  endif
endfunction "}}}


function! s:move_base(line, col) abort "{{{
  call popup_move(s:sbar_id, #{line: a:line, col: a:col})
endfunction "}}}


function! s:update_baseheight(height) abort "{{{
  call popup_settext(s:sbar_id, [s:sbar_text]->repeat(a:height))
endfunction "}}}


function! s:update_masks(winheight, lnums) abort "{{{
  call popup_setoptions(s:sbar_id, #{
   \ mask: s:get_masks(a:winheight, a:lnums),
   \ })
endfunction "}}}


" Return the screen position at which topright corner of base of scrollbar
" should be located.
function! s:get_basepos() abort "{{{
  let [line, col] = win_screenpos(0)
  let col += winwidth(0) - s:sbar_right_offset - 1
  return [line, col]
endfunction "}}}


function! s:get_lnums() abort "{{{
  return #{w0: line('w0'), wS: line('w$'), S: line('$')}
endfunction "}}}


function! s:is_blocked() abort "{{{
  return index(s:block_filetypes, &filetype) >= 0
    \ || index(s:block_buftypes,  &buftype)  >= 0
endfunction "}}}


function! s:sbar_exists() abort "{{{
  return exists('s:sbar_id')
endfunction "}}}


function! s:unlet_sbar_id(id, result) abort "{{{
  unlet s:sbar_id
endfunction "}}}


" Return popup masks. See `:h |popup-mask|`.
" +--------------------+
" |                    | <--+               <---+
" |                    |    | Mask top (ptop)   |
" |                    | <--+                   |
" |                   || <--+                   |
" |                   ||    | Gripper (height)  | Base (total)
" |       window      || <--+                   |
" |                    | <--+                   |
" |                    |    |                   |
" |                    |    | Mask bot (pbot)   |
" |                    |    |                   |
" |                    | <--+               <---+
" +--------------------+
" NOTE: ptop and pbot stand for padding top and padding bottom respectively.
"
" Requirements:
"   * Gripper length is not 0.
"   * Gripper length is constant.
"   * Padding top is not 0 if buffer's first line is not in the window.
"   * Padding bottom is not 0 if buffer's last line is not in the window.
function! s:get_masks(winheight, lnums) abort "{{{
  let PTOP   = a:lnums.w0 - 1          " = line('w0') - 1
  let HEIGHT = a:winheight             " = winheight(0)
  let PBOT   = a:lnums.S - a:lnums.wS  " = line('$') - line('w$')
  let total = HEIGHT

  if HEIGHT <= 2
    " Cannot meet all requirements. Mask all.
    return [s:mask(total, 'top')]
  endif

  if PTOP && PBOT "{{{
    let TOTAL = PTOP + HEIGHT + PBOT
    let scale = 1.0 * total / TOTAL
    let ptop   = float2nr(PTOP * scale)
    let height = float2nr(ceil(HEIGHT * scale))

    if !ptop
      let ptop = 1
      if ptop + height == total + 1
        let height -= 1
      endif
    endif
    if ptop + height == total
      let ptop -= 1
    endif

    let pbot = total - (ptop + height)

    return [
      \ s:mask(ptop, 'top'),
      \ s:mask(pbot, 'bot'),
      \ ]
  endif "}}}


  if PBOT "{{{
    let TOTAL = HEIGHT + PBOT
    let scale = 1.0 * total / TOTAL
    let ptop   = float2nr(PTOP * scale)
    let height = float2nr(ceil(HEIGHT * scale))
    let pbot   = total - (ptop + height)

    if !pbot
      let pbot = 1
    endif

    return [s:mask(pbot, 'bot')]
  endif "}}}


  if PTOP "{{{
    let TOTAL = PTOP + s:bufheight()
    let scale = 1.0 * total / TOTAL
    let ptop = float2nr(PTOP * scale)

    if !ptop
      let ptop = 1
    endif

    return [s:mask(ptop, 'top')]
  endif "}}}


  return s:hide_full_length
    \ ? [s:mask(total, 'top')]
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
" |.........           |    | Returns this height
" |....                |    |
" |.............       | <--+
" |~                   | <--+
" |~                   |    |
" |~                   |    | End of buffer
" |~                   |    |
" |~                   |    |
" |~                   | <--+
" +--------------------+
" NOTE: `line('w$') - line('w0') + 1` is not equal to this height when there are
" foldings or wrapped lines in the window.
function! s:bufheight() abort "{{{
  let savecurpos = getcurpos()
  keepjumps normal! G
  let line = winline()
  keepjumps call setpos('.', savecurpos)
  return line
endfunction "}}}


" API function to get scrollbar id.
function! sclow#getsbarid() abort "{{{
  return get(s:, 'sbar_id', '')
endfunction "}}}
