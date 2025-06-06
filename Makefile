LUA=lua5.4
LUA_PATH_ENV=./lua/?.lua;./lua/?/init.lua;./lua/?/main.lua;;

.PHONY: test

test:
	LUA_PATH="$(LUA_PATH_ENV)" busted --lua=$(LUA) spec
