-- Shared visual interface with injected local or server-authoritative state.
return function(data,settings)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")
local Protocol=require(settings.shared.Protocol)
local Layout = require(settings.shared.ResponsiveLayout)
local currentLayout = Layout.calculate(1064,740)
local player = Players.LocalPlayer
local Categories=Protocol.Categories
local function paperIndex(note)
	if type(note.id)=="number" then return (note.id-1)%5+1 end
	local value=0;local id=tostring(note.id);for i=1,#id do value=(value+id:byte(i))%5 end;return value+1
end
local C = {ink = Color3.fromRGB(53, 61, 55), muted = Color3.fromRGB(109, 112, 96), cream = Color3.fromRGB(255, 250, 234), green = Color3.fromRGB(55, 104, 84), border = Color3.fromRGB(220, 208, 177), cork = Color3.fromRGB(185, 139, 90)}
local papers = {Color3.fromRGB(255, 232, 148), Color3.fromRGB(255, 198, 182), Color3.fromRGB(207, 225, 188), Color3.fromRGB(203, 220, 240), Color3.fromRGB(230, 208, 240)}
local function make(class, parent, props)
	local obj = Instance.new(class)
	for k, v in pairs(props or {}) do obj[k] = v end
	obj.Parent = parent
	return obj
end
local function round(obj, radius) make("UICorner", obj, {CornerRadius = UDim.new(0, radius or 10)}) end
local function stroke(obj, color, width) return make("UIStroke", obj, {Color = color or C.border, Thickness = width or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}) end
local function text(parent, value, size, pos, dim, color, bold)
	return make("TextLabel", parent, {Text = value, TextSize = size, Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham, TextColor3 = color or C.ink, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, BackgroundTransparency = 1, Position = pos, Size = dim, RichText = false, BorderSizePixel = 0})
end
local function button(parent, value, pos, dim, callback, bg, fg)
	local b = make("TextButton", parent, {Text = value, TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = fg or C.ink, BackgroundColor3 = bg or C.cream, Position = pos, Size = dim, BorderSizePixel = 0, AutoButtonColor = false, Selectable = true})
	round(b, 9)
	local hoverScale = make("UIScale",b,{Scale = 1})
	local function hover(on) TweenService:Create(hoverScale, TweenInfo.new(0.12), {Scale = if on then 1.018 else 1}):Play() end
	b.MouseEnter:Connect(function() hover(true) end)
	b.MouseLeave:Connect(function() hover(false) end)
	b.SelectionGained:Connect(function() hover(true) end)
	b.SelectionLost:Connect(function() hover(false) end)
	b.Activated:Connect(callback)
	return b
