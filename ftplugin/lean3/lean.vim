if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

set wildignore+=*.olean

setlocal iskeyword=@,48-57,_,-,!,#,$,%

setlocal comments=s0:/-,mb:\ ,ex:-/,:--
setlocal commentstring=/-\ %s\ -/

setlocal expandtab
setlocal shiftwidth=2
setlocal softtabstop=2

function! lean#dotted2path(fname)
  return substitute(a:fname, '\.', '/', 'g') . '.lean'
endfunction
setlocal includeexpr=lean#dotted2path(v:fname)

setlocal matchpairs+=⟨:⟩

" Matchit support
if exists('loaded_matchit') && !exists('b:match_words')
  let b:match_ignorecase = 0

  let b:match_words =
        \  '\<begin\>:\<end$' .
        \ ',\<\%(namespace\|section\)\s\+\(.\{-}\)\>:\<end\s\+\1\>'
endif
