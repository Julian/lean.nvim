local uv = vim.uv

local function repo_root()
  local this_file = debug.getinfo(1, 'S').source:sub(2)
  return vim.fs.dirname(vim.fs.dirname(this_file))
end

local ROOT = repo_root()
local PROJECT = vim.fs.joinpath(ROOT, 'spec/fixtures/projects/Example')
local SOURCE = vim.fs.joinpath(PROJECT, 'Example.lean')
local TARGET = vim.fs.joinpath(PROJECT, '.benchmark-typing.lean')
local OUT = vim.env.LEAN_NVIM_BENCH_OUT or vim.fs.joinpath(ROOT, 'typing-benchmark.json')
local TEXT = vim.env.LEAN_NVIM_BENCH_TEXT or 'veryLongPropositionNameWithManySegmentsAndArguments'
local MODE = vim.env.LEAN_NVIM_BENCH_MODE or 'full'

local function env_number(name, default)
  local raw = tostring(vim.env[name] or default)
  raw = raw:gsub('^"(.*)"$', '%1'):gsub("^'(.*)'$", '%1')
  return assert(tonumber(raw), ('%s must be numeric, got %q'):format(name, raw))
end

local REPETITIONS = env_number('LEAN_NVIM_BENCH_REPETITIONS', '4')
local COOLDOWN = env_number('LEAN_NVIM_BENCH_COOLDOWN', '0')

if not vim.tbl_contains(vim.opt.runtimepath:get(), ROOT) then
  vim.opt.runtimepath:append(ROOT)
end

local function write_file(path, lines)
  local fd = assert(io.open(path, 'w'))
  fd:write(lines)
  fd:close()
end

local function read_file(path)
  local fd = assert(io.open(path, 'r'))
  local contents = fd:read '*a'
  fd:close()
  return contents
end

local function wait_for(predicate, timeout, message)
  local ok = vim.wait(timeout or 30000, predicate)
  if not ok then
    error(message or 'timed out waiting for condition')
  end
end

local function cleanup()
  pcall(vim.fn.delete, TARGET)
end

vim.api.nvim_create_autocmd('VimLeavePre', {
  once = true,
  callback = cleanup,
})

vim.g.lean_config = vim.tbl_deep_extend('force', vim.g.lean_config or {}, {
  infoview = { update_cooldown = COOLDOWN },
  lsp = {
    enhanced_handlers = {
      hover = true,
      diagnostics = true,
    },
  },
})

require('lean').setup(vim.g.lean_config)

local pin
local infoview = require 'lean.infoview'
if MODE == 'full' then
  write_file(TARGET, read_file(SOURCE) .. '\n\n#check ') -- fresh file under the project root
  vim.cmd.edit { TARGET, bang = true }

  wait_for(function()
    return vim.bo.filetype == 'lean'
  end, 10000, 'lean filetype did not load')

  wait_for(function()
    return not vim.tbl_isempty(vim.lsp.get_clients { bufnr = 0, name = 'leanls' })
  end, 30000, 'leanls did not attach')

  wait_for(function()
    local iv = infoview.get_current_infoview()
    return iv and iv.pin and iv.window
  end, 30000, 'infoview did not open')

  pin = infoview.get_current_infoview().pin
else
  vim.cmd.enew()
  vim.bo.filetype = 'lean'
  infoview.open()
  wait_for(function()
    local iv = infoview.get_current_infoview()
    return iv and iv.pin and iv.window
  end, 5000, 'could not create synthetic infoview')
  pin = infoview.get_current_infoview().pin
  pin.__position_params = {
    textDocument = { uri = 'file:///synthetic.lean' },
    position = { line = 0, character = 0 },
  }
end

local counts = {
  requests = 0,
  queued = 0,
  started = 0,
  completed = 0,
  errors = 0,
  refreshed = 0,
  concurrent = 0,
  max_concurrent = 0,
}

local original_request_update = pin.request_update
local original_queue_update = pin.queue_update
local original_update_now = pin.__update_now

pin.request_update = function(self)
  counts.requests = counts.requests + 1
  return original_request_update(self)
end

