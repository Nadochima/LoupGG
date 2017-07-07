AddCSLuaFile()

if CLIENT then
  SWEP.PrintName = "Vote"
  SWEP.Slot = 1
  SWEP.SlotPos = 1
  SWEP.DrawAmmo = false
  SWEP.DrawCrosshair = false
end

SWEP.Author = ""
SWEP.Instructions = "Left click to vote\n"
SWEP.Contact = ""
SWEP.Purpose = ""
SWEP.WorldModel = ""
SWEP.ViewModelFOV = 62
SWEP.ViewModelFlip = false
SWEP.AnimPrefix  = "rpg"
SWEP.UseHands = true
SWEP.Spawnable = true
SWEP.AdminOnly = true
SWEP.Category = "LoupGG"
SWEP.Sound = ""
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = 0
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = 0
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""

function SWEP:Initialize()
  self:SetHoldType("normal")
end

function SWEP:Deploy()
  if CLIENT or not IsValid(self:GetOwner()) then return true end
  self:GetOwner():DrawWorldModel(false)
  return true
end

function SWEP:Holster()
  return true
end

function SWEP:PreDrawViewModel()
  return true
end

function SWEP:PrimaryAttack()
  self:SetNextPrimaryFire(CurTime() + 0.1)
  if SERVER then
    local choices = {}
    for k,v in pairs(LoupGG.game.players) do
      local p = player.GetBySteamID64(k)
      if p then
        table.insert(choices,{k,p:Nick()})
      end
    end

    LoupGG:RequestChoice(self:GetOwner(), "Vote", choices, function(ply, choice)
      local p = player.GetBySteamID64(choice)
      if p then
        LoupGG:PlayerChat(ply, "Voted for "..p:Nick())
      end
    end)
  end
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
end
