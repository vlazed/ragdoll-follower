---@module "ragdollfollower.server.vendor"
local vendor = include("ragdollfollower/shared/vendor.lua")
---@module "ragdollfollower.server.constraints"
local fc = include("ragdollfollower/server/constraints.lua")
local boneToPhysBone = vendor.BoneToPhysBone
local boneMap

print("follower included")

---Store `phys_constraint` entities for each entity.
---@type {[Entity]: Entity[]}
local constraints = {}

util.AddNetworkString("ragdollfollower_updateview")
local function updateView()
	local followers = {}
	local count = 0
	for _, follower in ipairs(ents.FindByClass("logic_collision_pair")) do
		---@cast follower Entity
		local tab = follower:GetTable()
		if tab and tab.Type == "RagdollFollower" then
			table.insert(followers, follower)
			count = count + 1
		end
	end

	net.Start("ragdollfollower_updateview")
	net.WriteUInt(count, 13)
	for _, follower in ipairs(followers) do
		net.WriteEntity(follower.Controller)
		net.WriteEntity(follower.Follower)
		net.WriteEntity(follower)
	end
	net.Broadcast()
end
net.Receive("ragdollfollower_updateview", function(len, ply)
	updateView()
end)

---@param Controller Entity
---@param Follower Entity
---@param ConstraintTable RagdollFollowerConstraintInfo
function AddFollower(Controller, Follower, ConstraintTable)
	if not IsValid(Controller) then
		return false
	end
	if not IsValid(Follower) then
		return false
	end
	if Controller == Follower then
		return false
	end

	local bones = ConstraintTable.Bones
	local constraintType = ConstraintTable.ConstraintType

	---@diagnostic disable-next-line
	if istable(RAGDOLLPUPPETEER_PLAYERS) and not istable(boneMap) then
		---Might be risky to track a library that doesn't change. Fortunately,
		---this version of Ragdoll Puppeteer is final
		boneMap = include("ragdollpuppeteer/lib/bones.lua")
	end

	---@type integer[]
	local map
	if boneMap then
		map = boneMap.getPhysMap(Controller, Follower, boneMap.getMap(Controller, Follower))
	end

	if constraints[Controller] then
		for _, con in ipairs(constraints[Controller]) do
			con:Remove()
		end
	end
	constraints[Controller] = {}

	for _, boneName in ipairs(bones) do
		---We store a list of bone names, rather than physics object ids.
		---We still check if we get a physics object for the source. If the
		---physics object doesn't exist on the source, then let's remove
		---it from the bone name
		local sourcePhysBone =
			Controller:GetPhysicsObjectNum(boneToPhysBone(Controller, Controller:LookupBone(boneName)))
		local targetPhysBone = Follower:GetPhysicsObjectNum(sourcePhysBone and sourcePhysBone:GetIndex() or -1)
		if map then
			targetPhysBone = sourcePhysBone
				and map[sourcePhysBone]
				and Follower:GetPhysicsObjectNum(map[sourcePhysBone])
		end

		if IsValid(sourcePhysBone) and IsValid(targetPhysBone) then
			targetPhysBone:SetPos(sourcePhysBone:GetPos())
			targetPhysBone:SetAngles(sourcePhysBone:GetAngles())
			table.insert(
				constraints[Controller],
				fc[constraintType](Controller, Follower, sourcePhysBone, targetPhysBone)
			)
		end
	end

	local noCollide = constraint.FindConstraintEntity(Controller, "RagdollFollower")
	if not IsValid(noCollide) then
		noCollide = constraint.NoCollide(Controller, Follower, 0, 0, false)
	end
	constraint.AddConstraintTable(Controller, noCollide, Follower)
	noCollide:SetTable({
		Type = "RagdollFollower",
		Controller = Controller,
		Follower = Follower,
		Bones = bones,
		ConstraintType = constraintType,
	})

	updateView()

	return noCollide
end

function RemoveFollower(Controller)
	if constraints[Controller] then
		for _, con in ipairs(constraints[Controller]) do
			con:Remove()
		end
	end
	constraints[Controller] = {}

	constraint.RemoveConstraints(Controller, "RagdollFollower")

	updateView()
end

duplicator.RegisterConstraint("RagdollFollower", AddFollower, "Controller", "Follower", "ConstraintTable")

util.AddNetworkString("ragdollfollower_add")
net.Receive("ragdollfollower_add", function(len, ply)
	local controller = net.ReadEntity()
	local follower = net.ReadEntity()
	local bones = net.ReadTable(true)
	local constraint = net.ReadString()

	PrintTable(bones)

	AddFollower(controller, follower, {
		Controller = controller,
		Follower = follower,
		Bones = bones,
		ConstraintType = constraint,
	})
end)

util.AddNetworkString("ragdollfollower_select")
net.Receive("ragdollfollower_select", function(len, ply)
	local controller = net.ReadEntity()
	---@type RagdollFollowerConstraintInfo
	local followerInfo = constraint.FindConstraint(controller, "RagdollFollower")
	print("selected", followerInfo)
	print("count", controller:GetPhysicsObjectCount())
	PrintTable(followerInfo)
	if istable(followerInfo) then
		net.Start("ragdollfollower_select")
		net.WriteEntity(followerInfo.Controller)
		net.WriteEntity(followerInfo.Follower)
		net.WriteTable(followerInfo.Bones, true)
		net.WriteString(followerInfo.ConstraintType)
		net.WriteUInt(controller:GetPhysicsObjectCount() - 1, 5)
		net.Send(ply)
	end
end)

hook.Add("EntityRemoved", "RagdollFollower_ConstraintRemoved_Entity", function(ent)
	-- Remove this constraint from Entity.Constraints table of the constrained entities
	if ent:IsConstraint() and ent.Type == "RagdollFollower" then
		updateView()
	end
end)
