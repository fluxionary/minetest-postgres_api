local S = minetest.get_translator(minetest.get_current_modname())

local ie = assert(
	minetest.request_insecure_environment(),
	S("postgres_api will not work unless it has been listed under secure.trusted_mods in minetest.conf")
)
local pgsql = assert(ie.require("pgsql"), S("postgres_api will not function without pgsql. See README.md"))

postgres_api = fmod.create(nil, {
	pgsql = pgsql,
})

postgres_api.dofile("api", "init")
