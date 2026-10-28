-- Pure layout policy, shared with the viewport regression tests.
local Layout = {}
function Layout.calculate(viewWidth, viewHeight)
	local width = math.max(100,math.min(1040,viewWidth-24))
	local height = math.max(100,math.min(720,viewHeight-20))
	local compact = height < 510 and width >= 520
	local narrow = width < 640
	local top = if compact then 108 elseif narrow then 286 else 224
	local gap = if compact then 12 else 18
	local contentWidth = width-28
	local minCardWidth = if compact then 260 else 280
	local columns = math.max(1,math.min(3,math.floor((contentWidth-36+gap)/(minCardWidth+gap))))
	return {width = width,height = height,compact = compact,narrow = narrow,top = top,gap = gap,
		columns = columns,cardWidth = math.floor((contentWidth-36-(columns-1)*gap)/columns),
		cardHeight = if compact then 180 else 264,
		bodyText = if compact then 14 else 16,titleText = if compact then 18 else 20,
		metadataText = if compact then 12 else 13,
		sheetWidth = math.min(600,width-24),sheetHeight = math.min(620,height-16)}
end
return Layout
