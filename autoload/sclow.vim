" Maintainer: obcat <obcat@icloud.com>
" License:    MIT License


function! s:init()
  let s:block_filetypes = get(g:, 'sclow_block_filetypes', [])
  let s:block_buftypes  = get(g:, 'sclow_block_buftypes', [])
  let s:sbar_text   = get(g:, 'sclow_sbar_text', "\<Space>")
  let s:sbar_zindex = get(g:, 'sclow_sbar_zindex', 20)
  let s:hide_full_length = get(g:, 'sclow_hide_full_length', 0)
  hi default link SclowSbar Pmenu

  let s:sbar_width = strlen(s:sbar_text)
endfunction


call s:init()


" This function is called on BufEnter and WinEnter
function! sclow#create() abort
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
endfunction


function! s:is_blocked() abort
  return index(s:block_filetypes, &l:filetype) >= 0
    \ || index(s:block_buftypes,  &l:buftype)  >= 0
endfunction


" This function is called on CursorMoved, CursorMovedI, and CursorHold
function! sclow#update() abort
  if !s:sbar_exists()
    return
  endif

  call s:update_sbar()

  call s:save_info()
endfunction


function! s:sbar_exists() abort
  return exists('w:sclow_sbar_id')
endfunction


function! s:create_sbar() abort
  let [l:line, l:col] = win_screenpos(0)
  let l:col += winwidth(0) - 1

  let w:sclow_sbar_id = popup_create(repeat([s:sbar_text], winheight(0)), #{
    \ pos:'topright',
    \ line: l:line,
    \ col:  l:col,
    \ mask: s:get_masks(),
    \ zindex: s:sbar_zindex,
    \ highlight: 'SclowSbar',
    \ callback: 's:unlet_sbar_id',
    \})
endfunction


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
function! s:get_masks() abort
  let l:ptop   = line('w0') - 1
  let l:height = winheight(0)
  let l:pbot   = line('$') - line('w$')
  let l:sbar_total = l:height

  if l:sbar_total <= 2
    " Cannot meet all requirements. Mask all.
    return [s:mask(l:sbar_total, 'top')]
  endif

  if l:ptop && l:pbot
    let l:total = l:ptop + l:height + l:pbot
    let l:scale = 1.0 * l:sbar_total / l:total
    let l:sbar_ptop   = float2nr(l:ptop * l:scale)
    let l:sbar_height = float2nr(ceil(l:height * l:scale))

    if !l:sbar_ptop
      let l:sbar_ptop = 1

      if l:sbar_ptop + l:sbar_height == l:sbar_total + 1
        let l:sbar_height -= 1
      endif
    endif

    if l:sbar_ptop + l:sbar_height == l:sbar_total
      let l:sbar_ptop -= 1
    endif

    let l:sbar_pbot = l:sbar_total - (l:sbar_ptop + l:sbar_height)

    return [
      \ s:mask(l:sbar_ptop, 'top'),
      \ s:mask(l:sbar_pbot, 'bot'),
      \ ]
  endif


  if l:pbot
    let l:total = l:height + l:pbot
    let l:scale = 1.0 * l:sbar_total / l:total
    let l:sbar_ptop   = float2nr(l:ptop * l:scale)
    let l:sbar_height = float2nr(ceil(l:height * l:scale))
    let l:sbar_pbot   = l:sbar_total - (l:sbar_ptop + l:sbar_height)

    if !l:sbar_pbot
      let l:sbar_pbot = 1
    endif

    return [s:mask(l:sbar_pbot, 'bot')]
  endif


  if l:ptop
    let l:total = l:ptop + s:bufheight()
    let l:scale = 1.0 * l:sbar_total / l:total
    let l:sbar_ptop = float2nr(l:ptop * l:scale)

    if !l:sbar_ptop
      let l:sbar_ptop = 1
    endif

    return [s:mask(l:sbar_ptop, 'top')]
  endif


  return s:hide_full_length
    \ ? [s:mask(l:sbar_total, 'top')]
    \ : []
endfunction


" Return formatted popup mask.
function! s:mask(height, pos) abort
  return a:pos == 'top'
    \ ? [1, s:sbar_width,  1,  a:height]
    \ : [1, s:sbar_width, -a:height, -1]
endfunction


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
function! s:bufheight() abort
  let l:save_curpos = getcurpos()
  keepjumps normal! G
  let l:line = winline()
  keepjumps call setpos('.', l:save_curpos)
  return l:line
endfunction


function! s:unlet_sbar_id(id, result) abort
  unlet w:sclow_sbar_id
endfunction


function! s:update_sbar() abort
  let l:pos = popup_getpos(w:sclow_sbar_id)

  let [l:line, l:col] = win_screenpos(0)
  let l:col += winwidth(0) - 1

  if [l:pos.line, l:pos.col] != [l:line, l:col]
    call s:move_sbar_base(l:line, l:col)
  endif

  if s:winheight_changed()
    call s:update_sbar_base()
  endif

  if s:scrolled()
    call s:update_sbar_masks()
  endif
endfunction


function! s:move_sbar_base(line, col) abort
  call popup_move(w:sclow_sbar_id, #{line: a:line, col: a:col})
endfunction


function! s:winheight_changed() abort
  return w:sclow_saved_winheight != winheight(0)
endfunction


function! s:update_sbar_base() abort
  call popup_settext(w:sclow_sbar_id, repeat([s:sbar_text], winheight(0)))
endfunction


function! s:scrolled() abort
  return w:sclow_saved_lines != [line('w0'), line('w$')]
endfunction


function! s:update_sbar_masks() abort
  call popup_setoptions(w:sclow_sbar_id, #{
    \ mask: s:get_masks(),
    \ })
endfunction


function! s:save_info() abort
  let w:sclow_saved_lines = [line('w0'), line('w$')]
  let w:sclow_saved_winheight = winheight(0)
endfunction


" This function is called on BufLeave and WinLeave
function! sclow#delete() abort
  " Avoid E994 (cf. https://github.com/obcat/vim-hitspop/issues/5)
  if win_gettype() == 'popup'
    return
  endif

  if s:sbar_exists()
    call s:delete_sbar()
  endif
endfunction


function! s:delete_sbar() abort
  call popup_close(w:sclow_sbar_id)
endfunction
