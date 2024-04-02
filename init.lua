local ie = assert(
	minetest.request_insecure_environment(),
	"postgres_api will not work unless it has been listed under secure.trusted_mods in minetest.conf"
)
local pgsql = assert(ie.require("pgsql"), "postgres_api will not function without pgsql. See README.md")

postgres_api = fmod.create(nil, {
	pgsql = pgsql,
})

postgres_api.dofile("api")