end
local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), {Name = "FeedbackUI", ResetOnSpawn = false, DisplayOrder = 20, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets})
local hud = make("Frame", gui, {Name = "FeedbackNotice", AnchorPoint = Vector2.new(.5, 1), Position = UDim2.new(.5, 0, 1, -12), Size = UDim2.fromOffset(342, 54), BackgroundColor3 = C.green, BorderSizePixel = 0})
hud.Visible = settings.hudEnabled ~= false
round(hud, 14)
text(hud, "THE COMMUNITY CORNER", 13, UDim2.fromOffset(16, 5), UDim2.new(1, -32, 0, 21), C.cream, true)
text(hud, settings.hudText or "Walk to the board · Read and share ideas", 11, UDim2.fromOffset(16, 27), UDim2.new(1, -32, 0, 18), C.cream)
local veil = make("Frame", gui, {Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(23, 35, 30), BackgroundTransparency = .24, BorderSizePixel = 0, Visible = false, Active = true})
local panel = make("Frame", veil, {Name = "BoardMenu", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(1040, 690), BackgroundColor3 = C.cream, BorderSizePixel = 0, ClipsDescendants = true})
round(panel, 20)
stroke(panel, Color3.fromRGB(122, 85, 54), 5)
make("UIGradient", panel, {Color = ColorSequence.new(C.cream, Color3.fromRGB(241, 233, 211)), Rotation = 90})
local header = make("Frame", panel, {Size = UDim2.new(1,0,0,105), BackgroundColor3 = C.green, BorderSizePixel = 0})
header.Name = "Header"
text(header, "THE COMMUNITY CORNER", 11, UDim2.fromOffset(24, 12), UDim2.new(1,-90,0,18), Color3.fromRGB(205, 224, 188), true)
local title = text(header, "Player feedback", 32, UDim2.fromOffset(24, 34), UDim2.new(1,-90,0,39), C.cream, true)
text(header, "Little notes. Big ideas. A better game, together.", 12, UDim2.fromOffset(24, 77), UDim2.new(1,-40,0,20), C.cream)
local closeMenu, render, openForm, openNote
local close = button(header, "×", UDim2.new(1,-64,0,20), UDim2.fromOffset(44,44), function() closeMenu() end, Color3.fromRGB(76, 126, 101), C.cream)
close.TextSize = 28
local notice = make("Frame", panel, {Position = UDim2.fromOffset(14,116), Size = UDim2.new(1,-28,0,32), BackgroundColor3 = Color3.fromRGB(247, 222, 160), BorderSizePixel = 0})
round(notice, 7)
text(notice, settings.banner or "Player feedback", 11, UDim2.fromOffset(10,0), UDim2.new(1,-20,1,0), C.ink, true)
local tabs = make("Frame", panel, {Position = UDim2.fromOffset(14,158), Size = UDim2.new(1,-28,0,42), BackgroundTransparency = 1})
tabs.Name = "SortingControls"
local tabButtons = {}
for i, mode in ipairs({"Newest", "Oldest", "Most supported"}) do
	tabButtons[i] = button(tabs, mode, UDim2.fromOffset((i-1)*116,0), UDim2.fromOffset(110,40), function()
		data:setSort(mode);task.spawn(function()data:refresh()end);render()
	end)
end
local add = button(panel, "+  Write a note", UDim2.new(1,-174,0,158), UDim2.fromOffset(160,40), function() openForm() end, C.green, C.cream)
add.Name = "WriteNote"
local countLabel = text(panel, "", 11, UDim2.fromOffset(18,207), UDim2.new(1,-36,0,20), C.muted)
local scroll = make("ScrollingFrame", panel, {Name = "Notes", Active = true, Position = UDim2.fromOffset(14,236), Size = UDim2.new(1,-28,1,-276), BackgroundColor3 = C.cork, BorderSizePixel = 0, ScrollBarThickness = 5, ScrollBarImageColor3 = C.green, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y})
round(scroll, 10)
make("UIPadding", scroll, {PaddingTop = UDim.new(0,16), PaddingLeft = UDim.new(0,14), PaddingRight = UDim.new(0,14), PaddingBottom = UDim.new(0,18)})
local grid = make("UIGridLayout", scroll, {CellPadding = UDim2.fromOffset(16,16), CellSize = UDim2.fromOffset(230,224), SortOrder = Enum.SortOrder.LayoutOrder})
local footer = text(panel, "Made for players, by players.", 10, UDim2.new(0,18,1,-31), UDim2.new(1,-36,0,24), C.muted)
local toast = text(panel, "", 12, UDim2.new(0,18,1,-31), UDim2.new(1,-36,0,24), C.green, true)
toast.BackgroundColor3 = C.cream
toast.Visible = false
local toastVersion = 0
local function notify(message)
	toastVersion += 1
	local version = toastVersion
	toast.Text = message; toast.Visible = true; toast.BackgroundTransparency = 0
	task.delay(4, function() if version == toastVersion then toast.Visible = false end end)
