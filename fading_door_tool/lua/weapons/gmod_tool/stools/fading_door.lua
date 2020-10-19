TOOL.Category = "Construction"
TOOL.Name = "#Fading Door"
TOOL.ClientConVar["key"] = "41"
TOOL.ClientConVar["toggle"] = "0"
TOOL.ClientConVar["reversed"] = "0"
TOOL.ClientConVar["mat"] = "sprites/heatwave"
_gTool = TOOL or _gTool

if SERVER then
	util.AddNetworkString("fading_door_info")
end

function TOOL:FadeDoor(eDoor, bForce)
	if eDoor.bFaded then return end
	if eDoor.bPlayersStuck and not bForce then return end
	eDoor.bFaded = true
	eDoor.strFadeMaterial = "sprites/heatwave"

	if eDoor:GetMaterial() ~= eDoor.strFadeMaterial then
		eDoor.strMaterial = eDoor:GetMaterial()
	end

	eDoor:SetMaterial(eDoor.strFadeMaterial)
	eDoor:DrawShadow(false)
	eDoor:SetNotSolid(true)
	local phys = eDoor:GetPhysicsObject()

	if IsValid(phys) then
		eDoor.bWasMoving = phys:IsMoveable()
		phys:EnableMotion(false)
		phys:Sleep()
	end

	if bForce then return end

	if WireLib then
		Wire_TriggerOutput(eDoor, "FadeActive", 1)
	end
end

function TOOL:SolidDoor(eDoor, bForce)
	if not eDoor.bFaded then return end
	if eDoor.bPlayersStuck and not bForce then return end
	eDoor.bFaded = false

	if eDoor:GetMaterial() ~= eDoor.strMaterial then
		eDoor:SetMaterial(eDoor.strMaterial)
	end

	eDoor:DrawShadow(true)
	eDoor:SetNotSolid(false)
	local phys = eDoor:GetPhysicsObject()

	if IsValid(phys) and eDoor.bWasMoving then
		phys:EnableMotion(true)
		phys:Wake()
	end

	if bForce then return end

	if WireLib then
		Wire_TriggerOutput(eDoor, "FadeActive", 0)
	end
end

function TOOL:OnKeyReleased(pPlayer, eDoor)
	if not IsValid(eDoor) or not eDoor.bFadingDoor then return false end
	local bActive = false

	if eDoor.bToggle then
		if eDoor.bReversed then
			bActive = not eDoor.bFaded
		else
			bActive = eDoor.bFaded
		end
	elseif eDoor.bReversed then
		bActive = true
	end

	if bActive then
		self:FadeDoor(eDoor)
	else
		self:SolidDoor(eDoor)
	end
end

function TOOL:OnKeyPressed(pPlayer, eDoor)
	if not IsValid(eDoor) or not eDoor.bFadingDoor then return false end
	local bActive = true

	if eDoor.bToggle then
		if eDoor.bReversed then
			bActive = eDoor.bFaded
		else
			bActive = not eDoor.bFaded
		end
	elseif eDoor.bReversed then
		bActive = false
	end

	if bActive then
		self:FadeDoor(eDoor)
	else
		self:SolidDoor(eDoor)
	end
end

function TOOL:RemoveKeys(eDoor)
	if not eDoor.bFadingDoor then return end
	numpad.Remove(eDoor.intKeyDownID)
	numpad.Remove(eDoor.intKeyUpID)
end

function TOOL:SetupWireInputs(eDoor)
	local tblInputs = eDoor.Inputs
	if not tblInputs then return Wire_CreateInputs(eDoor, {"Fade"}) end
	local tblNames, tblTypes, tblDescs = {}, {}, {}
	local intNum

	for _, tblData in pairs(tblInputs) do
		intNum = tblData.Num
		tblNames[intNum] = tblData.Name
		tblTypes[intNum] = tblData.Type
		tblDescs[intNum] = tblData.Desc
	end

	table.insert(tblNames, "Fade")
	WireLib.AdjustSpecialInputs(eDoor, tblNames, tblTypes, tblDescs)
end

function TOOL:SetupWireOutputs(eDoor)
	local tblInputs = eDoor.Inputs
	if not tblInputs then return Wire_CreateInputs(eDoor, {"FadeActive"}) end
	local tblNames, tblTypes, tblDescs = {}, {}, {}
	local intNum

	for _, tblData in pairs(tblInputs) do
		intNum = tblData.Num
		tblNames[intNum] = tblData.Name
		tblTypes[intNum] = tblData.Type
		tblDescs[intNum] = tblData.Desc
	end

	table.insert(tblNames, "FadeActive")
	WireLib.AdjustSpecialInputs(eDoor, tblNames, tblTypes, tblDescs)
end

