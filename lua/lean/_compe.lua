local compe = require("compe")

local Source = {}

function Source.new(lean_abbreviations)
  local self = setmetatable({}, { __index = Source })
  self._abbreviation_items = {}
  for source, target in pairs(lean_abbreviations) do
    table.insert(self._abbreviation_items, {
      word = target;
      abbr = source;
      info = target;
      filter_text = string.sub(source, 2);
    })
  end
  return self
end

Source.get_metadata = function(_)
  return {
    priority = 100;
    filetypes = {'lean3', 'lean'};
    dup = true;
    sort = true;
    menu = '[LA]';
  }
end

Source.determine = function(_, context)
  return compe.helper.determine(context, {
    keyword_pattern = [[\%(\\\|\w\)\+$]],
    trigger_characters = { '\\' };
  })
end

Source.complete = function(self, args)
  args.callback({ items = self._abbreviation_items })
end

-- REMOVEME: hrsh7th/nvim-compe#122
Source.documentation = function(_, args)
  args.callback(args.completed_item.word)
end

return Source
