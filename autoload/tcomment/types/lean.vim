for ft in ['lean', 'lean3']
    call tcomment#type#Define(ft, '-- %s')
    call tcomment#type#Define(ft .. '_block', '/-%s-/')
endfor