function TOOL:TriggerInput(eDoor, strName, intValue, ...)
	if name == "Fade" then
		if value == 0 then
			return self:OnKeyReleased(nil, eDoor)
		else
			return self:OnKeyPressed(nil, eDoor)
		end
	elseif self.funcTriggerInput then
		return self:funcTriggerInput(strName, intValue, ...)
	end
end

function TOOL:PreEntityCopy(eDoor)
	if eDoor then
		local tblInfo = WireLib.BuildDupeInfo(eDoor)

		if tblInfo then
			duplicator.StoreEntityModifier(eDoor, "WireDupeInfo", tblInfo)
		end

		if eDoor.funcPreEntityCopy then
			eDoor:funcPreEntityCopy()
		end
	end
end

function TOOL:PostEntityPaste(eDoor, pPlayer, eEnt, tblEnts)
	if eDoor then
		if eDoor.EntityMods and eDoor.EntityMods.WireDupeInfo then
			WireLib.ApplyDupeInfo(pPlayer, eDoor, eDoor.EntityMods.WireDupeInfo, function(intId) return tblEnts[intId] end)
		end

		if eDoor.funcPostEntityPaste then
			eDoor:funcPostEntityPaste(pPlayer, eEnt, tblEnts)
		end
	end
end

function TOOL:OnRemove(eDoor)
	self:SolidDoor(eDoor)
	eDoor.bFadingDoor = nil
	eDoor.bKey = nil
	eDoor.bToggle = nil
	eDoor.bReversed = nil
	duplicator.ClearEntityModifier(eDoor, "Fading Door")

	if eDoor.OnDieFunctions then
		eDoor.OnDieFunctions["UndoFadingDoor" .. eDoor:EntIndex()] = nil
		eDoor.OnDieFunctions["Fading Doors"] = nil
	end

	if WireLib then
		if eDoor.Inputs then
			Wire_Link_Clear(eDoor, "Fade")
			eDoor.Inputs["Fade"] = nil
			WireLib._SetInputs(eDoor)
		end

		if eDoor.Outputs then
			local ePort = eDoor.Outputs["FadeActive"]

			if ePort then
				for intId, eInput in ipairs(ePort.Connected) do
					if IsValid(eInput.Entity) then
						Wire_Link_Clear(eInput.Entity, eInput.Name)
					end
				end
			end

			eDoor.Outputs["FadeActive"] = nil
			WireLib._SetOutputs(eDoor)
		end
	end

	if eDoor.EntityMods and eDoor.EntityMods.WireDupeInfo and eDoors.WireDupeInfo.Wires then
		eDoor.EntityMods.WireDupeInfo.Wires.Fade = nil
	end

	net.Start("fading_door_info")
	net.WriteString("FADING_DOOR_REMOVED")
	net.WriteUInt(eDoor:EntIndex(), 16)
	net.Broadcast()
end

function TOOL:FadingDoor(pPlayer, eEnt, tblStuff)
	if eEnt.bFadingDoor then
		if eEnt.OnDieFunctions and eEnt.OnDieFunctions["UndoFadingDoor" .. eEnt:EntIndex()] then
			eEnt.OnDieFunctions["UndoFadingDoor" .. eEnt:EntIndex()].Function(eEnt)
		end

		self:SolidDoor(eEnt)
		self:RemoveKeys(eEnt)
	else
		eEnt.bFadingDoor = true

		eEnt:CallOnRemove("Fading Doors", function(eRemoved)
			self:RemoveKeys(eRemoved)
		end)

		if WireLib then
			self:SetupWireInputs(eEnt)
			self:SetupWireOutputs(eEnt)
		end
	end

	eEnt.intKeyDownID = numpad.OnUp(pPlayer, tblStuff.key, "fading_door_released", eEnt)
	eEnt.intKeyUpID = numpad.OnDown(pPlayer, tblStuff.key, "fading_door_pressed", eEnt)
	eEnt.bToggle = tblStuff.toggle
	eEnt.bReversed = tblStuff.reversed
	eEnt.intKey = tblStuff.key
	eEnt.pFadingDoorOwner = pPlayer

	if eEnt.bReversed then
		self:FadeDoor(eEnt)
	end

	duplicator.StoreEntityModifier(eEnt, "Fading Door", tblStuff)
	net.Start("fading_door_info")
	net.WriteString("FADING_DOOR_CREATED")
	net.WriteUInt(eEnt:EntIndex(), 16)

	net.WriteTable({
		key = tblStuff.key,
		toggle = tblStuff.toggle,
		reversed = tblStuff.reversed
	})

	net.Broadcast()

	return true
end

duplicator.RegisterEntityModifier("Fading Door", function(pPlayer, eEnt, tblStuff) return _gTool:FadingDoor(pPlayer, eEnt, tblStuff) end)

