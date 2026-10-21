--!nocheck
local T = require("./runner/T")
local Loader = require("./runner/Loader")
local describe, it, expect = T.describe, T.it, T.expect

local Products = Loader.require(Loader.Shared.Config.Products)
local Profile = Loader.require(Loader.Shared.Progression.Profile)
local ok, Monetization = pcall(Loader.require, Loader.Server.Data.Receipts)

describe("Receipts", function()
	if not ok then
		it("loads Receipts", function()
			error(Monetization)
		end)
		return
	end
	local Decision = Loader.roblox.Enum.ProductPurchaseDecision

	local function setup(saveWorks)
		Products.Enabled = true
		Products.CoinPacks[1].productId = 111
		local player = { UserId = 7 }
		local data = Profile.new(0)
		local saves, granted = 0, 0
		local deps = {
			getPlayer = function(id)
				return if id == 7 then player else nil
			end,
			getProfile = function()
				return data
			end,
			save = function()
				saves += 1
				return saveWorks()
			end,
			onGranted = function()
				granted += 1
			end,
		}
		return data, deps, function()
			return saves, granted
		end
	end
	local function teardown()
		Products.Enabled = false
		Products.CoinPacks[1].productId = nil
	end

	it("grants once and acknowledges duplicates", function()
		local data, deps, counts = setup(function()
			return true
		end)
		local receipt = { PlayerId = 7, ProductId = 111, PurchaseId = "p-1" }
		expect(Monetization.process(receipt, deps)).toBe(Decision.PurchaseGranted)
		expect(Monetization.process(receipt, deps)).toBe(Decision.PurchaseGranted)
		expect(data.coins).toBe(Products.CoinPacks[1].coins)
		local saves, granted = counts()
		expect(saves).toBe(1)
		expect(granted).toBe(1)
		teardown()
	end)

	it("rolls back and retries later when the save fails", function()
		local works = false
		local data, deps = setup(function()
			return works
		end)
		local receipt = { PlayerId = 7, ProductId = 111, PurchaseId = "p-2" }
		expect(Monetization.process(receipt, deps)).toBe(Decision.NotProcessedYet)
		expect(data.coins).toBe(0)
		expect(Profile.hasReceipt(data, "p-2")).toBe(false)
		works = true
		expect(Monetization.process(receipt, deps)).toBe(Decision.PurchaseGranted)
		expect(data.coins).toBe(Products.CoinPacks[1].coins)
		teardown()
	end)

	it("waits for the player to be in a server", function()
		local _, deps = setup(function()
			return true
		end)
		local receipt = { PlayerId = 99, ProductId = 111, PurchaseId = "p-3" }
		expect(Monetization.process(receipt, deps)).toBe(Decision.NotProcessedYet)
		teardown()
	end)

	it("never grants unknown or disabled products", function()
		local data, deps = setup(function()
			return true
		end)
		expect(Monetization.process({ PlayerId = 7, ProductId = 555, PurchaseId = "p-4" }, deps)).toBe(
			Decision.NotProcessedYet
		)
		Products.Enabled = false
		expect(Monetization.process({ PlayerId = 7, ProductId = 111, PurchaseId = "p-5" }, deps)).toBe(
			Decision.NotProcessedYet
		)
		expect(data.coins).toBe(0)
		teardown()
	end)
end)
