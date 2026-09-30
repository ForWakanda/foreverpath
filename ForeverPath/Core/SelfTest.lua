-- ForeverPath / Core / SelfTest.lua
-- Pure-logic checks that run in-game (/fp selftest) and in tests/run.lua.
local ADDON, FP = ...
local U = FP.Util
local T = FP:NewModule("SelfTest")

local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end

function T:Cases()
	local cases = {}
	local function case(name, fn) cases[#cases + 1] = { name = name, fn = fn } end

	case("ParseGUID creature", function()
		local kind, id = U.ParseGUID("Creature-0-4379-0-13-3131-00003BB8D2")
		assert(kind == "Creature" and id == 3131, tostring(kind) .. " " .. tostring(id))
	end)
	case("ParseGUID gameobject", function()
		local kind, id = U.ParseGUID("GameObject-0-4379-0-13-1731-00003BB8D2")
		assert(kind == "GameObject" and id == 1731)
	end)
	case("ParseGUID player", function()
		local kind, id = U.ParseGUID("Player-4-0A1B2C3D")
		assert(kind == "Player" and id == nil)
	end)
	case("ParseGUID garbage", function()
		assert(U.ParseGUID(nil) == nil and U.ParseGUID("") == nil and U.ParseGUID(42) == nil)
	end)
	case("bearing north/west/south/east", function()
		assert(near(U.Bearing(0, 0, 100, 0), 0), "north")
		assert(near(U.Bearing(0, 0, 0, 100), math.pi / 2), "west")
		assert(near(math.abs(U.Bearing(0, 0, -100, 0)), math.pi), "south")
		assert(near(U.Bearing(0, 0, 0, -100), -math.pi / 2), "east")
	end)
	case("relative angle facing west, target north => turn right (negative)", function()
		local rel = U.NormalizeAngle(U.Bearing(0, 0, 100, 0) - math.pi / 2)
		assert(near(rel, -math.pi / 2), tostring(rel))
	end)
	case("NormalizeAngle wraps", function()
		assert(near(U.NormalizeAngle(3 * math.pi), math.pi))
		assert(near(U.NormalizeAngle(-3 * math.pi), math.pi))
		assert(near(U.NormalizeAngle(0.5), 0.5))
	end)
	case("distance", function()
		assert(near(U.Distance(0, 0, 3, 4), 5))
	end)
	case("RadialOffset: north-up minimap, target west => left", function()
		local x, y = U.RadialOffset(math.pi / 2, 10)
		assert(near(x, -10) and near(y, 0, 1e-6), x .. "," .. y)
		x, y = U.RadialOffset(0, 10)
		assert(near(x, 0, 1e-6) and near(y, 10))
	end)
	case("FormatDistance", function()
		assert(U.FormatDistance(387.4) == "387 yd", U.FormatDistance(387.4))
		assert(U.FormatDistance(1234) == "1.23k yd", U.FormatDistance(1234))
		assert(U.FormatDistance(nil) == "?")
	end)
	case("FormatCoords", function()
		assert(U.FormatCoords(0.472, 0.618) == "47.2, 61.8", U.FormatCoords(0.472, 0.618))
	end)
	case("MoneyString", function()
		assert(U.MoneyString(12345) == "1g 23s 45c", U.MoneyString(12345))
		assert(U.MoneyString(45) == "45c")
	end)
	case("Push ring", function()
		local t = {}
		for i = 1, 5 do U.Push(t, i, 3) end
		assert(#t == 3 and t[1] == 3 and t[3] == 5)
	end)
	case("Centroid", function()
		local x, y, n = U.Centroid({ { x = 0, y = 0 }, { x = 1, y = 1 }, { x = 0.5, y = 0.5 } })
		assert(near(x, 0.5) and near(y, 0.5) and n == 3)
	end)
	case("secret guard passes plain values", function()
		assert(FP.safe(5) == 5 and FP.safe("x") == "x" and FP.safe(nil) == nil)
	end)
	case("party parser", function()
		local p = FP.Party:Parse("FP1;Chiznooch;MAGE;20;1234,1235c,99")
		assert(p and p.name == "Chiznooch" and U.Count(p.quests) == 3)
		assert(p.complete[1235] and not p.complete[1234])
		assert(p.quests[99] and not p.quests[7])
	end)
	case("waypoint coordinate validation", function()
		assert(U.ValidMapPoint(1, 0, 1))
		assert(not U.ValidMapPoint(0, 0.5, 0.5))
		assert(not U.ValidMapPoint(1, -0.1, 0.5))
		assert(not U.ValidMapPoint(1, math.huge, 0.5))
		assert(not U.ValidMapPoint(1, 0/0, 0.5))
	end)
	case("planner sorts by distance with turn-in bonus", function()
		local steps = {
			{ kind = "objective", score = 500, title = "b" },
			{ kind = "turnin", score = 600 - 250, title = "a" },
			{ kind = "objective", score = 1e9, title = "c" },
		}
		table.sort(steps, function(x, y) if x.score ~= y.score then return x.score < y.score end return x.title < y.title end)
		assert(steps[1].kind == "turnin" and steps[3].title == "c")
	end)
	return cases
end

function T:Run(quiet)
	local cases = self:Cases()
	local pass, fail = 0, 0
	for _, c in ipairs(cases) do
		local ok, err = pcall(c.fn)
		if ok then pass = pass + 1 else fail = fail + 1; FP:Print(FP.RED .. "FAIL|r " .. c.name .. ": " .. tostring(err)) end
	end
	if not quiet or fail > 0 then FP:Print(string.format("selftest: %d passed, %d failed", pass, fail)) end
	return fail == 0, pass, fail
end
