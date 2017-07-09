AddCSLuaFile()

if CLIENT then
  SWEP.PrintName = lang.item.life_potion.title()
  SWEP.Slot = 1
  SWEP.SlotPos = 1
  SWEP.DrawAmmo = false
  SWEP.DrawCrosshair = false
end

SWEP.Author = ""
SWEP.Instructions = lang.item.life_potion.help()
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
  if SERVER then -- do vote
    local ply = self:GetOwner()
    if LoupGG.game.phase == PHASE.NIGHT_POSTVOTE and LoupGG.game.night_vote ~= nil then 
      local p = player.GetBySteamID64(LoupGG.game.night_vote)
      local choices = {
        {"nobody",lang.common.nobody()}
      }

      if p then
        table.insert(choices, {LoupGG.game.night_vote, p:Nick()})
      end

      LoupGG:RequestChoice(ply, lang.item.life_potion.title(), choices, function(ply, choice)
        local p = player.GetBySteamID64(choice)
        local gp = LoupGG.game.players[ply:SteamID64()]
        if gp and p then -- save the target
          LoupGG.game.night_vote = nil 
          gp.life_potion_used = true
          LoupGG:PlayerChat(ply, Color(0,255,0), lang.item.life_potion.used(p:Nick()))
        end
      end)
    else
      LoupGG:PlayerChat(ply, lang.item.cant_use())
    end
  end
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
end
