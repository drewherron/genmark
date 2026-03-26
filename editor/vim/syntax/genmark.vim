" Vim syntax file
" Language: Genmark (.gmd)
" URL: https://github.com/drewherron/genmark

if exists('b:current_syntax')
  finish
endif

" --- Comments ---

syn region genmarkBlockComment start="/\*" end="\*/" contains=@Spell
syn match  genmarkLineComment  "\(:\)\@<!//.*$" contains=@Spell

" --- Top-level headers ---

" Person header: Name [id]
syn match genmarkPersonName "^[A-Z].\{-}\ze\s\+\[\w\+\]\s*$"
      \ nextgroup=genmarkPersonID skipwhite
syn match genmarkPersonID   "\[\w\+\]" contained

" Source header: source [id]
syn match genmarkSourceKeyword "^source\ze\s\+\[\w\+\]"
      \ nextgroup=genmarkSourceID skipwhite
syn match genmarkSourceID   "\[\w\+\]" contained

" Union header: [id] + [id]
syn match genmarkUnionHeader "^\[\w\+\]\s*+\s*\[\w\+\]"
      \ contains=genmarkUnionID,genmarkUnionPlus
syn match genmarkUnionID   "\[\w\+\]" contained
syn match genmarkUnionPlus "+" contained

" --- Field tags ---

" Person field tags
syn match genmarkFieldTag "^\s\+\zsaka\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zssex\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zsb\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zsd\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zschr\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zsbap\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zsbur\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zscrm\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zsimm\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zsemi\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zsnat\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zsres\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zscen\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zsocc\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zsmil\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zsevt\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zsm\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zsdiv\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zsparents\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zsmaybe\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zsnote\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zssrc\ze:" nextgroup=genmarkFieldColon

" Source definition field tags
syn match genmarkFieldTag "^\s\+\zstitle\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zsauthor\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zspub\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zsurl\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zsrepo\ze:" nextgroup=genmarkFieldColon
syn match genmarkFieldTag "^\s\+\zspage\ze:" nextgroup=genmarkFieldColon

" --- Inline elements ---

" Child marker >
syn match genmarkChildMarker "^\s\+>" nextgroup=genmarkIDRef skipwhite

" @ place separator
syn match genmarkAtSign "\s\zs@\ze\s"

" ID references [word] (not source citations)
syn match genmarkIDRef "\[\w\+\]" contained containedin=ALL

" Source citations [src: ...]
syn match genmarkSourceCite "\[src:[^\]]*\]"

" Date modifiers
syn match genmarkDateMod "\%(^\|\s\)\zs[~<>]\ze\d"
syn match genmarkDateRange "\d\+\.\.\d\+"

" Multi-line note pipe
syn match genmarkNotePipe "^\s\+note:\s\+\zs|\ze\s*$"

" Special ? values
syn match genmarkUnknown "^\s\+\%(d\|sex\):\s\+\zs?\ze\s*$"

" --- Highlight links ---

hi def link genmarkBlockComment  Comment
hi def link genmarkLineComment   Comment
hi def link genmarkPersonName    Function
hi def link genmarkPersonID      Identifier
hi def link genmarkSourceKeyword Keyword
hi def link genmarkSourceID      Identifier
hi def link genmarkUnionID       Identifier
hi def link genmarkUnionPlus     Keyword
hi def link genmarkFieldTag      Keyword
hi def link genmarkChildMarker   Special
hi def link genmarkAtSign        Special
hi def link genmarkIDRef         Identifier
hi def link genmarkSourceCite    String
hi def link genmarkDateMod       Type
hi def link genmarkDateRange     Type
hi def link genmarkNotePipe      Special
hi def link genmarkUnknown       WarningMsg

let b:current_syntax = 'genmark'
