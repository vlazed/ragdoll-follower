local vendor = {}

---@type {[string]: {[integer]: integer}}
local boneToPhysMap = {}

---@param ent Entity Entity to translate bone
---@param bone integer Bone id
---@return integer physBone Physics object id
function vendor.BoneToPhysBone(ent, bone)
	if not bone then
		return -1
	end

	local model = ent:GetModel()
	if boneToPhysMap[model] and boneToPhysMap[model][bone] then
		return boneToPhysMap[model][bone]
	else
		boneToPhysMap[model] = boneToPhysMap[model] or {}
		for i = 0, ent:GetPhysicsObjectCount() - 1 do
			local b = ent:TranslatePhysBoneToBone(i)
			if bone == b then
				boneToPhysMap[model][b] = i
				return i
			end
		end
		boneToPhysMap[model][bone] = -1
		return -1
	end
end

return vendor
