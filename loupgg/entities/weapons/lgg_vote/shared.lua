AddCSLuaFile()

if CLIENT then
  SWEP.PrintName = lang.item.vote.title()
  SWEP.Slot = 1
  SWEP.SlotPos = 1
  SWEP.DrawAmmo = false
  SWEP.DrawCrosshair = false
end

SWEP.Author = ""
SWEP.Instructions = lang.item.vote.help()
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
    local p = self:GetOwner()
    if LoupGG.game.phase == PHASE.DAY_VOTE then -- DAY VOTE
      local choices = {
        {"nobody",lang.common.nobody()}
      }
      for k,v in pairs(LoupGG.game.players) do
        local p = player.GetBySteamID64(k)
        if p and p:Team() ~= TEAM.DEAD then
          table.insert(choices,{k,p:Nick()})
        end
      end

      LoupGG:RequestChoice(self:GetOwner(), lang.item.vote.title(), choices, function(ply, choice)
        local p = player.GetBySteamID64(choice)
        local id64 = ply:SteamID64()
        local gp = LoupGG.game.players[id64]
        if choice ~= "" and gp.vote ~= choice then
          local old_vote = gp.vote

          if LoupGG.game.players[choice] then
            -- info
            LoupGG:Chat(Color(255,0,0), lang.item.vote.voted(ply:Nick(),p:Nick()))
            LoupGG:SetTag(nil, id64, "votefor", 499, Color(255,0,0), "-> "..p:Nick())

            gp.vote = choice

            -- update vote for target
            LoupGG:SetTag(nil, choice, "votes", 500, Color(255,0,0), lang.common.votes(LoupGG:CountVotes(choice)))
          else
            gp.vote = "nobody"
            LoupGG:Chat(Color(255,0,0), lang.item.vote.voted(ply:Nick(),lang.common.nobody()))
            LoupGG:SetTag(nil, id64, "votefor", -1, Color(255,0,0), "")
          end

          -- update vote for previous target
          if LoupGG.game.players[old_vote or "nobody"] then
            LoupGG:SetTag(nil, old_vote, "votes", 500, Color(255,0,0), lang.common.votes(LoupGG:CountVotes(old_vote)))
          end
        end
      end)
    elseif LoupGG.game.phase == PHASE.NIGHT_VOTE then -- NIGHT VOTE
      local werewolves = team.GetPlayers(TEAM.WEREWOLF)

      local choices = {
        {"nobody",lang.common.nobody()}
      }

      for k,v in pairs(LoupGG.game.players) do
        local p = player.GetBySteamID64(k)
        if p and p:Team() ~= TEAM.WEREWOLF and p:Team() ~= TEAM.DEAD then
          table.insert(choices,{k,p:Nick()})
        end
      end

      LoupGG:RequestChoice(self:GetOwner(), lang.item.vote.title(), choices, function(ply, choice)
        local p = player.GetBySteamID64(choice)
        local id64 = ply:SteamID64()
        local gp = LoupGG.game.players[id64]
        if gp.vote ~= choice then
          local old_vote = gp.vote

          if LoupGG.game.players[choice] then
            -- info
            LoupGG:SetTag(werewolves, id64, "votefor", 499, Color(255,0,0), "-> "..p:Nick())

            gp.vote = choice
          else
            gp.vote = "nobody"
            LoupGG:SetTag(werewolves, id64, "votefor", -1, Color(255,0,0), "")
          end
        end
      end)
    end
  end
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
end