end
local modal = make("Frame", panel, {Name = "ModalShade", Size = UDim2.fromScale(1,1), BackgroundColor3 = C.ink, BackgroundTransparency = .22, ZIndex = 10, Visible = false, Active = true})
modal.SelectionGroup = true
modal.SelectionBehaviorUp = Enum.SelectionBehavior.Stop
modal.SelectionBehaviorDown = Enum.SelectionBehavior.Stop
modal.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop
modal.SelectionBehaviorRight = Enum.SelectionBehavior.Stop
local sheet = make("Frame", modal, {Name = "NoteSheet", AnchorPoint = Vector2.new(.5,.5), Position = UDim2.fromScale(.5,.5), Size = UDim2.fromOffset(520,510), BackgroundColor3 = C.cream, BorderSizePixel = 0})
round(sheet,16)
stroke(sheet,C.border,2)
local modalTitle = text(sheet, "", 25, UDim2.fromOffset(24,22), UDim2.new(1,-90,0,38), C.ink,true)
modalTitle.TextScaled = true
make("UITextSizeConstraint",modalTitle,{MinTextSize = 12,MaxTextSize = 25})
local bodyViewport = make("ScrollingFrame",sheet,{Name = "SheetContent",Active = true,Position = UDim2.fromOffset(22,74),Size = UDim2.new(1,-44,1,-102),BackgroundTransparency = 1,BorderSizePixel = 0,ScrollBarThickness = 5,ScrollBarImageColor3 = C.green,CanvasSize = UDim2.new(),AutomaticCanvasSize = Enum.AutomaticSize.Y,ScrollingDirection = Enum.ScrollingDirection.Y})
local body = make("Frame", bodyViewport, {Size = UDim2.new(1,-12,0,430), BackgroundTransparency = 1})
local sheetHint = text(sheet,"Scroll to read more and reach the actions ↓",12,UDim2.new(0,24,1,-25),UDim2.new(1,-48,0,18),C.muted)
local oldSelection, modalSelection, modalNoteId, modalRevision
local function dismissModal()
	modal.Visible = false
	modalNoteId=nil
	if UIS.GamepadEnabled then GuiService.SelectedObject = if modalSelection and modalSelection.Parent then modalSelection else add end
end
button(sheet,"×",UDim2.new(1,-62,0,20),UDim2.fromOffset(40,40),dismissModal)
local function beginModal(heading)
	modalSelection = GuiService.SelectedObject
	modalNoteId=nil
	body:ClearAllChildren(); modalTitle.Text = heading; modal.Visible = true
	bodyViewport.CanvasPosition = Vector2.zero
