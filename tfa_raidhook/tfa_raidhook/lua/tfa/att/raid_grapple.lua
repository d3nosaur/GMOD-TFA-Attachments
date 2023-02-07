if not ATTACHMENT then
	ATTACHMENT = {}
end

sound.Add( {
	name = "shoot_hook",
	channel = CHAN_WEAPON,
	volume = .4,
	level = 75,
	pitch = 100,
	sound = "bobble/grapple_hook/grappling_hook_shoot.mp3"
	-- sound = "weapons/crossbow/fire1.wav"
} )
local RemoveSound = Sound( "weapons/crossbow/reload1.wav" )

ATTACHMENT.Name = "Grapple Hook Module"
ATTACHMENT.ShortName = "G.H."
ATTACHMENT.Icon = "bobble/rhook.png"
ATTACHMENT.Description = {
    TFA.AttachmentColors["="], "Change to the Grapple Hook Module.",
}

ATTACHMENT.WeaponTable = {
	["Primary"] = {
		["ClipSize"] = 1,
		["DefaultClip"] = 1,
		["Automatic"] = false,
		["Sound"] = "",
		["KickUp"] = function(wep,stat) return stat * 4 end,
		["KickDown"] = function(wep,stat) return stat * 4 end,
	},
}

function CreateHook(attachment)
	if IsValid(attachment.Hook) then
		attachment.Hook:Remove()
	end
	
	if IsValid(attachment.Owner.rhook) then
		attachment.Owner.rhook:Remove()
	end
	
	local ang = attachment.Owner:EyeAngles()
	ang:RotateAroundAxis(attachment.Owner:GetAimVector(),120)
	ang:RotateAroundAxis(attachment.Owner:GetRight(),0)
	ang:RotateAroundAxis(attachment.Owner:GetUp(),-90)
	
	local ent = ents.Create("ent_grapplehook")
	ent:SetOwner(attachment.Owner)
	-- ent:SetUser(self.Owner)
	ent:SetPos(attachment.Owner:GetShootPos()-attachment.Owner:GetAimVector()*10+attachment.Owner:GetRight()*6)
	ent:SetAngles(ang)
	ent:Spawn()
	ent:GetPhysicsObject():ApplyForceCenter(attachment.Owner:GetAimVector()*(rhook.ShootPower or 2000))
	ent:GetPhysicsObject():AddAngleVelocity( Vector(-100,0,0) )
	attachment.Owner.rhook = ent
	attachment.Owner:DeleteOnRemove(ent)
	
	return ent
end

function ATTACHMENT:ShootBullet(...)
    if CLIENT then return end

    if not self.CanShoot then
        self.Owner:GetActiveWeapon():Reload()
        return
    end

    self.Hook = CreateHook(self)

    if IsValid(self.Hook) then
        self.Owner:EmitSound( "bobble/grapple_hook/grappling_hook_shoot.mp3", 75,100,1,CHAN_WEAPON )
        
        self.Owner:GetActiveWeapon():SendWeaponAnim( ACT_VM_PRIMARYATTACK )

        self.Owner:GetActiveWeapon():SetNextPrimaryFire( CurTime() + 0.5 )
		self.Owner:SetAnimation( PLAYER_ATTACK1 )

        timer.Create("emptyanim"..self.Owner:EntIndex(),self:SequenceDuration()+.1,1,function()
			if IsValid(self) then
				self.Owner:GetActiveWeapon():SendWeaponAnim( ACT_VM_FIDGET )
			end
		end)

        self.CanShoot = false
    else
        self.Owner:GetActiveWeapon():SetNextPrimaryFire(CurTime() + 1)
    end

    return
end

function ATTACHMENT:Reload()
	if SERVER and not self.CanShoot then
        if(IsValid(self.Hook)) then
            self.Hook:Remove()
        end

        self.Owner:EmitSound( RemoveSound, 75,100,1,CHAN_WEAPON )

		timer.Remove("emptyanim"..self.Owner:EntIndex())
		self.Owner:GetActiveWeapon():SendWeaponAnim( ACT_VM_RELOAD )

		self.Owner:GetActiveWeapon():SetNextPrimaryFire( CurTime() + self:SequenceDuration() )
		self.Owner:SetAnimation( PLAYER_RELOAD )

		self.CanShoot = true

		timer.Simple(1, function()
			self.Owner:GetActiveWeapon():SetClip1(1)
		end)
    end
	return
end

function ATTACHMENT:Holster()
    if SERVER and IsValid(self.Hook) and self.Hook:GetFlying() then
        self.Hook:Remove()
    end

    if CLIENT and IsValid(self.Owner) then
        local vm = self.Owner:GetViewModel()
		if IsValid(vm) then
			//self:ResetBonePositions(vm)
		end
    end

    return true
end

function ATTACHMENT:Attach(wep)
	if not rhook then 
		print("Raid Hook is not installed")
		return 
	end

	wep:Unload()
	wep:Reload( true )

	wep.ShootBullet = self.ShootBullet
    wep.Reload = self.Reload
	//wep.Holster = self.Holster

	wep:Reload()
end

function ATTACHMENT:Detach(wep)
	if not rhook then 
		print("Raid Hook is not installed")
		return 
	end

    timer.Remove("emptyanim" .. wep.Owner:EntIndex())
    self:Holster()

	wep.ShootBullet = baseclass.Get(wep.Base).ShootBullet
    wep.Reload = baseclass.Get(wep.Base).Reload
    //wep.Holster = baseclass.Get(wep.Base).Holster

	wep:Unload()
	wep:Reload( true )
end

if not TFA_ATTACHMENT_ISUPDATING then
	TFAUpdateAttachments()
end
