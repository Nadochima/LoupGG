include("gui.lua")

local GM = GM
DeriveGamemode("sandbox")

GM.Name = "LoupGG"
GM.Author = "Nadochima & ImagicTheCat"
GM.Email = "N/A"
GM.Website = "https://github.com/Nadochima/LoupGG"

function GM:Initialize()
end

-- init teams
TEAM = {
  NONE = TEAM_UNASSIGNED,
  SPECTATOR = 1,
  VILLAGER = 2,
  WEREWOLF = 3,
  DEAD = 4,
  SORCERER = 5,
  SAVIOR = 6,
  SEER = 7,
  HUNTER = 8,
  CUPID = 9,
  SISTER = 10
}

-- init phases
PHASE = {
  LOBBY = 0, -- waiting for people to register for the next game
  DAY_VOTE = 1, -- day vote
  NIGHT_VOTE = 2,
  NIGHT_POSTVOTE = 3,
  HUNTER = 4
}

-- init shared game data
GM.game = {
  countdown = 0, -- game countdown for phases
  phase = 0
}

-- create countdown
timer.Create("gm_countdown", 1, 0, function()
  GM.game.countdown = GM.game.countdown-1
  if GM.OnCountdown then GM:OnCountdown() end -- OnCountdown event
  if GM.game.countdown <= 0 and GM.DoNextPhase then GM:DoNextPhase() end -- DoNextPhase event
end)

-- events
function GM:CreateTeams()
  team.SetUp(TEAM.SPECTATOR, "Spectator", Color(120,120,120))
  team.SetUp(TEAM.VILLAGER, "Villager", Color(0,255,0))
  team.SetUp(TEAM.WEREWOLF, "Werewolf", Color(255,0,0))
  team.SetUp(TEAM.DEAD, "Dead", Color(125,0,0))
  team.SetUp(TEAM.SORCERER, "Sorcerer", Color(255,0,125))
  team.SetUp(TEAM.SAVIOR, "Savior", Color(255,255,0))
  team.SetUp(TEAM.SEER, "Seer", Color(121,33,255))
  team.SetUp(TEAM.HUNTER, "Hunter", Color(104,130,0))
  team.SetUp(TEAM.CUPID, "Cupid", Color(255,0,255))
  team.SetUp(TEAM.SISTER, "Sister", Color(0,135,255))
end

-- EXTEND SOME GMOD FUNCTIONS, DANGER ZONE

local Player = FindMetaTable("Player")
-- Player:SteamID64() with bot support
local Player_SteamID64 = Player.SteamID64
function Player:SteamID64()
  if self:IsBot() then
    return "BOT_"..self:Nick()
  else
    return Player_SteamID64(self)
  end
end

-- player.GetBySteamID64() with bot support
local player_GetBySteamID64 = player.GetBySteamID64
function player.GetBySteamID64(id64)
  if string.sub(id64,1,4) == "BOT_" then -- get bot by nickname
    local nick = string.sub(id64,5)

    for k,v in pairs(player.GetBots()) do
      if v:Nick() == nick then
        return v
      end
    end
  else
    return player_GetBySteamID64(id64)
  end
end
