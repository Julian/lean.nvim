#!/bin/sh
if [ -z ${TEST_FILE+x} ]; then
  nvim --headless --noplugin -u scripts/minimal_init.lua -c "PlenaryBustedDirectory lua/tests/ { minimal_init = './scripts/minimal_init.lua' }"
elif [ -d ${TEST_FILE} ]; then
  nvim --headless --noplugin -u scripts/minimal_init.lua -c "PlenaryBustedDirectory $TEST_FILE { minimal_init = './scripts/minimal_init.lua' }"
else
  nvim --headless --noplugin -u scripts/minimal_init.lua -c "PlenaryBustedFile $TEST_FILE"
fi