end
local function date(timestamp) return os.date("!%b %d, %Y",timestamp) end
openNote = function(note)
	beginModal("A note from " .. note.author)
	modalNoteId=note.id;modalRevision=note.revision
	sheet.BackgroundColor3 = papers[paperIndex(note)]
	text(body,note.category .. "  •  " .. date(note.timestamp),13,UDim2.fromOffset(0,0),UDim2.new(1,0,0,32),C.muted,true).TextWrapped = true
	local heading = text(body,note.title,23,UDim2.fromOffset(0,37),UDim2.new(1,0,0,62),C.ink,true); heading.TextWrapped = true
	-- One scrolling surface: nested message scrollers intercepted touch swipes.
	local messageScroll = make("Frame",body,{Name="MessageBody",Position = UDim2.fromOffset(0,112),Size = UDim2.new(1,0,0,152),BackgroundTransparency = 1,BorderSizePixel = 0})
	local message = text(messageScroll,note.message,18,UDim2.new(),UDim2.new(1,-14,0,0)); message.AutomaticSize = Enum.AutomaticSize.Y; message.TextWrapped = true; message.TextYAlignment = Enum.TextYAlignment.Top; message.LineHeight = 1.15
	local support
	local reasonIndex=4
	local reasonButton
	reasonButton=button(body,"Report reason: "..Protocol.Reasons[reasonIndex],UDim2.fromOffset(0,276),UDim2.new(1,0,0,44),function()
		reasonIndex=reasonIndex%#Protocol.Reasons+1;reasonButton.Text="Report reason: "..Protocol.Reasons[reasonIndex]
	end)
	local function fitMessage()
  if not message.Parent then return end
  local height=math.max(152,math.ceil(message.TextBounds.Y))
  messageScroll.Size=UDim2.new(1,0,0,height)
  reasonButton.Position=UDim2.fromOffset(0,112+height+12)
  body.Size=UDim2.new(1,-12,0,112+height+166)
 end
 message:GetPropertyChangedSignal("TextBounds"):Connect(fitMessage)
 task.defer(fitMessage)
	if data.staff then
		support=button(body,"Hide note",UDim2.new(0,0,1,-100),UDim2.new(.6,-6,0,44),function()
			local ok,reason=data:hide(note,Protocol.Reasons[reasonIndex]);if ok then dismissModal();notify("Hide confirmed by the server.");task.spawn(function()data:refresh()end) else notify(reason) end
		end,C.green,C.cream)
		button(body,"Review reports",UDim2.new(.6,6,1,-100),UDim2.new(.4,-6,0,44),function()
			local result=data.request("ReviewReports",{id=note.id})
			if result.ok then local summary={};for _,code in ipairs(Protocol.Reasons) do table.insert(summary,code..": "..(result.data.reasons[code] or 0)) end;message.Text=table.concat(summary,"\n") else notify(result.message or "Report review unavailable.") end
		end)
		text(body,"Server-authorized developer view · Hide is recorded in the audit.",11,UDim2.new(0,0,1,-45),UDim2.new(1,0,0,40),C.muted).TextWrapped=true
		if UIS.GamepadEnabled then GuiService.SelectedObject=support end
		return
	end
	support = button(body,"",UDim2.new(0,0,1,-100),UDim2.new(.6,-6,0,44),function()
		local ok,reason=data:toggle(note);if ok==false then notify(reason);return end
		support.Text = (if note.supported then "👍  Supported · " else "👍  Support · ") .. note.supports; render()
	end,C.green,C.cream)
	support.Text = (if note.supported then "👍  Supported · " else "👍  Support · ") .. note.supports
	local report
	report = button(body,if note.reported then "Reported" else "Report",UDim2.new(.6,6,1,-100),UDim2.new(.4,-6,0,44),function()
		local ok,reason=data:report(note,Protocol.Reasons[reasonIndex]);if not ok then notify(reason);return end
		report.Text="Reported";notify("Report stored for developer review.")
	end)
	if note.reported then report.Text="Reported" end
	text(body,"Your reaction is confirmed by the server. Public totals may update later.",11,UDim2.new(0,0,1,-45),UDim2.new(1,0,0,40),C.muted).TextWrapped = true
	if UIS.GamepadEnabled then GuiService.SelectedObject = support end
