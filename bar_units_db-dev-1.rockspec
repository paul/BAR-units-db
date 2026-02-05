package = "bar_units_db"
version = "dev-1"
source = {
	url = "*** please add URL for source tarball, zip or repository here ***",
}
description = {
	homepage = "*** please enter a project homepage ***",
	license = "*** please specify a license ***",
}
dependencies = {
	"luafilesystem",
	"dkjson",
}
build = {
	type = "builtin",
	modules = {
		units2json = "units2json.lua",
	},
}
