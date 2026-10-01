local wow = require("tests.mock.wow")

describe("locale", function()
	before_each(function()
		wow.reset()
	end)

	it("returns the key itself for strings it doesn't know", function()
		local ns = wow.loadAddon({ "locale.lua" })
		assert.equals("Not a real key", ns.L["Not a real key"])
	end)

	it("defines the English strings", function()
		local ns = wow.loadAddon({ "locale.lua" })
		assert.equals("Enable roll bars", rawget(ns.L, "Enable roll bars"))
		assert.equals("{tag} {name} won {item}", rawget(ns.L, "{tag} {name} won {item}"))
		assert.equals("BoP", rawget(ns.L, "BoP"))
	end)

	it("treats enGB as English", function()
		wow.locale = "enGB"
		local ns = wow.loadAddon({ "locale.lua" })
		assert.equals("Automatic", rawget(ns.L, "Automatic"))
	end)

	it("falls back to the English keys for a locale it has no block for", function()
		wow.locale = "xxXX"
		local ns = wow.loadAddon({ "locale.lua" })
		assert.is_nil(rawget(ns.L, "Enable roll bars"))
		assert.equals("Enable roll bars", ns.L["Enable roll bars"])
	end)
end)