end
local draft, categoryIndex = "", 2
openForm = function()
	beginModal("Pin a little idea")
	sheet.BackgroundColor3 = C.cream
	text(body,"Choose a category",12,UDim2.fromOffset(0,0),UDim2.new(1,0,0,20),C.muted,true)
	local category
	category = button(body,Categories[categoryIndex] .. "  ›",UDim2.fromOffset(0,27),UDim2.new(1,0,0,44),function()
		categoryIndex = categoryIndex % #Categories + 1; category.Text = Categories[categoryIndex] .. "  ›"
	end,Color3.fromRGB(234,230,209))
	local input = make("TextBox",body,{Name = "MessageInput",Text = draft,PlaceholderText = "What would make this game even better?",ClearTextOnFocus = false,MultiLine = true,TextWrapped = true,TextXAlignment = Enum.TextXAlignment.Left,TextYAlignment = Enum.TextYAlignment.Top,Font = Enum.Font.Gotham,TextSize = 16,TextColor3 = C.ink,PlaceholderColor3 = C.muted,BackgroundColor3 = Color3.fromRGB(255,243,198),BorderSizePixel = 0,Position = UDim2.fromOffset(0,84),Size = UDim2.new(1,0,1,-220)})
	round(input,10); stroke(input,C.border)
	make("UIPadding",input,{PaddingTop = UDim.new(0,14),PaddingBottom = UDim.new(0,14),PaddingLeft = UDim.new(0,14),PaddingRight = UDim.new(0,14)})
	local counter = text(body,"",12,UDim2.new(0,0,1,-130),UDim2.new(1,0,0,22),C.muted); counter.TextXAlignment = Enum.TextXAlignment.Right
	local errorLabel = text(body,"",11,UDim2.new(0,0,1,-105),UDim2.new(1,0,0,30),Color3.fromRGB(169,66,51)); errorLabel.TextWrapped = true
	local function update()
		draft = input.Text
		errorLabel.Text = ""
		local length = utf8.len(draft)
		counter.Text = (if length then tostring(length) else "Invalid text") .. " / 300"
		counter.TextColor3 = if not length or length > 300 then Color3.fromRGB(169,66,51) else C.muted
	end
	input:GetPropertyChangedSignal("Text"):Connect(update); update()
	button(body,"Cancel",UDim2.new(0,0,1,-64),UDim2.new(.32,-6,0,44),dismissModal,Color3.fromRGB(234,230,209))
	button(body,"Submit to server  ↗",UDim2.new(.32,6,1,-64),UDim2.new(.68,-6,0,44),function()
		local note, reason = data:submit(Categories[categoryIndex],input.Text,player.DisplayName,os.time())
		if not note then errorLabel.Text = reason; return end
		draft = ""; data.sort = "Newest"; dismissModal(); render(); scroll.CanvasPosition = Vector2.zero
		notify(if data.testMode then "Server accepted this test note. Memory storage resets when Play stops." elseif note.pendingListing then "Saved. Listing is still updating." else "Server confirmed successful storage.")
		if data.backend then task.spawn(function()data:refresh(true)end) end
	end,C.green,C.cream)
	text(body,"Draft stays here if the server cannot confirm storage.",10,UDim2.new(0,0,1,-16),UDim2.new(1,0,0,18),C.muted)
	if UIS.GamepadEnabled then GuiService.SelectedObject = category end
