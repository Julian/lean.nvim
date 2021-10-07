" Can be removed as soon as we stop supporting 0.5,
" now that https://github.com/neovim/neovim/pull/15259 is merged.
function! health#lean#check() abort
    lua require'lean.health'.check()
endfunction
