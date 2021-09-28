#!/bin/sh
if [ -z ${TEST_FILE+x} ]; then
  nvim --headless --noplugin -u scripts/minimal_init.lua -c "PlenaryBustedDirectory lua/tests/ { minimal_init = './scripts/minimal_init.lua'; sequential = true; keep_going = true }"
else
  nvim --headless --noplugin -u scripts/minimal_init.lua -c "PlenaryBustedFile $TEST_FILE"
fi
