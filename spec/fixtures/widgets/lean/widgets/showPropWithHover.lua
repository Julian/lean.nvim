return function(_, props)
  return require('lean.tui').Element:new { text = props[1] }
end
