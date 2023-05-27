local private_env = ...
local pgsql = private_env.pgsql

local S = postgres_api.S

local trusted_mods = {}

for _, modname in ipairs(postgres_api.settings.trusted_mods:split()) do
	trusted_mods[modname] = true
end

-------------

local function check_description(description)
	if type(description) ~= "string" or description == "" then
		error(("invalid query description: %s"):format(description))
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
		error("out-of-memory or unable to send the command at all")
	end
	assert(connection:status() == pgsql.CONNECTION_OK, connection:errorMessage())
	return connection
end

--------------

local Connection = futil.class()

function postgres_api.get_connection(connspec)
	local current_modname = minetest.get_current_modname()
	assert(
		trusted_mods[current_modname],
		S(
			"in order to get a connection, %s must be added to postgres_api.trusted_mods in minetest.conf. "
				.. "see README.md for more information"
		)
	)
	return Connection(connspec)
end

function Connection:_init(connspec)
	if type(connspec) == "table" then
		connspec = ("postgres://%s:%s@%s:%s/%s"):format(
			connspec.user,
			connspec.password,
			connspec.host,
			connspec.port,
			connspec.database
		)
	end

	self._connection = check_connection(pgsql.connectdb(connspec))
end

-------------

function Connection:_check_result(result, description)
	if not result then
		error(("%s: invalid result: %s"):format(description, self._connection:errorMessage()))
	end
	if not is_result_ok(result) then
		local status = result:status()
		error(("%s: %s %s"):format(description, result:resStatus(status), result:errorMessage()))
	end
	return result
end

---------------------

function Connection:exec(command, description, ...)
	check_description(description)

	local result
	if #{ ... } > 0 then
		result = self._connection:execParams(command, ...)
	else
		result = self._connection:exec(command)
	end

	return self:_check_result(result, description)
end

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
function Connection:prepare(name, command, ...)
	local result = self._connection:prepare(name, command, ...)

	return self:_check_result(result, name)
end

function Connection:exec_prepared(name, ...)
	local result = self._connection:execPrepared(name, ...)

	return self:_check_result(result, name)
end
