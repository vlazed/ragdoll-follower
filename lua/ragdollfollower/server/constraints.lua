local fc = {}

---These are taken from `constraints.lua`
---These are constraints decoupled from the duplicator
---system
local currentSystem = NULL
local systemLookup = {}
local MAX_CONSTRAINTS_PER_SYSTEM = 100

local function CreateConstraintSystem()
	local iterations = GetConVarNumber("gmod_physiterations")

	---@class ConstraintSystem: Entity
	local csystem = ents.Create("phys_constraintsystem")
	if not IsValid(csystem) then
		return
	end

	csystem:SetKeyValue("additionaliterations", iterations)
	csystem:Spawn()
	csystem:Activate()
	csystem.__ConstraintCount = 0

	return csystem
end

local function FindOrCreateConstraintSystem(ent1, ent2)
	local system = NULL

	ent2 = ent2 or ent1

	-- Does Ent1 have a constraint system?
	if not ent1:IsWorld() and IsValid(ent1.ConstraintSystem) and not ent1.ConstraintSystem.__BadConstraintSystem then
		system = ent1.ConstraintSystem
	end

	-- Don't add to this system - we have too many constraints on it already.
	if IsValid(system) and (system.__ConstraintCount or 0) >= MAX_CONSTRAINTS_PER_SYSTEM then
		system = nil
	end

	-- Does Ent2 have a constraint system?
	if
		not IsValid(system)
		and not ent2:IsWorld()
		and IsValid(ent2.ConstraintSystem)
		and not ent2.ConstraintSystem.__BadConstraintSystem
	then
		system = ent2.ConstraintSystem
	end

	-- Don't add to this system - we have too many constraints on it already.
	if IsValid(system) and (system.__ConstraintCount or 0) >= MAX_CONSTRAINTS_PER_SYSTEM then
		system = nil
	end

	-- No constraint system yet (Or they're both full) - make a new one
	if not IsValid(system) then
		--Msg( "New Constrant System\n" )
		system = CreateConstraintSystem()
	end

	ent1.ConstraintSystem = system
	ent2.ConstraintSystem = system

	return system
end

local function onStartConstraint(ent1, ent2)
	-- Get constraint system
	currentSystem = FindOrCreateConstraintSystem(ent1, ent2)

	-- Any constraints called after this call will use this system
	SetPhysConstraintSystem(currentSystem)
end

local function onFinishConstraint()
	-- Turn off constraint system override
	currentSystem = nil
	SetPhysConstraintSystem(NULL)
end

local function ConstraintCreated(constr)
	assert(IsValid(currentSystem))
	systemLookup[constr] = currentSystem
	currentSystem.__ConstraintCount = (currentSystem.__ConstraintCount or 0) + 1
end

---Custom weld which isn't stored by the duplicator system
---
---https://github.com/Facepunch/garrysmod/blob/12b4400438b2de4cdd183c4fad7c2bef58056438/garrysmod/lua/includes/modules/constraint.lua#L440
---@param Ent1 Entity
---@param Ent2 Entity
---@param Phys1 PhysObj
---@param Phys2 PhysObj
---@return Entity
function fc.Weld(Ent1, Ent2, Phys1, Phys2)
	onStartConstraint(Ent1, Ent2)

	-- Create the constraint
	local Constraint = ents.Create("phys_constraint")
	ConstraintCreated(Constraint)
	Constraint:SetKeyValue("forcelimit", 0)
	Constraint:SetPhysConstraintObjects(Phys2, Phys1)
	Constraint:Spawn()
	Constraint:Activate()

	onFinishConstraint()

	return Constraint
end

---@param Ent1 Entity
---@param Ent2 Entity
---@param Phys1 PhysObj
---@param Phys2 PhysObj
function fc.Rope(Ent1, Ent2, Phys1, Phys2)
	onStartConstraint(Ent1, Ent2)

	-- Create the constraint
	local Constraint = ents.Create("phys_lengthconstraint")
	ConstraintCreated(Constraint)
	Constraint:SetPos(Phys1:GetPos())
	Constraint:SetKeyValue("attachpoint", tostring(Phys2:GetPos()))
	Constraint:SetKeyValue("minlength", "0.0")
	Constraint:SetKeyValue("length", 0.1)
	Constraint:SetKeyValue("forcelimit", 0)
	Constraint:SetPhysConstraintObjects(Phys1, Phys2)
	Constraint:Spawn()
	Constraint:Activate()

	onFinishConstraint()

	return Constraint
end

function fc.Elastic(Ent1, Ent2, Phys1, Phys2)
	onStartConstraint(Ent1, Ent2)

	Constraint = ents.Create("phys_spring")
	ConstraintCreated(Constraint)
	Constraint:SetPos(Phys1:GetPos())
	Constraint:SetKeyValue("springaxis", tostring(Phys2:GetPos()))
	Constraint:SetKeyValue("constant", 32000)
	Constraint:SetKeyValue("damping", 100)
	Constraint:SetKeyValue("relativedamping", 0.01)
	Constraint:SetPhysConstraintObjects(Phys1, Phys2)
	Constraint:SetKeyValue("spawnflags", 1)

	Constraint:Spawn()
	Constraint:Activate()

	onFinishConstraint()

	return Constraint
end

function fc.Ballsocket(Ent1, Ent2, Phys1, Phys2)
	onStartConstraint(Ent1, Ent2)

	local Constraint = ents.Create("phys_ballsocket")
	ConstraintCreated(Constraint)
	Constraint:SetPos(Phys2:GetPos())
	Constraint:SetPhysConstraintObjects(Phys1, Phys2)
	Constraint:Spawn()
	Constraint:Activate()

	onFinishConstraint()

	return Constraint
end

-- HACK: Entity.IsConstraint is false for these
local constraintClasses = {}
constraintClasses["phys_spring"] = true
constraintClasses["phys_slideconstraint"] = true
constraintClasses["phys_torque"] = true
constraintClasses["logic_collision_pair"] = true

hook.Add("EntityRemoved", "RagdollFollower_ConstraintRemoved", function(ent)
	-- Remove this constraint from Entity.Constraints table of the constrained entities
	if ent:IsConstraint() or constraintClasses[ent:GetClass()] then
		for i = 1, 6 do
			local entX = ent["Ent" .. i]
			if IsValid(entX) and entX.Constraints then
				table.RemoveByValue(entX.Constraints, ent)
			end
		end
	end

	-- Update constraint system entity's constraint count
	local constSystem = systemLookup[ent]
	if not IsValid(constSystem) then
		return
	end

	constSystem.__ConstraintCount = (constSystem.__ConstraintCount or 0) - 1

	if constSystem.__ConstraintCount <= 0 then
		constSystem.__BadConstraintSystem = true
		constSystem:Remove()
	end
end)

return fc
