" Needed until neovim/neovim#15099
function! health#lean#check() abort
    lua require'lean.health'.check()
endfunction
