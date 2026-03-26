" Vim indent file
" Language: Genmark (.gmd)
" URL: https://github.com/drewherron/genmark

if exists('b:did_indent')
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GenmarkIndent(v:lnum)
setlocal indentkeys=o,O,!^F

function! GenmarkIndent(lnum) abort
  let l:line = getline(a:lnum)
  let l:prev_lnum = prevnonblank(a:lnum - 1)

  if l:prev_lnum == 0
    return 0
  endif

  let l:prev = getline(l:prev_lnum)

  " Top-level constructs stay at column 0
  if l:line =~# '^\S.*\[\w\+\]\s*$'
        \ || l:line =~# '^source\s\+\[\w\+\]'
        \ || l:line =~# '^\[\w\+\]\s*+\s*\[\w\+\]'
    return 0
  endif

  " Child lines get 4 spaces
  if l:line =~# '^\s*>'
    return &shiftwidth * 2
  endif

  " After a top-level header: indent
  if l:prev =~# '^\S.*\[\w\+\]\s*$'
        \ || l:prev =~# '^source\s\+\[\w\+\]'
        \ || l:prev =~# '^\[\w\+\]\s*+\s*\[\w\+\]'
    return &shiftwidth
  endif

  " Otherwise: match previous line's indent
  return indent(l:prev_lnum)
endfunction

let b:undo_indent = 'setlocal indentexpr< indentkeys<'