end
render = function()
	local q = currentLayout
	local compact = q.compact
	local selectedId
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(scroll) then selectedId = selected:GetAttribute("NoteId") end
	for _, child in ipairs(scroll:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
	for _, tab in ipairs(tabButtons) do
		tab.BackgroundColor3 = if tab.Text == data.sort then C.green else Color3.fromRGB(234,230,209)
		tab.TextColor3 = if tab.Text == data.sort then C.cream else C.ink
	end
	countLabel.Text = if data.status~="" then data.status else #data.notes .. " notes on this page / tap a note to read"
	local blank = button(scroll,"",UDim2.new(),UDim2.new(),openForm,Color3.fromRGB(239,216,166))
	blank.Name = "WriteSlot"; blank.LayoutOrder = 0; stroke(blank,Color3.fromRGB(141,105,67),2)
	text(blank,"+",if compact then 34 else 48,UDim2.fromOffset(20,if compact then 12 else 30),UDim2.new(1,-40,0,50),C.green,true)
	text(blank,"Your idea goes here",if compact then 17 else 20,UDim2.fromOffset(20,if compact then 63 else 116),UDim2.new(1,-40,0,48),C.ink,true).TextWrapped = true
	text(blank,"Big or small, we're listening.\nPin a new note  ↗",if compact then 13 else 15,UDim2.fromOffset(20,if compact then 116 else 180),UDim2.new(1,-40,0,48),C.muted).TextWrapped = true
	for i, note in ipairs(data:list(data.sort)) do
		local card = button(scroll,"",UDim2.new(),UDim2.new(),function() openNote(note) end,papers[paperIndex(note)])
		card.Name = "Note_" .. note.id; card:SetAttribute("NoteId",note.id); card.LayoutOrder = i; round(card,3)
		make("UIGradient",card,{Color = ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(226,221,203)),Rotation = 90})
		local tape = make("Frame",card,{AnchorPoint = Vector2.new(.5,0),Position = UDim2.new(.5,0,0,5),Size = UDim2.fromOffset(58,13),BackgroundColor3 = C.cream,BackgroundTransparency = .42,BorderSizePixel = 0,Rotation = if i%2 == 0 then 4 else -4})
		text(card,string.upper(note.category),if compact then 11 else 12,UDim2.fromOffset(18,if compact then 16 else 28),UDim2.new(1,-36,0,18),C.muted,true)
		local noteTitle = text(card,note.title,q.titleText,UDim2.fromOffset(18,if compact then 36 else 52),UDim2.new(1,-36,0,if compact then 38 else 50),C.ink,true); noteTitle.Name = "Title"; noteTitle.TextWrapped = true; noteTitle.TextTruncate = Enum.TextTruncate.AtEnd
		local preview = text(card,note.message,q.bodyText,UDim2.fromOffset(18,if compact then 78 else 111),UDim2.new(1,-36,0,if compact then 34 else 73)); preview.Name = "MessagePreview"; preview.TextWrapped = true; preview.TextYAlignment = Enum.TextYAlignment.Top; preview.TextTruncate = Enum.TextTruncate.AtEnd; preview.LineHeight = 1.1
		local author = text(card,note.author,q.metadataText,UDim2.fromOffset(18,if compact then 121 else 201),UDim2.new(1,-36,0,20),C.ink,true); author.TextTruncate = Enum.TextTruncate.AtEnd
		text(card,date(note.timestamp),q.metadataText,UDim2.fromOffset(18,if compact then 148 else 231),UDim2.new(.65,-18,0,20),C.muted)
		local reactions = text(card,"👍 " .. note.supports,q.metadataText,UDim2.new(.65,0,0,if compact then 148 else 231),UDim2.new(.35,-18,0,20),C.green,true); reactions.TextXAlignment = Enum.TextXAlignment.Right
		if note.id == selectedId and not modal.Visible then GuiService.SelectedObject = card end
	end
	local lastBlank = button(scroll,if data.nextCursor then "Next page  →" else "+  There is room for your idea",UDim2.new(),UDim2.new(),function()
		if data.nextCursor then data:nextPage();task.spawn(function()data:refresh()end) else openForm() end
	end,Color3.fromRGB(239,216,166))
	lastBlank.Name = "LastWriteSlot"; lastBlank.LayoutOrder = 1000; lastBlank.TextWrapped = true; stroke(lastBlank,Color3.fromRGB(141,105,67),2)
	if data.moderator then
		local staff=button(scroll,if data.staff then "Return to public board" else "Developer review",UDim2.new(),UDim2.new(),function()
			data.staff=not data.staff;data.generation+=1;data.reportedOnly=nil;data.archived=nil;data.category=nil;data.pageCursor=nil;data:clear("Loading…");task.spawn(function()data:refresh()end)
		end,C.green,C.cream);staff.LayoutOrder=1001
		if data.staff then
			local reports=button(scroll,if data.reportedOnly then "Show all notes" else "Reported notes",UDim2.new(),UDim2.new(),function()
				data.reportedOnly=not data.reportedOnly;data.generation+=1;data.pageCursor=nil;data:clear("Loading reports…");task.spawn(function()data:refresh()end)
			end);reports.LayoutOrder=1002
			local archive=button(scroll,if data.archived then "Show current notes" else "Private archive",UDim2.new(),UDim2.new(),function()
				data.archived=not data.archived;data.generation+=1;data.pageCursor=nil;data:clear("Loading archive…");task.spawn(function()data:refresh()end)
			end);archive.LayoutOrder=1003
			local category=button(scroll,"Category: "..(data.category or "All"),UDim2.new(),UDim2.new(),function()
				local index=if data.category then table.find(Categories,data.category) or 0 else 0
				data.category=Categories[index+1];data.generation+=1;data.pageCursor=nil;data:clear("Loading category…");task.spawn(function()data:refresh()end)
			end);category.LayoutOrder=1004
			local stats=data.stats
			if stats then countLabel.Text=string.format("Active %d · Hidden %d · Archived %d · Reported %d (derived)",stats.active,stats.hidden,stats.archived,stats.reported) end
		end
	end
