" Vim ftplugin file
" Language: Genmark (.gmd)
" URL: https://github.com/drewherron/genmark

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let s:save_cpo = &cpo
set cpo&vim

" --- Basic settings ---

setlocal expandtab
setlocal shiftwidth=2
setlocal softtabstop=2
setlocal tabstop=2

" Comment format for commentary plugins and built-in gc
setlocal commentstring=//\ %s
setlocal comments=s1:/*,mb:*,ex:*/,://

" --- Folding ---

setlocal foldmethod=expr
setlocal foldexpr=GenmarkFoldExpr(v:lnum)
setlocal foldtext=GenmarkFoldText()
setlocal foldlevel=99

function! GenmarkFoldExpr(lnum) abort
  let l:line = getline(a:lnum)

  " Top-level headers start a fold
  if l:line =~# '^\S.*\[\w\+\]\s*$'
        \ || l:line =~# '^source\s\+\[\w\+\]'
        \ || l:line =~# '^\[\w\+\]\s*+\s*\[\w\+\]'
    return '>1'
  endif

  " Blank lines between blocks: keep at level 0 if next non-blank is a header
  if l:line =~# '^\s*$'
    let l:next = nextnonblank(a:lnum + 1)
    if l:next > 0
      let l:nextline = getline(l:next)
      if l:nextline =~# '^\S.*\[\w\+\]\s*$'
            \ || l:nextline =~# '^source\s\+\[\w\+\]'
            \ || l:nextline =~# '^\[\w\+\]\s*+\s*\[\w\+\]'
        return '0'
      endif
    endif
    return '='
  endif

  " Comment-only lines at column 0 between blocks stay at 0
  if l:line =~# '^//' && (a:lnum == 1 || getline(a:lnum - 1) =~# '^\s*$')
    return '0'
  endif

  " Indented lines and block-interior comments are inside the fold
  return '='
endfunction

function! GenmarkFoldText() abort
  let l:line = getline(v:foldstart)
  let l:count = v:foldend - v:foldstart
  return l:line . '  (' . l:count . ' lines)'
endfunction

" --- Keybindings ---

" Tab: toggle fold on headings, indent on other lines
nnoremap <buffer> <Tab> :call <SID>GenmarkTab()<CR>
" Shift-Tab: toggle all folds
nnoremap <buffer> <S-Tab> :call <SID>GenmarkFoldAll()<CR>
" Enter: smart newline with auto-indent
inoremap <buffer> <CR> <C-o>:call <SID>GenmarkNewline()<CR>

function! s:GenmarkTab() abort
  let l:line = getline('.')
  if l:line =~# '^\S.*\[\w\+\]\s*$'
        \ || l:line =~# '^source\s\+\[\w\+\]'
        \ || l:line =~# '^\[\w\+\]\s*+\s*\[\w\+\]'
    if foldclosed('.') >= 0
      normal! zo
    else
      normal! zc
    endif
  else
    normal! >>
  endif
endfunction

function! s:GenmarkFoldAll() abort
  let l:has_closed = 0
  let l:lnum = 1
  while l:lnum <= line('$')
    if foldclosed(l:lnum) >= 0
      let l:has_closed = 1
      break
    endif
    let l:lnum += 1
  endwhile

  if l:has_closed
    normal! zR
  else
    normal! zM
  endif
endfunction

function! s:GenmarkNewline() abort
  let l:line = getline('.')
  let l:col = col('.')

  " If current line is blank/whitespace-only and indented, clear and go to col 0
  if l:line =~# '^\s\+$'
    call setline('.', '')
    call cursor(line('.'), 1)
    execute "normal! o"
    return
  endif

  " Insert new line
  execute "normal! o"

  " Determine indent for the new line
  let l:prev = getline(line('.') - 1)
  if l:prev =~# '^\S.*\[\w\+\]\s*$'
        \ || l:prev =~# '^source\s\+\[\w\+\]'
        \ || l:prev =~# '^\[\w\+\]\s*+\s*\[\w\+\]'
    " After a header: indent
    call setline('.', repeat(' ', &shiftwidth))
    call cursor(line('.'), &shiftwidth + 1)
  elseif l:prev =~# '^\s'
    " After an indented line: match indent
    let l:indent = matchend(l:prev, '^\s\+')
    call setline('.', repeat(' ', l:indent))
    call cursor(line('.'), l:indent + 1)
  endif

  startinsert!
endfunction

" --- Undo ftplugin ---

let b:undo_ftplugin = 'setlocal expandtab< shiftwidth< softtabstop< tabstop<'
      \ . ' commentstring< comments< foldmethod< foldexpr< foldtext< foldlevel<'
      \ . '| nunmap <buffer> <Tab>'
      \ . '| nunmap <buffer> <S-Tab>'
      \ . '| iunmap <buffer> <CR>'

let &cpo = s:save_cpo
unlet s:save_cpo
