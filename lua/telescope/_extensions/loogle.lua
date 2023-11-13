local loogle = require 'telescope._extensions.loogle.loogle_search'
local telescope = require 'telescope'

return telescope.register_extension {
  exports = {
    loogle = loogle.find,
  },
}
