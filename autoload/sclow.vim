" Maintainer: obcat <obcat@icloud.com>
" License:    MIT License


function s:init() "{{{
  let g:sclow_block_filetypes = get(g:, 'sclow_block_filetypes', [])
  let g:sclow_block_buftypes  = get(g:, 'sclow_block_buftypes', [])
  let g:sclow_sbar_text         = get(g:, 'sclow_sbar_text', "\<Space>")
  let g:sclow_sbar_right_offset = get(g:, 'sclow_sbar_right_offset', 0)
  let g:sclow_sbar_zindex       = get(g:, 'sclow_sbar_zindex', 20)
  let g:sclow_hide_full_length = get(g:, 'sclow_hide_full_length', 0)
  let s:HLGROUP = 'SclowSbar'
  exe 'hi default link' s:HLGROUP 'Pmenu'

  let s:SBAR_STATIC_OPTIONS = #{
    \ pos: 'topright',
    \ highlight: s:HLGROUP,
    \ callback: {-> s:unlet_sbar_id()},
    \}
endfunction "}}}


call s:init()


" This function is called on BufEnter and WinEnter
function sclow#create() abort "{{{
  if s:is_blocked() || s:sbar_exists()
    return
  endif

  let [line, col] = s:get_basepos()
  let winheight = winheight(0)
  let bufheights = s:get_bufheights()
  let options = deepcopy(s:SBAR_STATIC_OPTIONS)->extend(#{
    \ line: line,
    \ col:  col,
    \ zindex: g:sclow_sbar_zindex,
    \ mask: s:get_masks(winheight, bufheights),
    \ })

  " Create scrollbar
  let s:sbar_id = popup_create([g:sclow_sbar_text]->repeat(winheight), options)
  let s:savebufheights = bufheights
endfunction "}}}


" This function is called on CursorMoved, CursorMovedI, and CursorHold
function sclow#update() abort "{{{
  if !s:sbar_exists()
    return
  endif

  let opts = popup_getoptions(s:sbar_id)
  let [line, col] = s:get_basepos()
  if [opts.line, opts.col] != [line, col]
    call s:move_base(line, col)
  endif

  let baseheight = winheight(s:sbar_id)
  let winheight  = winheight(0)
  if baseheight != winheight
    call s:update_baseheight(winheight)
  endif

  let bufheights = s:get_bufheights()
  if bufheights != s:savebufheights
    call s:update_masks(winheight, bufheights)
  endif
  let s:savebufheights = bufheights
endfunction "}}}


" This function is called on BufLeave and WinLeave
function sclow#delete() abort "{{{
  " Avoid E994 (cf. https://github.com/obcat/vim-hitspop/issues/5)
  if win_gettype() is# 'popup'
    return
  endif

  if s:sbar_exists()
    " Delete scrollbar
    call popup_close(s:sbar_id)
  endif
endfunction "}}}


function s:move_base(line, col) abort "{{{
  call popup_move(s:sbar_id, #{line: a:line, col: a:col})
endfunction "}}}


function s:update_baseheight(height) abort "{{{
  call popup_settext(s:sbar_id, [g:sclow_sbar_text]->repeat(a:height))
endfunction "}}}


function s:update_masks(winheight, bufheights) abort "{{{
  call popup_setoptions(s:sbar_id, #{mask: s:get_masks(a:winheight, a:bufheights)})
endfunction "}}}


" Return the screen position at which topright corner of base of scrollbar
" should be located.
function s:get_basepos() abort "{{{
  let [line, col] = win_screenpos(0)
  if !empty(menu_info('WinBar', 'a'))
    let line += 1
  endif
  let col += winwidth(0) - g:sclow_sbar_right_offset - 1
  return [line, col]
endfunction "}}}


function s:is_blocked() abort "{{{
  return index(g:sclow_block_filetypes, &filetype) >= 0
    \ || index(g:sclow_block_buftypes,  &buftype)  >= 0
endfunction "}}}


function s:sbar_exists() abort "{{{
  return exists('s:sbar_id')
endfunction "}}}


function s:unlet_sbar_id() abort "{{{
  unlet s:sbar_id
endfunction "}}}


" Return height of visible and invisible area of current buffer.
" +--------------------+                         +--------------------+
" |....                | <--+                    |....                | <--+
" |.. Invisible area   |    | PTOP               |..                  |    |
" |......              | <--+                    |......              |    |
" +--------------------+                         |.........           |    |
" |.......             | <--+                    |.. Invisible area   |    | PTOP
" |....                |    |                    |....                |    |
" |... Visible area    |    |                    |.....               |    |
" |..   (window)       |    | HEIGHT             |..                  |    |
" |............        |    |                    |............        |    |
" |......              |    |                    |......              | <--+
" +--------------------+ <--+                    +--------------------+
" |.......             | <--+                    |.......             | <--+
" |.............       |    | PBOT               |.............       |    | HEIGHT
" |.. Invisible area   | <--+                    |... Visible area    | <--+
" |~                   | <--+               +--> |~    (window)       |      PBOT = 0
" |~                   |    | End of buffer |    |~                   |
" |~                   | <--+               +--> |~                   |
" +--------------------+                         +--------------------+
" NOTE: PTOP and PBOT are computed assuming that there are no wraps or
" foldings in the corresponding areas.
function s:get_bufheights() abort "{{{
  let bufheights = {}
  let bufheights.PTOP = line('w0') - 1
  let bufheights.PBOT = line('$') - line('w$')
  let bufheights.HEIGHT = (bufheights.PBOT == 0)
    \ ? s:bufheight()
    \ : winheight(0)
  return bufheights
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
function s:bufheight() abort "{{{
  let savecurpos = getcurpos()
  keepjumps normal! G
  let line = winline()
  keepjumps call setpos('.', savecurpos)
  return line
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
function s:get_masks(winheight, bufheights) abort "{{{
  let PTOP   = a:bufheights.PTOP
  let HEIGHT = a:bufheights.HEIGHT
  let PBOT   = a:bufheights.PBOT
  let TOTAL  = PTOP + HEIGHT + PBOT

  let total  = a:winheight
  let scale  = 1.0 * total / TOTAL
  let ptop   = float2nr(PTOP * scale)
  let height = float2nr(ceil(HEIGHT * scale))

  if total <= 2
    " Cannot meet all requirements. Mask all.
    return [s:mask(total, 'top')]
  endif

  if PTOP >= 1 && PBOT >= 1 "{{{
    if ptop == 0
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


  if PBOT >= 1 " && PTOP == 0 {{{
    let pbot = total - (ptop + height)

    if pbot == 0
      let pbot = 1
    endif

    return [s:mask(pbot, 'bot')]
  endif "}}}


  if PTOP >= 1 " && PBOT == 0 {{{
    if ptop == 0
      let ptop = 1
    endif

    return [s:mask(ptop, 'top')]
  endif "}}}


  " PBOT == 0 && PTOP == 0
  return g:sclow_hide_full_length
    \ ? [s:mask(total, 'top')]
    \ : []
endfunction "}}}


" Return formatted popup mask.
function s:mask(height, pos) abort "{{{
  if a:pos is# 'top'
    return [1, strwidth(g:sclow_sbar_text),  1,  a:height]
  elseif a:pos is# 'bot'
    return [1, strwidth(g:sclow_sbar_text), -a:height, -1]
  endif
endfunction "}}}


" API function to get scrollbar id.
function sclow#getsbarid() abort "{{{
  return get(s:, 'sbar_id', '')
endfunction "}}}
