# vim-sclow

Text-based scrollbar for Vim.

![sclow eyecatch](https://i.gyazo.com/0e141446f04bf34ecdd3e55ee439a291.gif)


## Installation

Requires Vim compiled with +popupwin feature (Neovim is not supported).

If you use [vim-plug](https://github.com/junegunn/vim-plug), add the following
line to your vimrc:

```vim
Plug 'obcat/vim-sclow'
```

You can use any other plugin manager.


## Usage

No configuration is required. Scrollbar is automaticaly shown in the current
window.


### When will scrollbar's position be updated?

When you scroll with cursor moves, the scrollbar's position is updated
immediately.

On the other hand, scrolling without cursor moves (you can do this with `<C-e>`
or `<C-y>`), the position will be updated after the time specified with
`updatetime` option.

The default value of `updatetime` option is `4000`, i.e. 4 seconds. If you want
to update the scrollbar's position as soon as possible in the latter situation,
reduce the value of this option. I suggest around 100ms:

```vim
set updatetime=100
```

Note that `updatetime` also controls the delay before Vim writes its swap file
(see `:h updatetime`).


## Customization

You can customize some features.


### Appearance

To customize scrollbar's appearance, you can use:

* `g:sclow_sbar_text` (default: `"\<Space>"`)
* `SclowSbar` highlight group (default: links to `Pmenu`)

Examples:

![sbar ex 1](https://user-images.githubusercontent.com/64692680/100740863-bb3d0880-341c-11eb-950c-50350e256be6.png)

```vim
let g:sclow_sbar_text = '*'
highlight link SclowSbar PmenuSel
```

![sbar ex 2](https://user-images.githubusercontent.com/64692680/100744585-68198480-3421-11eb-9e5a-bd5398b7efa3.png)

```vim
let g:sclow_sbar_text = '👾👾'
highlight SclowSbar ctermbg=NONE guibg=NONE
```

:memo: I use [iceberg.vim](https://github.com/cocopon/iceberg.vim) for color scheme.

You can use `g:sclow_sbar_right_offset` to specify the scrollbar offset from
right border of window. The defaut value is `0`. Negative values are also allowed;
`-1` may be useful:

### Blocking

If you don't want to see the scrollbar in a specific buffer, you can use:

* `g:sclow_block_filetypes` (default: `[]`)
* `g:sclow_block_buftypes` (default: `[]`)

Example:

```vim
let g:sclow_block_filetypes = ['netrw', 'nerdtree']
let g:sclow_block_buftypes = ['terminal', 'prompt']
```


### Misc

By default, when both the first and last line of the buffer are in the window,
a full-length scrollbar will be shown.

![full-length sbar](https://user-images.githubusercontent.com/64692680/100746502-22aa8680-3424-11eb-9bc3-72d54295a36c.png)

If you want to turn this off, you can use:

```vim
let g:hide_full_length = 1
```

See help file for more information.


## License

MIT License.
