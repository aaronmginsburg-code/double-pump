local T = require("./runner/T")
local Identity = require("../../overrides/DevelopmentIdentity")
T.describe("Development-only skin access", function()
	T.it("allows the exact private development destination", function()
		T.expect(Identity.allowed(10772492892, 139437092998076)).toBe(true)
	end)
	for _, ids in
		{ { 10772275012, 82505574993280 }, { 10772492892, 82505574993280 }, { 10772275012, 139437092998076 }, { 0, 0 } }
	do
		T.it("refuses universe " .. ids[1] .. " place " .. ids[2], function()
			T.expect(Identity.allowed(ids[1], ids[2])).toBe(false)
		end)
	end
end)
