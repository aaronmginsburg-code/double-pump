-- Stable identity fixture for imported rigs. Lune 0.8.9 creates fresh Bone userdata
-- wrappers on traversal; those cannot faithfully model Roblox Instance table keys.
local R = require("@lune/roblox")
local M, methods = {}, {}
local mt = {
	__index = function(self, key)
		if methods[key] then
			return methods[key]
		end
		if self.props[key] ~= nil then
			return self.props[key]
		end
		for _, child in self.children do
			if child.Name == key then
				return child
			end
		end
		return nil
	end,
	__newindex = function(self, key, value)
		if key == "Parent" then
			local previous = self.props.Parent
			if previous then
				local index = table.find(previous.children, self)
				if index then
					table.remove(previous.children, index)
				end
			end
			if value then
				table.insert(value.children, self)
			end
		end
		self.props[key] = value
	end,
}
function M.new(class)
	return setmetatable({
		props = { ClassName = class, Name = class, CFrame = R.CFrame.identity, Transform = R.CFrame.identity },
		children = {},
		attributes = {},
	}, mt)
end
function methods:IsA(class)
	return self.ClassName == class or class == "BasePart" and (self.ClassName == "MeshPart" or self.ClassName == "Part")
end
function methods:GetChildren()
	return table.clone(self.children)
end
function methods:GetDescendants()
	local out = {}
	local function visit(node)
		for _, child in node.children do
			table.insert(out, child)
			visit(child)
		end
	end
	visit(self)
	return out
end
function methods:FindFirstChild(name, recursive)
	for _, child in (if recursive then self:GetDescendants() else self.children) do
		if child.Name == name then
			return child
		end
	end
	return nil
end
function methods:FindFirstChildWhichIsA(class, recursive)
	for _, child in (if recursive then self:GetDescendants() else self.children) do
		if child:IsA(class) then
			return child
		end
	end
	return nil
end
function methods:SetAttribute(key, value)
	self.attributes[key] = value
end
function methods:GetAttribute(key)
	return self.attributes[key]
end
function methods:GetPivot()
	return self.PrimaryPart.CFrame
end
function methods:PivotTo(target)
	local delta = target * self.PrimaryPart.CFrame:Inverse()
	for _, part in self:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = delta * part.CFrame
		end
	end
end
function methods:Clone()
	local map = {}
	local function copy(node)
		local result = M.new(node.ClassName)
		map[node] = result
		for key, value in node.props do
			if key ~= "Parent" and key ~= "PrimaryPart" then
				result[key] = value
			end
		end
		result.attributes = table.clone(node.attributes)
		for _, child in node.children do
			copy(child).Parent = result
		end
		return result
	end
	local result = copy(self)
	for original, cloned in map do
		if original.PrimaryPart then
			cloned.PrimaryPart = map[original.PrimaryPart]
		end
	end
	return result
end
function methods:Destroy()
	self.Parent = nil
end
return M
