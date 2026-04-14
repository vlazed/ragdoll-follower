local ui = {}

local constraintTypes = { "Weld", "Rope", "Elastic", "Ballsocket" }

---Helper for DForm
---@param cPanel ControlPanel|DForm
---@param name string
---@param type "ControlPanel"|"DForm"
---@return ControlPanel|DForm
local function makeCategory(cPanel, name, type)
	---@type DForm|ControlPanel
	local category = vgui.Create(type, cPanel)

	category:SetLabel(name)
	cPanel:AddItem(category)
	return category
end

local lgp = language.GetPhrase

---@param cPanel ControlPanel|DForm
---@param panelState PanelState
---@return PanelChildren
function ui.ConstructPanel(cPanel, panelState)
	local entities = makeCategory(cPanel, lgp("#tool.ragdollfollower.entities"), "ControlPanel")
	local bones = makeCategory(cPanel, lgp("#tool.ragdollfollower.bones"), "ControlPanel")
	local settings = makeCategory(cPanel, lgp("#tool.ragdollfollower.settings"), "ControlPanel")

	entities:Help(lgp("#tool.ragdollfollower.general"))

	---@class EntityList: DListView
	local entityList = vgui.Create("DListView", entities)
	entityList:AddColumn("Controller")
	entityList:AddColumn("Follower")
	entityList:SizeTo(-1, 200, 0)
	entities:AddItem(entityList)

	---@class ConstraintType: DComboBox
	local constraintType = bones:ComboBox(lgp("#tool.ragdollfollower.bones.constraint"), nil)

	for _, constraint in ipairs(constraintTypes) do
		constraintType:AddChoice(constraint)
	end

	local boneListPanel = vgui.Create("DPanel", bones)
	boneListPanel:SizeTo(-1, 400, 0)
	bones:AddItem(boneListPanel)
	local boneList = vgui.Create("DScrollPanel", boneListPanel)
	boneList:Dock(FILL)

	---@class UpdateEntity: DButton
	local update = bones:Button(lgp("#tool.ragdollfollower.bones.update"), "")

	---@class PanelChildren
	local panelChildren = {
		constraintType = constraintType,
		boneList = boneList,
		entityList = entityList,
		update = update,
	}

	return panelChildren
end

---@param parent Panel
---@param boneName string
---@param initial boolean
---@return BoneCheckbox
local function boneCheckbox(parent, boneName, initial)
	---@class BoneCheckbox: DPanel
	local panel = vgui.Create("DPanel", parent)

	panel:SetTall(50)

	panel.checkbox = vgui.Create("DCheckBoxLabel", panel)
	panel.checkbox:Dock(RIGHT)
	panel.checkbox:SetChecked(initial)

	panel.checkbox:SetText("")
	panel.checkbox:SetDark(true)

	panel.label = vgui.Create("DLabel", panel)
	panel.label:Dock(FILL)
	panel.label:DockMargin(10, 0, 0, 0)
	panel.label:SetText(boneName)

	panel.label:SetDark(true)

	panel.name = boneName

	panel:Dock(TOP)

	return panel
end

---@param panelChildren PanelChildren
---@param panelState PanelState
function ui.HookPanel(panelChildren, panelState)
	local constraintType = panelChildren.constraintType
	local boneList = panelChildren.boneList
	---@class UpdateEntity
	local update = panelChildren.update

	---@class EntityList
	local entityList = panelChildren.entityList

	---@param controller Entity
	---@param follower Entity
	---@param boneSet StringSet
	---@param constraint string
	local function populateBones(controller, follower, boneSet, constraint, count)
		boneList:Clear()

		print(controller)
		print("populate bones")
		---@type BoneCheckbox[]
		local boneCheckboxes = {}
		print("count", count)
		for i = 0, count do
			local name = controller:GetBoneName(controller:TranslatePhysBoneToBone(i))
			if name then
				table.insert(boneCheckboxes, boneCheckbox(boneList, name, boneSet[name]))
			end
		end

		constraintType:SetValue(constraint)

		function update:DoClick()
			local bones = {}
			for _, panel in pairs(boneCheckboxes) do
				if panel.checkbox:GetChecked() then
					table.insert(bones, panel.name)
				end
			end
			net.Start("ragdollfollower_add")
			net.WriteEntity(controller)
			net.WriteEntity(follower)
			net.WriteTable(bones, true)
			net.WriteString(constraintType:GetValue())
			net.SendToServer()
		end
	end

	---@param entities EntityTriplet[]
	local function populateEntities(entities)
		print("clear list")
		entityList:Clear()

		for _, entity in ipairs(entities) do
			---@class EntityLine: DListView_Line
			local line = entityList:AddLine(tostring(entity[1]), tostring(entity[2]))
			line.controller = entity[1]
			line.constraint = entity[3]

			local function removeLineOnDelete(ent)
				if IsValid(line) and IsValid(ent) then
					line:Remove()
				end
			end

			entity[1]:CallOnRemove("RagdollFollower_DeleteLine", removeLineOnDelete)
			entity[2]:CallOnRemove("RagdollFollower_DeleteLine", removeLineOnDelete)
			entity[3]:CallOnRemove("RagdollFollower_DeleteLine", removeLineOnDelete)
		end
	end

	---@param index integer
	---@param row EntityLine
	function entityList:OnRowSelected(index, row)
		print("row selected")
		net.Start("ragdollfollower_select")
		net.WriteEntity(row.controller)
		net.WriteEntity(row.constraint)
		net.SendToServer()
	end

	net.Receive("ragdollfollower_updateview", function(len, ply)
		local count = net.ReadUInt(13)
		local entities = {}
		for _ = 1, count do
			local controller = net.ReadEntity()
			local follower = net.ReadEntity()
			local con = net.ReadEntity()
			table.insert(entities, { controller, follower, con })
		end
		populateEntities(entities)
	end)

	net.Receive("ragdollfollower_select", function(len, ply)
		local controller = net.ReadEntity()
		local follower = net.ReadEntity()
		local bones = net.ReadTable(true)
		local constraint = net.ReadString()
		local count = net.ReadUInt(5)

		PrintTable(bones)

		local boneSet = {}
		for _, bone in ipairs(bones) do
			boneSet[bone] = true
		end

		populateBones(controller, follower, boneSet, constraint, count)
	end)

	net.Start("ragdollfollower_updateview")
	net.SendToServer()
end

return ui
