if not ATTACHMENT then
	ATTACHMENT = {}
end

if SERVER then
	util.AddNetworkString("Deno_TFA_Thermal_Activate")
	util.AddNetworkString("Deno_TFA_Thermal_Deactivate")
end

ATTACHMENT.Name = "Thermal Vision Module"
ATTACHMENT.ShortName = "T.V.M."
ATTACHMENT.Icon = "phoenix_storms/stripes"
ATTACHMENT.Description = {
    TFA.AttachmentColors["="], "Change to the Thermal Vision Module.",
}

if CLIENT then
	local PLAYER = FindMetaTable("Player")

	function PLAYER:ActivateThermal()
		local tab = {
			[ "$pp_colour_colour" ] = 1,
			[ "$pp_colour_mulr" ] = 0,
			[ "$pp_colour_mulg" ] = 0,
			[ "$pp_colour_mulb" ] = 0
		}
		local start = SysTime()

		hook.Add("PostDrawOpaqueRenderables", "Deno_TFA_Thermal_Highlight", function()
			if not LocalPlayer():Alive() then 
				LocalPlayer():DeactivateThermal() 
				return
			end
			
			tab["$pp_colour_brightness"] = Lerp(SysTime()-start, 1, -0.2)
			tab["$pp_colour_contrast"] = Lerp(SysTime()-start, 0.5, 0.1)
			tab["$pp_colour_addr"] = Lerp(SysTime()-start, 0, 0.7)
			tab["$pp_colour_addg"] = Lerp(SysTime()-start, 0, 0.3)
			tab["$pp_colour_addb"] = Lerp(SysTime()-start, 0, 1.5)
			DrawColorModify(tab)

			render.SetStencilWriteMask( 0xFF )
			render.SetStencilTestMask( 0xFF )
			render.SetStencilReferenceValue( 0 )
			render.SetStencilCompareFunction( STENCIL_ALWAYS )
			render.SetStencilPassOperation( STENCIL_KEEP )
			render.SetStencilFailOperation( STENCIL_KEEP )
			render.SetStencilZFailOperation( STENCIL_KEEP )
			render.ClearStencil()

			render.SetStencilEnable(true)
			render.SetStencilCompareFunction( STENCIL_NEVER )
			render.SetStencilFailOperation( STENCIL_REPLACE )

			render.SetStencilReferenceValue( 1 )
			render.SetStencilWriteMask( 1 )
			for _, ent in pairs(ents.GetAll()) do
				if ent:IsPlayer() or ent:IsNPC() and ent:GetRenderFX() != 23 and ent != LocalPlayer() then
					local tr = util.TraceLine( {
						start = LocalPlayer():EyePos(),
						endpos = ent:GetPos() + Vector(0,0,10),
						filter = LocalPlayer()
					} )

					if not tr.HitWorld then
						ent:DrawModel()
					end
				end
			end
			render.SetStencilTestMask(1)
			render.SetStencilReferenceValue( 1 )
			render.SetStencilCompareFunction( STENCIL_EQUAL )
			render.ClearBuffersObeyStencil( 242, 242, 33, 255, false )
	
			render.SetStencilEnable(false)
		end)

		hook.Add("RenderScreenspaceEffects", "Deno_TFA_Thermal_Darken", function()
			DrawBloom( 0.5, 2, 9, 9, 1, 1, 0.5, 0.25, 1 )
		end)
	end

	function PLAYER:DeactivateThermal(doAnim)
		if(doAnim) then
			local tab = {
				[ "$pp_colour_colour" ] = 1,
				[ "$pp_colour_mulr" ] = 0,
				[ "$pp_colour_mulg" ] = 0,
				[ "$pp_colour_mulb" ] = 0
			}
			local start = SysTime()

			hook.Add("PostDrawOpaqueRenderables", "Deno_TFA_Thermal_Highlight", function()
				tab["$pp_colour_brightness"] = Lerp((SysTime()-start) / 0.25, -0.2, 1)
				tab["$pp_colour_contrast"] = Lerp((SysTime()-start) / 0.25, 0.1, 0.5)
				tab["$pp_colour_addr"] = Lerp((SysTime()-start) / 0.25, 0.7, 0)
				tab["$pp_colour_addg"] = Lerp((SysTime()-start) / 0.25, 0.3, 0)
				tab["$pp_colour_addb"] = Lerp((SysTime()-start) / 0.25, 1.5, 0)

				DrawColorModify(tab)

				if tab["$pp_colour_brightness"] == 1 then
					hook.Remove("PostDrawOpaqueRenderables", "Deno_TFA_Thermal_Highlight")
				end
			end)
		else
			hook.Remove("PostDrawOpaqueRenderables", "Deno_TFA_Thermal_Highlight")
		end

		hook.Remove("RenderScreenspaceEffects", "Deno_TFA_Thermal_Darken")
	end

	net.Receive("Deno_TFA_Thermal_Activate", function()
		local wep = net.ReadEntity()

		if not IsValid(wep) then return end

		local previous = wep:GetIronSights()
		timer.Create("Deno_TFA_Thermal_Scoped", 0, 0, function()
			if not IsValid(wep) then return end
			
			local scoped = wep:GetIronSights()

			if scoped == true and previous == false then
				LocalPlayer():ActivateThermal()
			elseif scoped == false and previous == true then
				LocalPlayer():DeactivateThermal(true)
			end
			previous = scoped
		end)
	end)

	net.Receive("Deno_TFA_Thermal_Deactivate", function()
		timer.Remove("Deno_TFA_Thermal_Scoped")
		LocalPlayer():DeactivateThermal(false)
	end)
end

function ATTACHMENT:Attach(wep)
	if SERVER then
		net.Start("Deno_TFA_Thermal_Activate")
		net.WriteEntity(wep)
		net.Send(wep:GetOwner())
	end
end

function ATTACHMENT:Detach(wep)
	if SERVER then
		net.Start("Deno_TFA_Thermal_Deactivate")
		net.Send(wep:GetOwner())
	end
end

if not TFA_ATTACHMENT_ISUPDATING then
	TFAUpdateAttachments()
end