if not FadingDoor then
	function TOOL:LegacyFadingDoor(pPlayer, eEnt, tblStuff)
		return self:FadingDoor(pPlayer, eEnt, {
			key = tblStuff.Key,
			toggle = tblStuff.Toggle,
			reversed = tblStuff.Reversed
		})
	end

	duplicator.RegisterEntityModifier("FadingDoor", function(pPlayer, eEnt, tblStuff) return _gTool:LegacyFadingDoor(pPlayer, eEnt, tblStuff) end)
end

local function _get_last_value(tblInput)
	local vOut

	for intID, vValue in pairs(tblInput) do
		vOut = vValue
	end

	return vOut
end

function TOOL:LeftClick(tblTrace)
	if not tblTrace.Entity or not IsValid(tblTrace.Entity) then return false end
	if tblTrace.Entity:IsPlayer() or tblTrace.HitWorld then return false end
	if CLIENT then return true end
	local eDoor = tblTrace.Entity
	local pOwner = self:GetOwner()
	if not IsValid(pOwner) then return false end

	self:FadingDoor(pOwner, eDoor, {
		key = self:GetClientNumber("key"),
		toggle = self:GetClientNumber("toggle") == 1,
		reversed = self:GetClientNumber("reversed") == 1
	})

	undo.Create("Fading Door")

	undo.AddFunction(function(tblUndo, tblArgs)
		local eEnt = tblArgs[1]
		local pPlayer = tblArgs[2]

		if IsValid(eEnt) then
			self:OnRemove(eEnt)
		end
	end, {eDoor, pOwner})

	undo.SetPlayer(pOwner)
	undo.Finish("Fading Door")
	local last = _get_last_value(undo:GetTable()[pOwner:UniqueID()])

	if last then
		last.Door = eDoor
	end

	eDoor:CallOnRemove("UndoFadingDoor" .. eDoor:EntIndex(), function(eRemoved)
		if not eRemoved.bFadingDoor then return end
		local pRemovedOwner = eRemoved.pFadingDoorOwner
		if not IsValid(pRemovedOwner) then return end
		local tblUndos = undo:GetTable()[pRemovedOwner:UniqueID()]

		if tblUndos then
			for intID, _ in pairs(tblUndos) do
				local tblUndo = tblUndos[intID]

				if tblUndo and tblUndo.Door == eRemoved then
					undo:GetTable()[pRemovedOwner:UniqueID()][intID] = nil
					net.Start("fading_door_info")
					net.WriteString("FADING_DOOR_REMOVE_UNDO")
					net.WriteUInt(intID, 16)
					net.Send(pRemovedOwner)
					break
				end
			end
		end
	end)

	return true
end

function TOOL:RightClick(tblTrace)
	if not tblTrace.Entity or not IsValid(tblTrace.Entity) then return false end
	if tblTrace.Entity:IsPlayer() or tblTrace.HitWorld then return false end
	if CLIENT then return true end
	local eDoor = tblTrace.Entity
	if not eDoor.bFadingDoor then return false end
	local pOwner = self:GetOwner()
	if not IsValid(pOwner) then return false end

	if eDoor.intKey then
		pOwner:ConCommand("fading_door_key " .. tostring(eDoor.intKey))
	end

	if eDoor.bToggle then
		pOwner:ConCommand("fading_door_toggle " .. (eDoor.bToggle and "1" or "0"))
	end

	if eDoor.bReversed then
		pOwner:ConCommand("fading_door_reversed " .. (eDoor.bReversed and "1" or "0"))
	end

	return true
end

function TOOL:Reload(tblTrace)
	if not tblTrace.Entity or not IsValid(tblTrace.Entity) then return false end
	if tblTrace.Entity:IsPlayer() or tblTrace.HitWorld then return false end
	if CLIENT then return true end
	local eDoor = tblTrace.Entity
	if not eDoor.bFadingDoor then return false end
	local pOwner = self:GetOwner()
	if not IsValid(pOwner) then return false end

	if eDoor.OnDieFunctions and eDoor.OnDieFunctions["UndoFadingDoor" .. eDoor:EntIndex()] then
		eDoor.OnDieFunctions["UndoFadingDoor" .. eDoor:EntIndex()].Function(eDoor)
	end

	self:OnRemove(eDoor)

	return true
end

function TOOL:Holster()
	if CLIENT then return end
	local pOwner = self:GetOwner()
	if not IsValid(pOwner) then return end
end