pin.queue_update = function(self)
  counts.queued = counts.queued + 1
  return original_queue_update(self)
end

pin.__update_now = function(self)
  counts.started = counts.started + 1
  counts.concurrent = counts.concurrent + 1
  counts.max_concurrent = math.max(counts.max_concurrent, counts.concurrent)
  local ok, result = xpcall(function()
    return original_update_now(self)
  end, debug.traceback)
  counts.concurrent = counts.concurrent - 1
  counts.completed = counts.completed + 1
  if not ok then
    counts.errors = counts.errors + 1
    return result
  end
  return result
end

local refreshed_group = vim.api.nvim_create_augroup('LeanTypingBenchmark', { clear = true })
vim.api.nvim_create_autocmd('User', {
  group = refreshed_group,
  pattern = 'LeanPinRefreshed',
  callback = function()
    counts.refreshed = counts.refreshed + 1
  end,
})

local function snapshot()
  return vim.deepcopy(counts)
end

local function diff(after, before)
  local out = {}
  for key, value in pairs(after) do
    if type(value) == 'number' then
      out[key] = value - (before[key] or 0)
    end
  end
  return out
end

local function wait_for_quiescence(timeout)
  local last_change = uv.hrtime()
  local last_seen = snapshot()
  wait_for(function()
    local current = snapshot()
    if not vim.deep_equal(current, last_seen) or pin.loading or pin.__update_running or pin.__update_pending then
      last_change = uv.hrtime()
      last_seen = current
      return false
    end
    return (uv.hrtime() - last_change) / 1e6 >= 200
  end, timeout or 30000, 'benchmark did not become idle')
end

local function benchmark_typing_burst()
  if MODE ~= 'full' then
    return nil
  end
  vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(0), #'#check ' })
  wait_for_quiescence(30000)

  local typed = {}
  for i = 1, REPETITIONS do
    typed[#typed + 1] = TEXT
    typed[#typed + 1] = tostring(i)
  end
  local payload = table.concat(typed, '')

  local before = snapshot()
  local t0 = uv.hrtime()
  local keys = vim.api.nvim_replace_termcodes('A' .. payload .. '<Esc>', true, false, true)
  vim.api.nvim_feedkeys(keys, 'xt', false)
  wait_for(function()
    return vim.fn.mode() == 'n'
  end, 5000, 'did not leave insert mode')
  local input_ms = (uv.hrtime() - t0) / 1e6

  local settle_start = uv.hrtime()
  wait_for_quiescence(30000)
  local settle_ms = (uv.hrtime() - settle_start) / 1e6

  return {
    payload_bytes = #payload,
    input_ms = input_ms,
    settle_ms = settle_ms,
    counters = diff(snapshot(), before),
  }
end

local function benchmark_queue_coalescing()
  local async = require 'std.async'
  local before = snapshot()
  local original = pin.__update_now
  local release = async.event()
  local queue_requests = 20
  local synthetic = { started = 0, completed = 0 }

  pin.__update_now = function(self)
    synthetic.started = synthetic.started + 1
    if synthetic.started == 1 then
      release.wait()
    end
    synthetic.completed = synthetic.completed + 1
  end

  pin:queue_update()
  wait_for(function()
    return synthetic.started == 1 and pin.__update_running
  end, 5000, 'synthetic update did not start')

  vim.schedule(function()
    for _ = 1, queue_requests do
      pin:queue_update()
    end
    release.set()
  end)

  wait_for(function()
    return synthetic.completed == 2 and not pin.__update_running and not pin.__update_pending
  end, 5000, 'synthetic queue did not drain')

  pin.__update_now = original

  return {
    queue_requests = queue_requests + 1,
    synthetic_runs = synthetic.completed,
    counters = diff(snapshot(), before),
  }
end

local results = {
  mode = MODE,
  cooldown_ms = COOLDOWN,
  target = TARGET,
  typing_burst = benchmark_typing_burst(),
  queue_coalescing = benchmark_queue_coalescing(),
}

write_file(OUT, vim.json.encode(results))
print(vim.json.encode(results))
vim.cmd.quitall { bang = true }
