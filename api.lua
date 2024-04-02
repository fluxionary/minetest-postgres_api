local private_env = ...
local pgsql = private_env.pgsql

local f = string.format
local S = postgres_api.S

local trusted_mods = {}

for _, modname in ipairs(postgres_api.settings.trusted_mods:split()) do
	trusted_mods[modname] = true
end

local mods_loaded = false
table.insert(minetest.registered_on_mods_loaded, 1, function()
	mods_loaded = true
end)

-------------

local function check_description(description)
	if type(description) ~= "string" or description == "" then
		error("invalid query description: " .. description)
	end
end

local function is_result_ok(result)
	if not result then
		return false
	end
	local status = result:status()
	return status ~= pgsql.PGRES_BAD_RESPONSE and status ~= pgsql.PGRES_FATAL_ERROR
end

local function check_connection(connection)
	if not connection then
		return nil, "out-of-memory or unable to send the connection command at all."
	end
	if connection:status() == pgsql.CONNECTION_OK then
		return connection
	else
		return nil, connection:errorMessage()
	end
end

local function check_result(connection, description, result)
	if not result then
		return nil, f("%s: invalid result: %s", description, connection:errorMessage())
	end
	if not is_result_ok(result) then
		return nil, f("%s: %s %s", description, result:resStatus(result:status()), result:errorMessage())
	end
	return result
end

--------------

local PreparedStatement = futil.class()

--[[
luapgsql calls the first argument to `prepare` "command", and the second "name", but
that's backwards. they're passed to PQprepare in the same backwards order, so we can
just use the order that PQprepare expects (name first, query second)
...
	conn = pgsql_conn(L, 1);
	command = luaL_checkstring(L, 2);
	name = luaL_checkstring(L, 3);
...
	*res = PQprepare(conn, command, name, nParams, paramTypes);
...
PGresult *PQprepare(PGconn *conn,
                    const char *stmtName,
                    const char *query,
                    int nParams,
                    const Oid *paramTypes);
]]
function PreparedStatement:_init(connection, name, command, ...)
	-- connection is properly private because minetest lacks debug.getupvalue (thanks to me!)
	local result = connection:prepare(name, command, ...)
	check_result(connection, name, result)
	self._name = name
	-- keep the connection private
	function self._exec(...)
		local exec_result = connection:execPrepared(name, ...)

		return check_result(connection, name, exec_result)
	end
end

function PreparedStatement:exec(...)
	return self._exec(...)
end

--------------

local Connection = futil.class()

function postgres_api.get_connection(connspec)
	assert(not mods_loaded, S("connections can only be created while mods are loading."))
	local current_modname = minetest.get_current_modname()
	assert(
		trusted_mods[current_modname],
		S(
			"in order to get a connection, %s must be added to postgres_api.trusted_mods in minetest.conf. "
				.. "see README.md for more information."
		)
	)
	return Connection(connspec)
end

function Connection:_init(connspec)
	if type(connspec) == "table" then
		connspec = f(
			"postgres://%s:%s@%s:%s/%s",
			connspec.user,
			connspec.password,
			connspec.host,
			connspec.port,
			connspec.database
		)
	end

	-- this is properly private because minetest lacks debug.getupvalue (thanks to me!)
	local connection = check_connection(pgsql.connectdb(connspec))

	function self._exec(description, command, ...)
		check_description(description)

		local result
		if #{ ... } > 0 then
			result = connection:execParams(command, ...)
		else
			result = connection:exec(command)
		end

		return check_result(connection, description, result)
	end

	function self._prepare(name, command, ...)
		return PreparedStatement(connection, name, command, ...)
	end

	function self._disconnect()
		connection:finish()
	end

	function self._reconnect()
		connection = check_connection(pgsql.connectdb(connspec))
	end

	function self._is_connected()
		local _, errormsg = check_connection(connection)
		if errormsg then
			return false, errormsg
		else
			return true
		end
	end
end

---------------------

function Connection:exec(description, command, ...)
	return self._exec(description, command, ...)
end

function Connection:prepare(name, command, ...)
	return self._prepare(name, command, ...)
end

function Connection:disconnect()
	self._disconnect()
end

function Connection:reconnect()
	self._reconnect()
end

function Connection:is_connected()
	return self._is_connected()
end
