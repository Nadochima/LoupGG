AddCSLuaFile()

if CLIENT then
  SWEP.PrintName = lang.item.seer_eye.title()
  SWEP.Slot = 1
  SWEP.SlotPos = 1
  SWEP.DrawAmmo = false
  SWEP.DrawCrosshair = false
end

SWEP.Author = ""
SWEP.Instructions = lang.item.seer_eye.help()
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
    local gp = LoupGG.game.players[ply:SteamID64()]
    if not gp.seen then gp.seen = {} end

    if LoupGG.game.phase == PHASE.NIGHT_POSTVOTE and gp and not gp.seer_ability_used then 
      local choices = {
        {"nobody",lang.common.nobody()}
      }

      for k,v in pairs(LoupGG.game.players) do
        local p = player.GetBySteamID64(k)
        if p and p:Team() ~= TEAM.DEAD and not gp.seen[k] then
          table.insert(choices,{k,p:Nick()})
        end
      end

      LoupGG:RequestChoice(ply, lang.item.seer_eye.title(), choices, function(ply, choice)
        local p = player.GetBySteamID64(choice)
        if p then -- inspect role
          local teamid = p:Team()

          gp.seer_ability_used = true
          gp.seen[choice] = true

          LoupGG:SetTag(ply, choice, "role", 999, team.GetColor(teamid), team.GetName(teamid))
          LoupGG:Chat(team.GetColor(TEAM.SEER), lang.item.seer_eye.inspected(), team.GetColor(teamid), team.GetName(teamid))
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
