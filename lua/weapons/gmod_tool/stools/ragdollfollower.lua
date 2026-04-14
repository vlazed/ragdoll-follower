TOOL.Category = "Poser"
TOOL.Name = "#tool.ragdollfollower.name"
TOOL.Command = nil
TOOL.ConfigName = ""

local firstReload = true
function TOOL:Think()
	if CLIENT and firstReload then
		self:RebuildControlPanel()
		firstReload = false
	end
end

---@param ent Entity
---@return boolean
local function validateEntity(ent)
	return IsValid(ent) and not ent:IsPlayer() and not ent:IsWorld()
end

---Remove the outgoing arc from the entity
---@param tr table|TraceResult
---@return boolean
function TOOL:Reload(tr)
	local entity = tr.Entity
	if not validateEntity(entity) then
		return false
	end

	if CLIENT then
		return true
	end

	self:ClearObjects()

	RemoveFollower(entity)

	return true
end

function TOOL:Holster()
	self:ClearObjects()
end

local function canTool(ent, pl)
	local cantool

	---@diagnostic disable-next-line
	if CPPI and ent.CPPICanTool then
		cantool = ent:CPPICanTool(pl, "ragdollfollower")
	else
		cantool = true
	end

	return cantool
end

---Select an entity to target, and then select another entity to set its arc it.
---@param tr table|TraceResult
---@return boolean
function TOOL:LeftClick(tr)
	local entity = tr.Entity
	if not validateEntity(entity) then
		return false
	end
	if SERVER and not util.IsValidPhysicsObject(entity, tr.PhysicsBone) then
		return false
	end
	if not canTool(entity, self:GetOwner()) then
		return false
	end

	self:SetOperation(2)

	-- Using weld.lua for the logic
	local iNum = self:NumObjects()
	local phys = entity:GetPhysicsObjectNum(tr.PhysicsBone)
	self:SetObject(iNum + 1, entity, tr.HitPos, phys, tr.PhysicsBone, tr.HitNormal)

	if CLIENT then
		if iNum > 0 then
			self:ClearObjects()
		end
		return true
	end

	if iNum == 0 then
		self:SetStage(1)
		return true
	end

	if iNum == 1 then
		local ply = self:GetOwner()
		if not ply:CheckLimit("constraints") then
			self:ClearObjects()
			return false
		end

		-- Get information we're about to use
		local controller, follower = self:GetEnt(1), self:GetEnt(2)

		local bones = {}
		for i = 0, controller:GetPhysicsObjectCount() - 1 do
			table.insert(bones, controller:GetBoneName(controller:TranslatePhysBoneToBone(i)))
		end

		-- add weld
		AddFollower(controller, follower, bones, "Weld")

		-- Clear the objects so we're ready to go again
		self:ClearObjects()
	end

	return true
end

---Select an entity to view its data, if it has any
---@param tr table|TraceResult
---@return boolean
function TOOL:RightClick(tr)
	local entity = tr.Entity
	if not IsValid(entity) then
		return false
	end

	if CLIENT then
		return true
	end

	return true
end

if SERVER then
	return
end

TOOL:BuildConVarList()

---@module "ragdollfollower.client.ui"
local ui = include("ragdollfollower/client/ui.lua")

---@class PanelState
local panelState = {
	follower = NULL,
	controller = NULL,
}

---@param cPanel ControlPanel|DForm
function TOOL.BuildCPanel(cPanel)
	local panelChildren = ui.ConstructPanel(cPanel, panelState)
	ui.HookPanel(panelChildren, panelState)
end

TOOL.Information = {
	{ name = "left", stage = 0 },
	{ name = "left_1", stage = 1, op = 2 },
	{ name = "right", stage = 0 },
	{ name = "reload" },
}

concommand.Add("ragdollfollower_sync", function(ply, cmd, args, argStr)
	net.Start("ragdollfollower_sync")
	net.SendToServer()
end)
