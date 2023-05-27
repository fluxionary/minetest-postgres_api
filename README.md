# postgres_api

postgres API for minetest.

NOTE: THIS IS UNFINISHED AND NOT CURRENTLY FUNCTIONAL

## requirements

* postgres_api must be listed as a trusted mod in minetest.conf (`secure.trusted_mods`)
* luapgsql must be accessible to whatever lua interpreter your minetest is using.
  * https://luarocks.org/modules/mbalmer/luapgsql

## usage

first, you must add your mod to `postgres_api.trusted_mods` in minetest.conf.

```lua
-- connections must be initialized while your mod is initializing
local connection = postgres_api.get_connection("postgres://user:password@host:port/database")

-- alternate format for connection spec
local connection2 = postgres_api.get_connection({
    user = "user",
    password = "password",
    host = "host",
    port = "port",
    database = "database"
})

function my_mod.add_user(name)
    connection:exec("INSERT INTO users (name) VALUES (?)", "add a user", name)
end

function mod_mod.bulk_add_users(names)
    connection:prepare("add users", "INSERT INTO users (name) VALUES (?)")
    for _, name in ipairs(names) do
        connection:exec_prepared("add users", name)
    end
end

function my_mod.get_users()
    local ... = connection:exec("SELECT name FROM users", "get users")
end
```