end
local prompt=settings.prompt or workspace:FindFirstChild("FeedbackPrompt",true)
if not prompt then warn("[FeedbackUI] Configured board prompt is unavailable.");gui:Destroy();return end
local originalMouseBehavior, originalMouseIcon
local originalPlayerList
closeMenu = function()
	dismissModal(); veil.Visible = false; hud.Visible = settings.hudEnabled ~= false; prompt.Enabled = true
	CAS:UnbindAction("FeedbackClose"); CAS:UnbindAction("FeedbackMovement")
	if settings.onClose then settings.onClose() end
	UIS.MouseBehavior = originalMouseBehavior or Enum.MouseBehavior.Default
	if originalMouseIcon ~= nil then UIS.MouseIconEnabled = originalMouseIcon end
	if originalPlayerList ~= nil then pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,originalPlayerList) end) end
	GuiService.SelectedObject = if oldSelection and oldSelection.Parent then oldSelection else nil
end
local function openMenu()
	if veil.Visible then return end
	if settings.canOpen and not settings.canOpen() then return end
	if settings.onOpen then settings.onOpen() end
	oldSelection = GuiService.SelectedObject
	originalMouseBehavior = UIS.MouseBehavior; originalMouseIcon = UIS.MouseIconEnabled
	pcall(function()
		originalPlayerList = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false)
	end)
	UIS.MouseBehavior = Enum.MouseBehavior.Default; UIS.MouseIconEnabled = true
	prompt.Enabled = false; veil.Visible = true; hud.Visible = false; render()
	panel.Position = UDim2.new(.5,0,.5,14)
	TweenService:Create(panel,TweenInfo.new(.22,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position = UDim2.fromScale(.5,.5)}):Play()
	CAS:BindActionAtPriority("FeedbackMovement",function() return Enum.ContextActionResult.Sink end,false,3000,Enum.PlayerActions.CharacterForward,Enum.PlayerActions.CharacterBackward,Enum.PlayerActions.CharacterLeft,Enum.PlayerActions.CharacterRight,Enum.PlayerActions.CharacterJump)
	CAS:BindActionAtPriority("FeedbackClose",function(_,state)
		if state == Enum.UserInputState.Begin then if modal.Visible then dismissModal() else closeMenu() end end
		return Enum.ContextActionResult.Sink
	end,false,3001,Enum.KeyCode.ButtonB)
	if UIS.GamepadEnabled then GuiService.SelectedObject = add end
	if data.backend then task.spawn(function()data:capabilities();data:refresh(true)end) end
