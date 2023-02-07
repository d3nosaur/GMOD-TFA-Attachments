if not ATTACHMENT then
	ATTACHMENT = {}
end

if SERVER then
	util.AddNetworkString("Deno_Ricochet_Add")
	util.AddNetworkString("Deno_Ricochet_Remove")
end

local config = {
	["DamageMultiplier"] = 8, // Damage multiplier to increase shot damage by
	["NumRicochet"] = 5, // Number of times the bullet will bounce off of walls / NPCs
	["Clipsize"] = 5 // Number of shots per clip
}

ATTACHMENT.Name = "Ricochet Sniper Module"
ATTACHMENT.ShortName = "S.M."
ATTACHMENT.Icon = "entities/dc17m_sniper.png"
ATTACHMENT.Description = {
    TFA.AttachmentColors["="], "Change to the Sniper module.",
    TFA.AttachmentColors["+"], config["DamageMultiplier"] .. "x Damage",
    TFA.AttachmentColors["-"], "-265% RPM",
    TFA.AttachmentColors["-"], "+100% Kickback",
    TFA.AttachmentColors["="], config["Clipsize"] .. " Cell/Clip",
}

ATTACHMENT.WeaponTable = {
	["Primary"] = {
		["KickUp"] = function(wep,stat) return stat * 2 end,
		["KickDown"] = function(wep,stat) return stat * 2 end,
		["ClipSize"] = config["Clipsize"],
		["RPM"] = 145,
		["Damage"] = function(wep,stat) return stat * config["DamageMultiplier"] end,
	},
}

if CLIENT then
	local Laser = Material( "cable/redlaser" )
	local function reflect(count, src, dir)
		if count <= 0 then return end

		local tr = util.QuickTrace(src, dir * 10000, LocalPlayer())
		if tr.HitSky or !tr.Hit then return end
		
		render.SetMaterial( Laser )
		render.DrawBeam((count == config["NumRicochet"] and Vector(src.x, src.y, src.z-3) or src), tr.HitPos, 2, 1, 1, Color(180, 0, 0, 60))

		if IsValid(tr.Entity) then
			local ent = {}
			if tr.Entity:IsNPC() or tr.Entity:IsPlayer() then
				table.insert(ent, tr.Entity)
				halo.Add(ent, Color(255, 0, 0), 2, 2, 1, true, true)
				return
			end
		end

		local refVect = -1 * ((2*(tr.HitNormal*dir))*tr.HitNormal-dir)
		reflect(count-1, tr.HitPos, refVect)
	end

	net.Receive("Deno_Ricochet_Add", function()
		local wep = net.ReadEntity()

		hook.Add("HUDPaint", "DC17m_Sniper_Ricochet", function()
			if(LocalPlayer():GetActiveWeapon() == wep) then
				cam.Start3D()
					local src = LocalPlayer():GetShootPos()
					local dir = LocalPlayer():GetAimVector()

					reflect(config["NumRicochet"], src, dir)
				cam.End3D()
			end
		end)
	end)

	net.Receive("Deno_Ricochet_Remove", function()
		hook.Remove("HUDPaint", "DC17m_Sniper_Ricochet")
	end)
end

function RicochetBullet(gun, count, bullet, hitTable)
	if count <= 0 then return end

	local tr = util.QuickTrace(bullet.Src, bullet.Dir*10000, gun.Owner)

	if tr.HitSky or !tr.Hit then return end

	local data = EffectData()
	data:SetEntity(gun)
	data:SetStart(bullet.Src)
	data:SetOrigin(tr.HitPos)
	util.Effect(gun.TracerName, data)

	if IsValid(tr.Entity) then
		if tr.Entity:IsNPC() then
			local npc = tr.Entity
			hitTable[npc] = true

			for _,v in ipairs(ents.FindInSphere(npc:GetPos(), 500)) do
				if IsValid(v) and v:IsNPC() and hitTable[v] == nil and v:Health() > 0 then
					bullet.Src = tr.HitPos
					bullet.Dir = v:GetPos() - npc:GetPos()

					RicochetBullet(gun, count-1, bullet, hitTable)
					break
				end
			end
			gun.Owner:FireBullets(bullet)
			return
		end

		if tr.Entity:IsPlayer() and tr.Entity != gun.Owner then
			local ply = tr.Entity
			hitTable[ply] = true

			for _,v in ipairs(ents.FindInSphere(ply:GetPos(), 500)) do
				if IsValid(v) and v:IsPlayer() and hitTable[v] == nil and v:Alive() then
					bullet.Src = tr.HitPos
					bullet.Dir = v:GetPos() - ply:GetPos()

					RicochetBullet(gun, count-1, bullet, hitTable)
					break
				end
			end
			gun.Owner:FireBullets(bullet)
			return
		end
	end

	local refVect = -1 * ((2*(tr.HitNormal*bullet.Dir))*tr.HitNormal-bullet.Dir)

	gun.Owner:FireBullets(bullet)

	bullet.Src = tr.HitPos
	bullet.Dir = refVect

	RicochetBullet(gun, count-1, bullet, hitTable)
end

function ATTACHMENT:ShootBullet(damage, recoil, num_bullets, aimcone, disablericochet, bulletoverride)
	num_bullets 		= num_bullets or 1
	aimcone 			= aimcone or 0

	self.MainBullet.Num 		= num_bullets
	self.MainBullet.Src 		= self.Owner:GetShootPos()			-- Source
	self.MainBullet.Dir 		= self.Owner:GetAimVector()			-- Dir of bullet
	self.MainBullet.Spread.x=aimcone-- Aim Cone X
	self.MainBullet.Spread.y=aimcone-- Aim Cone Y
	self.MainBullet.Tracer	= 0							-- Show a tracer on every x bullets
	self.MainBullet.TracerName = "nil"
	self.MainBullet.Force	= damage/3 * math.sqrt((self.Primary.KickUp+self.Primary.KickDown+self.Primary.KickHorizontal )) * GetConVarNumber("sv_tfa_force_multiplier",1) * self:GetAmmoForceMultiplier()				-- Amount of force to give to phys objects
	self.MainBullet.Damage	= damage

	self.lastbul = self.MainBullet
	self.lastbulnoric = disablericochet
	self:Recoil( recoil )

	local hitTable = {}
	self.Owner:LagCompensation(true)
	RicochetBullet(self, config["NumRicochet"], self.MainBullet, hitTable)
	self.Owner:LagCompensation(false)
	return
end

function ATTACHMENT:Attach(wep)
	wep.ShootBullet = self.ShootBullet

	wep:Unload()
	wep:Reload( true )

	if SERVER then
		net.Start("Deno_Ricochet_Add")
		net.WriteEntity(wep)
		net.Send(wep:GetOwner())
	end
end


function ATTACHMENT:Detach(wep)
	wep.ShootBullet = baseclass.Get(wep.Base).ShootBullet

	wep:Unload()
	wep:Reload( true )

	if SERVER then
		net.Start("Deno_Ricochet_Remove")
		net.Send(wep:GetOwner())
	end
end

if not TFA_ATTACHMENT_ISUPDATING then
	TFAUpdateAttachments()
end
