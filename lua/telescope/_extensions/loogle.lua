local telescope = require('telescope');
local loogle = require('telescope._extensions.loogle.loogle_search');

return telescope.register_extension {
  exports = {
    loogle = loogle.find
  }
}
