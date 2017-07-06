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
  VILLAGER = 1,
  WEREWOLF = 2
}

-- init phases
PHASE = {
  LOBBY = 0, -- waiting for people to register for the next game
  DAY_VOTE = 1 -- day vote
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
  team.SetUp(TEAM.VILLAGER, "Villager", Color(0,255,0))
  team.SetUp(TEAM.WEREWOLF, "Werewolf", Color(255,0,0))
end
