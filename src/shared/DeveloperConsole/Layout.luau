--!strict
-- Input dimensions are already reduced by ScreenGui.DeviceSafeInsets.
local Layout = {}
function Layout.measure(width: number, height: number): any
	local w = math.max(1, math.min(740, width - 16))
	local h = math.max(1, math.min(740, height - 16))
	return {
		width = w,
		height = h,
		x = math.max(0, width - w - 16),
		y = math.max(0, (height - h) / 2),
		compact = h < 560,
	}
end
return Layout