function TOOL:Think()
	if CLIENT then return end
	local pOwner = self:GetOwner()
	if not IsValid(pOwner) then return end
	local tblTrace = pOwner:GetEyeTrace()
	if not tblTrace.Entity or not IsValid(tblTrace.Entity) then return end
	if tblTrace.Entity:IsPlayer() or tblTrace.HitWorld then return end
	local eDoor = tblTrace.Entity
	if not eDoor.bFadingDoor then return end

	if not self.tblCache then
		self.tblCache = {}
	end

	local tblCached = self.tblCache[eDoor]

	if not tblCached then
		self.tblCache[eDoor] = {
			key = eDoor.bKey,
			toggle = eDoor.bToggle,
			reversed = eDoor.bReversed
		}

		tblCached = self.tblCache[eDoor]
	end

	local p_key = eDoor.bKey
	local p_toggle = eDoor.bToggle
	local p_reversed = eDoor.bReversed

	if (tblCached.key ~= p_key or tblCached.toggle ~= p_toggle or tblCached.reversed ~= p_reversed) then
		net.Start("fading_door_info")
		net.WriteString("FADING_DOOR_UPDATED")
		net.WriteUInt(eDoor:EntIndex(), 16)

		net.WriteTable({
			key = eDoor.bKey,
			toggle = eDoor.bToggle,
			reversed = eDoor.bReversed
		})

		net.Send(pOwner)

		self.tblCache[eDoor] = {
			key = eDoor.bKey,
			toggle = eDoor.bToggle,
			reversed = eDoor.bReversed
		}
	end
end

if SERVER then
	numpad.Register("fading_door_released", function(pPlayer, eEnt) return _gTool:OnKeyReleased(pPlayer, eEnt) end)
	numpad.Register("fading_door_pressed", function(pPlayer, eEnt) return _gTool:OnKeyPressed(pPlayer, eEnt) end)
end

if CLIENT then
	language.Add("Tool.fading_door.name", "Fading Doors")
	language.Add("Tool.fading_door.desc", "Makes anything into a fadable door")
	language.Add("Tool.fading_door.0", "Click on something to make it a fading door. Right click to copy settings. Reload to remove fading door.")

	function TOOL:BuildCPanel()
		self:AddControl("Header", {
			Text = "#Tool.fading_door.name",
			Description = "#Tool.fading_door.desc"
		})

		self:AddControl("CheckBox", {
			Label = "Toggle Active",
			Command = "fading_door_toggle"
		})

		self:AddControl("CheckBox", {
			Label = "Reversed",
			Command = "fading_door_reversed"
		})

		self:AddControl("Numpad", {
			Label = "Button",
			ButtonSize = "22",
			Command = "fading_door_key"
		})
	end

	_g_tblFadingDoors = _g_tblFadingDoors or {}

	net.Receive("fading_door_info", function()
		local strWhat = net.ReadString()
		local intDoor = net.ReadUInt(16)

		if strWhat == "FADING_DOOR_CREATED" or strWhat == "FADING_DOOR_UPDATED" then
			local tblData = net.ReadTable()
			_g_tblFadingDoors[intDoor] = tblData
		elseif strWhat == "FADING_DOOR_REMOVED" then
			_g_tblFadingDoors[intDoor] = nil
		elseif strWhat == "FADING_DOOR_REMOVE_UNDO" then
			local tblUndos = undo:GetTable()

			for intID, tblData in pairs(tblUndos) do
				local tblUndo = tblUndos[intID]

				if tblUndo and tblUndo.Key == intDoor then
					tblUndos[intID] = nil
					undo.MakeUIDirty()
					break
				end
			end
		end
	end)

	local COLOR_NONE = color_white
	local COLOR_SAME = Color(100, 255, 100)
	local COLOR_DIFFERENT = Color(255, 150, 50)

	hook.Add("PreDrawHalos", "fading_door_halos", function()
		local pLocalPlayer = LocalPlayer()
		local eTool = pLocalPlayer:GetActiveWeapon()
		if not IsValid(eTool) or eTool:GetClass() ~= "gmod_tool" then return end
		local tblObject = eTool:GetToolObject()
		if not tblObject or tblObject.Mode ~= "fading_door" then return end
		local tblTrace = pLocalPlayer:GetEyeTrace()
		if not tblTrace.Entity or not IsValid(tblTrace.Entity) then return end
		if tblTrace.Entity:IsPlayer() or tblTrace.HitWorld then return end
		if tblTrace.Entity:GetPos():DistToSqr(pLocalPlayer:GetPos()) >= (500 * 500) then return end
		local intIndex = tblTrace.Entity:EntIndex()
		local tblData = _g_tblFadingDoors[intIndex]
		local colHalo = COLOR_NONE
		local p_key = tblObject:GetClientNumber("key")
		local p_toggle = tblObject:GetClientNumber("toggle") == 1
		local p_reversed = tblObject:GetClientNumber("reversed") == 1

		if tblData then
			if tblData.key ~= p_key or tblData.toggle ~= p_toggle or tblData.reversed ~= p_reversed then
				colHalo = COLOR_DIFFERENT
			else
				colHalo = COLOR_SAME
			end
		end

		halo.Add({tblTrace.Entity}, colHalo, 10, 10, 1, true, false)
	end)
end