end
prompt.Triggered:Connect(function(who) if who == nil or who == player then openMenu() end end)
player.CharacterAdded:Connect(function() if veil.Visible then closeMenu() end end)
if settings.bindClose then settings.bindClose(function() if veil.Visible then closeMenu() end end) end
local function resize()
	local size = veil.AbsoluteSize
	if size.X < 100 or size.Y < 100 then return end
	local q = Layout.calculate(size.X,size.Y)
	local changed = q.compact ~= currentLayout.compact or q.columns ~= currentLayout.columns
	currentLayout = q
	panel.Size = UDim2.fromOffset(q.width,q.height)
	local compact, narrow = q.compact,q.narrow
	header.Size = UDim2.new(1,0,0,if compact then 48 else 105)
	title.Position = UDim2.fromOffset(if compact then 16 else 24,if compact then 8 else 34)
	title.Size = if compact then UDim2.fromOffset(210,32) else UDim2.new(1,-90,0,39)
	title.TextSize = if compact then 25 elseif narrow then 26 else 32
	title.TextWrapped = false
	for _, label in ipairs(header:GetChildren()) do
		if label:IsA("TextLabel") and label ~= title then label.Visible = not compact end
	end
	close.Position = UDim2.new(1,if compact then -54 else -64,0,if compact then 2 else 20)
	close.Size = UDim2.fromOffset(44,44)
	notice.Position = if compact then UDim2.fromOffset(238,8) else UDim2.fromOffset(14,116)
	notice.Size = if compact then UDim2.new(1,-302,0,32) else UDim2.new(1,-28,0,if narrow then 44 else 32)
	local label = notice:FindFirstChildOfClass("TextLabel")
	label.Text = settings.banner or "Player feedback"
	label.TextSize = 12; label.TextWrapped = true
	tabs.Position = UDim2.fromOffset(14,if compact then 56 elseif narrow then 170 else 158)
	tabs.Size = UDim2.new(1,if compact then -202 else -28,0,44)
	local tabWidth = if compact then math.min(118,math.floor((q.width-212)/3)) elseif narrow then math.floor((q.width-44)/3) else 116
	for i,b in ipairs(tabButtons) do
		b.Position = UDim2.fromOffset((i-1)*(tabWidth+6),0)
		b.Size = UDim2.fromOffset(tabWidth,44)
		b.TextSize = if tabWidth < 106 then 12 else 14
	end
	add.Position = if compact then UDim2.new(1,-182,0,56) elseif narrow then UDim2.fromOffset(14,220) else UDim2.new(1,-182,0,158)
	add.Size = if narrow and not compact then UDim2.new(1,-28,0,44) else UDim2.fromOffset(168,44)
	countLabel.Visible = not compact; footer.Visible = not compact
	countLabel.Position = UDim2.fromOffset(18,q.top-24); countLabel.TextSize = 12
	scroll.Position = UDim2.fromOffset(14,q.top)
	scroll.Size = UDim2.new(1,-28,1,-q.top-(if compact then 10 else 36))
	scroll.ScrollBarThickness = if UIS.TouchEnabled then 7 else 6
	local padding = scroll:FindFirstChildOfClass("UIPadding")
	padding.PaddingTop = UDim.new(0,if compact then 8 else 16)
	padding.PaddingBottom = UDim.new(0,if compact then 8 else 18)
	grid.CellPadding = UDim2.fromOffset(q.gap,q.gap)
	grid.CellSize = UDim2.fromOffset(q.cardWidth,q.cardHeight)
	sheet.Size = UDim2.fromOffset(q.sheetWidth,q.sheetHeight)
	local oldScale = sheet:FindFirstChildOfClass("UIScale")
	if oldScale then oldScale:Destroy() end
	sheetHint.Visible = q.sheetHeight < 550
	toast.Position = UDim2.new(0,18,1,-(if compact then 48 else 31))
	toast.Size = UDim2.new(1,-36,0,if compact then 38 else 24); toast.TextWrapped = true
	hud.Size = UDim2.fromOffset(math.min(342,size.X-24),54)
	hud.AnchorPoint = if UIS.TouchEnabled then Vector2.new(.5,0) else Vector2.new(.5,1)
	hud.Position = if UIS.TouchEnabled then UDim2.new(.5,0,0,8) else UDim2.new(.5,0,1,-12)
	if changed and render then render() end
end
veil:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
resize(); render()
if data.backend then
	footer.Text=settings.footer or "Made for players, by players."
	data.onChanged=function()
		if modalNoteId then
			local fresh
			for _,note in ipairs(data.notes) do if note.id==modalNoteId then fresh=note;break end end
			if not fresh or fresh.revision~=modalRevision then dismissModal() end
		end
		render()
	end
	task.spawn(function()
		local last=0
		while gui.Parent do
			task.wait(.25);data:expire()
			if veil.Visible and os.clock()-last>=4 and not data.refreshing then last=os.clock();task.spawn(function()data:refresh()end) end
		end
	end)
	if settings.network then settings.network.Invalidation.OnClientEvent:Connect(function(message)
		if type(message)~="table" then return end
		for _,note in ipairs(data.notes) do
			if note.id==message.id and type(message.revision)=="number" and message.revision>note.revision then
				data.generation+=1;data:clear("Feedback changed. Revalidating…");break
			end
		end
	end) end
end
if settings.hudDistance then
 task.spawn(function()
  while gui.Parent and prompt.Parent do
   local character=player.Character;local root=character and character:FindFirstChild("HumanoidRootPart")
   hud.Visible=settings.hudEnabled~=false and not veil.Visible and root~=nil and (root.Position-prompt.Parent.Position).Magnitude<=settings.hudDistance
   task.wait(.25)
  end
 end)
end
print("[FeedbackUI] Ready: server-authoritative feedback interface")
end
