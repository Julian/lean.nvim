---@mod lean.neovim_compat Neovim compatibility fixes

---@brief [[
--- Compatibility fixes for different versions of Neovim.
--- This module provides workarounds for known issues in specific Neovim versions.
---@brief ]]

local compat = {}

---Fix for Neovim nightly `band` error in file watching.
---
---In Neovim nightly, file system event types were changed from numbers to userdata,
---but some code still tries to use `bit.band` on them, causing errors.
---This function provides a workaround by ensuring the arguments are always numbers.
local function fix_band_error()
  -- Only apply the fix if we detect we're running a problematic version
  local has_userdata_events = false
  
  -- Try to detect if we have the problematic version by checking if vim._watch exists
  -- and if event types are userdata
  if vim._watch and vim._watch.FileChangeType then
    local event_type = vim._watch.FileChangeType.Created
    if type(event_type) == 'userdata' then
      has_userdata_events = true
    end
  end
  
  -- Also check for vim.uv.fs_event constants if they exist and are userdata
  if not has_userdata_events and vim.uv and vim.uv.fs_event then
    for k, v in pairs(vim.uv.fs_event) do
      if type(v) == 'userdata' then
        has_userdata_events = true
        break
      end
    end
  end
  
  if not has_userdata_events then
    return -- No fix needed
  end

  -- Override bit.band to handle userdata by converting to numbers
  local original_band = bit.band
  
  bit.band = function(a, b)
    -- Convert userdata to numbers if needed
    if type(a) == 'userdata' then
      -- Try different ways to convert userdata to number
      if getmetatable(a) and getmetatable(a).__tonumber then
        a = tonumber(a)
      elseif getmetatable(a) and getmetatable(a).__index and type(getmetatable(a).__index.value) == 'number' then
        a = getmetatable(a).__index.value
      elseif a.value and type(a.value) == 'number' then
        a = a.value
      else
        -- If we can't convert, try to use the userdata directly with pcall
        local success, result = pcall(original_band, a, b)
        if success then
          return result
        else
          -- Last resort: treat as 0
          a = 0
        end
      end
    end
    if type(b) == 'userdata' then
      if getmetatable(b) and getmetatable(b).__tonumber then
        b = tonumber(b)
      elseif getmetatable(b) and getmetatable(b).__index and type(getmetatable(b).__index.value) == 'number' then
        b = getmetatable(b).__index.value
      elseif b.value and type(b.value) == 'number' then
        b = b.value
      else
        b = 0
      end
    end
    
    return original_band(a, b)
  end
end

---Fix for file watching issues in Neovim nightly.
---
---Disables file watching capabilities to prevent the band error from occurring.
local function disable_file_watching()
  -- Check if this is a problematic version and disable file watching
  local function patch_capabilities(capabilities)
    capabilities = capabilities or {}
    capabilities.workspace = capabilities.workspace or {}
    capabilities.workspace.didChangeWatchedFiles = nil
    return capabilities
  end
  
  -- Override make_client_capabilities to disable file watching
  local original_make_capabilities = vim.lsp.protocol.make_client_capabilities
  vim.lsp.protocol.make_client_capabilities = function()
    local capabilities = original_make_capabilities()
    return patch_capabilities(capabilities)
  end
end

---Apply all compatibility fixes.
function compat.apply_fixes()
  -- Add missing vim.uv for older Neovim versions
  if not vim.uv then
    vim.uv = vim.loop
  end
  
  -- Add missing vim.lsp.protocol.Methods for older Neovim versions
  if vim.lsp.protocol and not vim.lsp.protocol.Methods then
    vim.lsp.protocol.Methods = {
      textDocument_publishDiagnostics = 'textDocument/publishDiagnostics',
      textDocument_didClose = 'textDocument/didClose',
      textDocument_didOpen = 'textDocument/didOpen',
    }
  end
  
  -- Add missing vim.version.ge for older Neovim versions
  if vim.version and not vim.version.ge then
    vim.version.ge = function(v1, v2)
      local function parse_version(v)
        if type(v) == 'string' then
          local major, minor, patch = v:match('(%d+)%.(%d+)%.(%d+)')
          return {
            major = tonumber(major) or 0,
            minor = tonumber(minor) or 0,
            patch = tonumber(patch) or 0
          }
        end
        return v or { major = 0, minor = 0, patch = 0 }
      end
      
      v1 = parse_version(v1)
      v2 = parse_version(v2)
      
      if not v1 or not v2 then return false end
      if v1.major > v2.major then return true end
      if v1.major < v2.major then return false end
      if v1.minor > v2.minor then return true end
      if v1.minor < v2.minor then return false end
      return v1.patch >= v2.patch
    end
  end
  
  -- Add missing vim.iter for older Neovim versions
  if not vim.iter then
    -- Simplified vim.iter implementation for compatibility
    vim.iter = function(t)
      if type(t) ~= 'table' then
        return t
      end
      
      local result = {}
      for i, v in ipairs(t) do
        result[i] = v
      end
      
      local mt = {}
      
      function mt:map(func)
        local mapped = {}
        for i, v in ipairs(result) do
          mapped[i] = func(v)
        end
        return vim.iter(mapped)
      end
      
      function mt:filter(func)
        local filtered = {}
        for _, v in ipairs(result) do
          if func(v) then
            table.insert(filtered, v)
          end
        end
        return vim.iter(filtered)
      end
      
      function mt:each(func)
        for _, v in ipairs(result) do
          func(v)
        end
        return vim.iter(result)
      end
      
      function mt:totable()
        return result
      end
      
      function mt:any(func)
        for _, v in ipairs(result) do
          if func(v) then
            return true
          end
        end
        return false
      end
      
      function mt:fold(init, func)
        local acc = init
        for _, v in ipairs(result) do
          acc = func(acc, v)
        end
        return acc
      end
      
      return setmetatable({}, { __index = mt })
    end
  end
  
  -- Apply the band fix unconditionally to be safe
  fix_band_error()
  
  -- Check if we're running a version that might have the band issue
  local nvim_version = vim.version and vim.version() or { major = 0, minor = 9, patch = 0 }
  local is_nightly = vim.version and (vim.version().prerelease or string.find(tostring(vim.version()), 'dev'))
  
  if is_nightly then
    -- For nightly versions, apply file watching disable as well
    disable_file_watching()
  end
end

return compat