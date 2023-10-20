if not ATTACHMENT then
	ATTACHMENT = {}
end

if SERVER then
	util.AddNetworkString("Deno_TFA_NightVision_Activate")
	util.AddNetworkString("Deno_TFA_NightVision_Deactivate")
end

ATTACHMENT.Name = "Night Vision Module"
ATTACHMENT.ShortName = "N.V.M."
ATTACHMENT.Icon = "phoenix_storms/stripes"
ATTACHMENT.Description = {
    TFA.AttachmentColors["="], "Change to the Night Vision Module.",
}

function ATTACHMENT:Attach(wep)
	if SERVER then
		net.Start("Deno_TFA_NightVision_Activate")
		net.WriteEntity(wep)
		net.Send(wep:GetOwner())
	end
end

function ATTACHMENT:Detach(wep)
	if SERVER then
		net.Start("Deno_TFA_NightVision_Deactivate")
		net.Send(wep:GetOwner())
	end
end

if not TFA_ATTACHMENT_ISUPDATING then
	TFAUpdateAttachments()
end

if SERVER then return end

local PLAYER = FindMetaTable("Player")

local function BuildNVGLight()
	local light = ProjectedTexture()
    light:SetTexture("effects/flashlight/square")
    light:SetFOV(170)
    light:SetFarZ(10000)
    light:SetBrightness(0.1)
    light:SetConstantAttenuation(0.5)

	DenoNVGLight = light
    DenoNVGLight:Update()
end

function PLAYER:ActivateNightVision(swepClass)
	local tab = {}
	local start = SysTime()

	hook.Add("RenderScreenspaceEffects", "Deno_TFA_NightVision", function()
		if not LocalPlayer():Alive() or LocalPlayer():GetActiveWeapon():GetClass() != swepClass then 
			LocalPlayer():DeactivateNightVision(true) 
			return
		end
			
		tab["$pp_colour_brightness"] 	= Lerp(SysTime()-start, -1, 0.15)
		tab["$pp_colour_contrast"] 		= Lerp(SysTime()-start, 0.15, 0.6)
		tab["$pp_colour_addr"] 			= Lerp(SysTime()-start, 0, 0.2)
		tab["$pp_colour_addg"] 			= Lerp(SysTime()-start, 0, 0.5)
		tab["$pp_colour_addb"] 			= Lerp(SysTime()-start, 0, 0.2)
		DrawColorModify(tab)

		DrawBloom( 0.5, 20, 5, 30, 2, 1, 0.5, 0.25, 1 )

		if not DenoNVGLight then
			BuildNVGLight()
		end

		DenoNVGLight:SetPos(EyePos())
        DenoNVGLight:SetAngles(EyeAngles())
        DenoNVGLight:Update()

		local dlight = DynamicLight(LocalPlayer():EntIndex())

        dlight.brightness = 1
        dlight.Size = 1000
        dlight.r = 255
        dlight.g = 255
        dlight.b = 255
        dlight.Decay = 1000
        dlight.pos = EyePos()
        dlight.DieTime = CurTime() + 0.1
	end)
end

function PLAYER:DeactivateNightVision(doAnim)
	if(doAnim) then
		local tab = {
			[ "$pp_colour_colour" ] = 1,
			[ "$pp_colour_mulr" ] = 0,
			[ "$pp_colour_mulg" ] = 0,
			[ "$pp_colour_mulb" ] = 0
		}
		local start = SysTime()

		hook.Add("RenderScreenspaceEffects", "Deno_TFA_NightVision", function()
			tab["$pp_colour_brightness"] = Lerp((SysTime()-start) / 0.25, 0.15, 0)
			tab["$pp_colour_contrast"] = Lerp((SysTime()-start) / 0.25, 0.6, 1)
			tab["$pp_colour_addr"] = Lerp((SysTime()-start) / 0.25, 0.2, 0)
			tab["$pp_colour_addg"] = Lerp((SysTime()-start) / 0.25, 0.5, 0)
			tab["$pp_colour_addb"] = Lerp((SysTime()-start) / 0.25, 0.2, 0)

			DrawColorModify(tab)

			if tab["$pp_colour_brightness"] == 1 then
				hook.Remove("RenderScreenspaceEffects", "Deno_TFA_NightVision")
			end
		end)
	else
		hook.Remove("RenderScreenspaceEffects", "Deno_TFA_NightVision")
	end

	if DenoNVGLight then
		DenoNVGLight:Remove()
		DenoNVGLight = nil
	end
end

net.Receive("Deno_TFA_NightVision_Activate", function()
	local wep = net.ReadEntity()

	if not IsValid(wep) then return end

	LocalPlayer():ActivateNightVision(wep:GetClass())
end)

net.Receive("Deno_TFA_NightVision_Deactivate", function()
	timer.Remove("Deno_TFA_NightVision_Scoped")
	LocalPlayer():DeactivateNightVision(true)
end)
