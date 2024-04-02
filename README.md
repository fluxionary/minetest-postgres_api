# postgres_api

a postgres API for minetest.

this is a "complex installation" mod, and is intended for server owners and not most minetest users.

it is intended to provide a secure way for a mod to access a postgres DB without needing access to the full insecure
environment. care has been taken to leak neither the insecure environment nor anything accessed from it. because it is
a simple mod, it should be much easier to audit and trust than a complex mod needing database access.

currently, this mod only provides the basics - executing and preparing statements, and getting the results. more
features can be added as necessary (transactions, maybe?), but keeping things simple is a design goal.

## requirements

* postgres_api must be listed as a trusted mod in minetest.conf (`secure.trusted_mods`)
* luapgsql must be accessible to whatever lua interpreter your minetest is using.
  * https://luarocks.org/modules/mbalmer/luapgsql

## usage

first, you must add your mod to `secure.postgres_api.trusted_mods` in minetest.conf.

if a postgres error occurs during any of these operations, an error message will be returned as the second value.

```lua
-- connections *must* be initialized while your mod is initializing!
-- be careful how you store this value! generally, you want to keep it secure the same way you'd secure the
-- full insecure environment, or anything emitted from it.
-- see https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING for more info on connection strings
local connection, errormsg = postgres_api.get_connection("postgres://user:password@host:port/database")

-- a unix-domain socket
postgres_api.get_connection("postgres://user:password@/database?host=/path/to/db")

-- alternate format for connection spec
postgres_api.get_connection({
    user = "user",
    password = "password",
    host = "host",
    port = "port",
    database = "database"
})

connection:exec([[
    CREATE TABLE IF NOT EXISTS user (
        id                INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY
      , name              TEXT    NOT NULL
      , password          TEXT    NOT NULL
    )
]])

function my_mod.add_user(name, password)
    local _, erromsg = connection:exec("add a user", "INSERT INTO user (name, password) VALUES (?, ?)", name, password)
end

-- only store prepared statements in locally-accessible variables. leaking them might be dangerous!
local add_users_prepared = connection:prepare("add users", "INSERT INTO user (name, password) VALUES (?, ?)")
function mod_mod.bulk_add_users(data)
    for _, datum in ipairs(data) do
        local _, erromsg = add_users_prepared:exec(unpack(datum))
    end
end

function my_mod.get_users()
    local res, erromsg = connection:exec("get users", "SELECT name FROM user")
    local users = {}
    for i = 1, #res do
        users[i] = res[i][1]
    end
    return users
end
```
