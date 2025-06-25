LUA ?= lua

.PHONY: test

test:
	eval "$$(luarocks path --lua-version=5.3)" && \
	LUA_PATH="./?.lua;./lua/?.lua;./lua/?/init.lua;./lua/?/main.lua;./lua/?/?/?.lua;./lua/?/?/init.lua;./lua/?/?/?/?.lua;$$LUA_PATH" \
	busted --lua=$(LUA) spec
