local wow = require("tests.mock.wow")

local function ReadFile(path)
	local file = assert(io.open(path, "rb"))
	local text = file:read("*a")
	file:close()
	return text
end

local function LocaleBlocks()
	local blocks, current = {}, nil
	for line in ReadFile("locale.lua"):gmatch("[^\n]+") do
		local lang = line:match('^if lang == "(%a+)"')
		if lang then
			current = lang
			blocks[current] = {}
		end
		local key = line:match('^%s*L%["(.-)"%]%s*=')
		if key and current then blocks[current][key] = true end
		if line:match("^end") then current = nil end
	end
	return blocks
end

local function Sorted(set)
	local list = {}
	for key in pairs(set) do list[#list + 1] = key end
	table.sort(list)
	return list
end

describe("translations", function()
	local blocks = LocaleBlocks()

	it("has a block for every client language", function()
		assert.same({ "deDE", "enUS", "esES", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }, Sorted(blocks))
	end)

	it("translates exactly the same keys everywhere", function()
		local english = Sorted(blocks.enUS)
		assert.equals(28, #english)
		for lang, keys in pairs(blocks) do
			assert.same(english, Sorted(keys), lang)
		end
	end)

	it("defines every key the code uses", function()
		for _, file in ipairs({ "config.lua", "core.lua", "bars.lua", "chat.lua" }) do
			for key in ReadFile(file):gmatch('L%["(.-)"%]') do
				assert.is_true(blocks.enUS[key] == true, file .. " uses undefined key: " .. key)
			end
		end
	end)

	it("loads every language, including the shared ones, without gaps", function()
		for _, lang in ipairs({ "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ptPT", "ruRU", "zhCN", "zhTW" }) do
			wow.reset()
			wow.locale = lang
			local ns = wow.loadAddon({ "locale.lua" })
			for key in pairs(blocks.enUS) do
				local value = rawget(ns.L, key)
				assert.is_true(type(value) == "string" and value ~= "", lang .. " is missing " .. key)
			end
		end
	end)

	it("keeps the summary placeholders intact in every language", function()
		for _, lang in ipairs({ "deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }) do
			wow.reset()
			wow.locale = lang
			local L = wow.loadAddon({ "locale.lua" }).L
			for _, token in ipairs({ "{tag}", "{name}", "{item}" }) do
				assert.truthy(L["{tag} {name} won {item}"]:find(token, 1, true), lang .. " lost " .. token)
			end
			assert.truthy(L["{roll} - {value}"]:find("{roll}", 1, true), lang)
			assert.truthy(L["{roll} - {value}"]:find("{value}", 1, true), lang)
		end
	end)

	it("localizes the addon list notes for every language", function()
		local toc = ReadFile("LootBeacon.toc")
		for _, lang in ipairs({ "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }) do
			assert.truthy(toc:find("## Notes-" .. lang .. ": ", 1, true), lang)
			assert.truthy(toc:find("## Category-" .. lang .. ": ", 1, true), lang)
		end
	end)
end)
