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
		---@type RagdollFollowerConstraintInfo
		local tab = follower:GetTable()
		if tab and tab.IsRagdollFollower then
			table.insert(followers, follower)
			count = count + 1
		end
	end

	net.Start("ragdollfollower_updateview")
	net.WriteUInt(count, 13)
	for _, follower in ipairs(followers) do
		net.WriteEntity(follower.Ent1)
		net.WriteEntity(follower.Ent2)
		net.WriteEntity(follower)
	end
	net.Broadcast()
end
net.Receive("ragdollfollower_updateview", function(len, ply)
	updateView()
end)

---@param Ent1 Entity
---@param Ent2 Entity
---@param Bones string[]
---@param ConstraintType string
function AddFollower(Ent1, Ent2, Bones, ConstraintType)
	if not IsValid(Ent1) then
		return false
	end
	if not IsValid(Ent2) then
		return false
	end
	if Ent1 == Ent2 then
		return false
	end

	local bones = Bones
	local constraintType = ConstraintType

	---@diagnostic disable-next-line
	if istable(RAGDOLLPUPPETEER_PLAYERS) and not istable(boneMap) then
		---Might be risky to track a library that doesn't change. Fortunately,
		---this version of Ragdoll Puppeteer is final
		boneMap = include("ragdollpuppeteer/lib/bones.lua")
	end

	---@type integer[]
	local map
	if boneMap then
		map = boneMap.getPhysMap(Ent1, Ent2, boneMap.getMap(Ent1, Ent2))
	end

	if constraints[Ent1] then
		for _, con in ipairs(constraints[Ent1]) do
			con:Remove()
		end
	end
	constraints[Ent1] = {}

	for _, boneName in ipairs(bones) do
		---We store a list of bone names, rather than physics object ids.
		---We still check if we get a physics object for the source. If the
		---physics object doesn't exist on the source, then let's remove
		---it from the bone name
		local sourcePhysBone = Ent1:GetPhysicsObjectNum(boneToPhysBone(Ent1, Ent1:LookupBone(boneName)))
		local targetPhysBone = Ent2:GetPhysicsObjectNum(sourcePhysBone and sourcePhysBone:GetIndex() or -1)
		if map then
			targetPhysBone = sourcePhysBone and map[sourcePhysBone] and Ent2:GetPhysicsObjectNum(map[sourcePhysBone])
		end

		if IsValid(sourcePhysBone) and IsValid(targetPhysBone) then
			targetPhysBone:SetPos(sourcePhysBone:GetPos())
			targetPhysBone:SetAngles(sourcePhysBone:GetAngles())
			table.insert(constraints[Ent1], fc[constraintType](Ent1, Ent2, sourcePhysBone, targetPhysBone))
		end
	end

	print(Ent1, Ent2)

	local noCollide = constraint.FindConstraintEntity(Ent1, "RagdollFollower")
	if not IsValid(noCollide) then
		noCollide = constraint.NoCollide(Ent1, Ent2, 0, 0, false)
	end
	constraint.AddConstraintTable(Ent1, noCollide, Ent2)
	---@type RagdollFollowerConstraintInfo
	local c = {
		Ent1 = Ent1,
		Ent2 = Ent2,
		Bones = Bones,
		ConstraintType = ConstraintType,
		Type = "RagdollFollower",
		IsRagdollFollower = true
	}
	noCollide:SetTable(c)

	updateView()

	return noCollide
end

function RemoveFollower(Controller)
	if constraints[Controller] then
		for _, con in ipairs(constraints[Controller]) do
			if IsValid(con) then
				con:Remove()
			end
		end
	end
	constraints[Controller] = {}

	constraint.RemoveConstraints(Controller, "RagdollFollower")

	updateView()
end

duplicator.RegisterConstraint("RagdollFollower", AddFollower, "Ent1", "Ent2", "Bones", "ConstraintType")

util.AddNetworkString("ragdollfollower_add")
net.Receive("ragdollfollower_add", function(len, ply)
	local controller = net.ReadEntity()
	local follower = net.ReadEntity()
	local bones = net.ReadTable(true)
	local constraint = net.ReadString()

	AddFollower(controller, follower, bones, constraint)
end)

util.AddNetworkString("ragdollfollower_select")
net.Receive("ragdollfollower_select", function(len, ply)
	local controller = net.ReadEntity()
	---@type RagdollFollowerConstraintInfo
	local followerInfo = constraint.FindConstraint(controller, "RagdollFollower")
	-- print("selected", followerInfo)
	-- print("count", controller:GetPhysicsObjectCount())
	-- PrintTable(followerInfo)
	-- print(controller)
	if istable(followerInfo) then
		net.Start("ragdollfollower_select")
		net.WriteEntity(followerInfo.Ent1)
		net.WriteEntity(followerInfo.Ent2)
		net.WriteTable(followerInfo.Bones, true)
		net.WriteString(followerInfo.ConstraintType)
		net.WriteUInt(controller:GetPhysicsObjectCount() - 1, 5)
		net.Send(ply)
	end
end)

hook.Add("EntityRemoved", "RagdollFollower_ConstraintRemoved_Entity", function(ent)
	-- Remove this constraint from Entity.Constraints table of the constrained entities
	if ent:IsConstraint() and ent.IsRagdollFollower then
		updateView()
	end
end)

util.AddNetworkString("ragdollfollower_sync")
net.Receive("ragdollfollower_sync", function(len, ply)
	for _, follower in ipairs(ents.FindByClass("logic_collision_pair")) do
		---@cast follower Entity
		---@type RagdollFollowerConstraintInfo
		local tab = follower:GetTable()
		if tab and tab.IsRagdollFollower then
			local c = tab.Ent1
			local f = tab.Ent2
			for i = 0, c:GetPhysicsObjectCount() - 1 do
				local cPo = c:GetPhysicsObjectNum(i)
				local fPo = f:GetPhysicsObjectNum(i)
				fPo:SetPos(cPo:GetPos())
				fPo:SetAngles(cPo:GetAngles())
			end
			for i = 0, c:GetBoneCount() - 1 do
				f:ManipulateBoneAngles(i, c:GetManipulateBoneAngles(i))
				f:ManipulateBonePosition(i, c:GetManipulateBonePosition(i))
				f:ManipulateBoneScale(i, c:GetManipulateBoneScale(i))
			end

			f:SetFlexScale(c:GetFlexScale())
			for i = 0, c:GetFlexNum() - 1 do
				f:SetFlexWeight(i, c:GetFlexWeight(i))
			end
			
			---@diagnostic disable: undefined-field
			if c.GetEyeTarget and isfunction(c.GetEyeTarget) then
				f:SetEyeTarget(c:GetEyeTarget())
			end
			---@diagnostic enable: undefined-field
		end
	end
end)
