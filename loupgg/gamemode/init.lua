AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("fonts.lua")
AddCSLuaFile("commands.lua")
AddCSLuaFile("gui.lua")

local GM = GM
LoupGG = GM

include("shared.lua")
include("commands.lua")

-- init data folder
if !file.Exists("loupgg","DATA") then file.CreateDir("loupgg") end
if !file.Exists("loupgg/maps","DATA") then file.CreateDir("loupgg/maps") end


util.AddNetworkString("gm_chat")
util.AddNetworkString("gm_countdown")
util.AddNetworkString("gm_phase")

GM.game.phase = PHASE.LOBBY
GM.game.players = {}

-- API

local function build_chat_message(...)
  local args = {...}
  net.WriteInt(#args,32)
  for k,v in pairs(args) do
    if type(v) == "table" then
      net.WriteInt(0,32)
      net.WriteColor(v)
    else
      net.WriteInt(1,32)
      net.WriteString(tostring(v))
    end
  end
end

-- send chat message to all clients (supported types: color, string)
function GM:Chat(...) 
  net.Start("gm_chat")
    build_chat_message(...)
  net.Broadcast()
end

-- same as GM:Chat for a single player
function GM:PlayerChat(ply, ...) 
  net.Start("gm_chat")
    build_chat_message(...)
  net.Send(ply)
end

-- add seconds to the countdown
function GM:AddCountdown(n)
  GM:SetCountdown(GM.game.countdown+n)
end

function GM:SetCountdown(v)
  GM.game.countdown = v
  -- update countdown
  net.Start("gm_countdown")
    net.WriteInt(GM.game.countdown,32)
  net.Broadcast()
end

function GM:SetPhase(phase)
  if GM.OnPhaseChange then GM:OnPhaseChange(GM.game.phase, phase) end -- OnPhaseChange event (old,new)

  GM.game.phase = phase
  net.Start("gm_phase")
    net.WriteInt(GM.game.phase,32)
  net.Broadcast()
end

function GM:GetVillagerSeats()
  local r = {}
  for k,v in pairs(ents.FindByClass("prop_vehicle_prisoner_pod")) do
    if v:GetModel() == "models/nova/airboat_seat.mdl" then
      table.insert(r, v)
    end
  end

  return r
end

function GM:SetTeam(ply, teamid)
  ply:SetTeam(teamid)

  if nteam == TEAM.VILLAGER then
    GM:PlayerChat(ply, Color(0,255,0), "You are a villager.")
  elseif nteam == TEAM.WEREWOLF then
    GM:PlayerChat(ply, Color(255,0,0), "You are a werewolf.")
  elseif nteam == TEAM.DEAD then
    GM:PlayerChat(ply, Color(125,0,0), "You are dead.")
  end

  -- display role tag for the player
  GM:SetTag(ply, ply:SteamID64(), "role", 999, team.GetColor(teamid), team.GetName(teamid))

  -- share role
  if teamid == TEAM.WEREWOLF or teamid == TEAM.DEAD then
    GM:SetTag(team.GetPlayers(teamid), ply:SteamID64(), "role", 999, team.GetColor(teamid), team.GetName(teamid))
  end
end

function GM:TriggerDeath(steamid64) -- trigger the special death effects for the role
  local p = player.GetBySteamID64(steamid64)
  if GM.game.players[steamid64] and p then
    GM:ApplyDeath(p)
  end
end

-- return true,winner_team if the game must end or false
function GM:CheckEndOfGame()
  if GM.game.phase ~= PHASE.LOBBY then
    -- no more werewolves
    local werewolves = 0
    local good_alives = 0
    local players = 0

    for k,v in pairs(GM.game.players) do
      local p = player.GetBySteamID64(k)
      if p then
        if p:Team() == TEAM.WEREWOLF then werewolves = werewolves+1 
        else good_alives = good_alives+1 end

        players = players+1
      end
    end

    if werewolves == 0 then return true,TEAM.VILLAGER end
    if good_alives < 2 then return true,TEAM.WEREWOLF end
  end

  return false
end

-- end the game if it must
function GM:TryEndGame()
  local gend,winner = GM:CheckEndOfGame() 
  if gend then
    GM:Chat(team.GetColor(winner), "The "..team.GetName(winner).." team win !")
    GM:SetPhase(PHASE.LOBBY)
    GM:SetCountdown(30)
  end

  return gend
end

function GM:ApplyDeath(ply) -- real dead now
  GM:SetTeam(ply, TEAM.DEAD)
  GM:Chat(ply:Nick().." is dead.")
  ply:Kill()
end

function GM:CountVotes(steamid64)
  local count = 0
  for k,v in pairs(GM.game.players) do
    if v.vote == steamid64 then
      count = count+1
    end
  end

  return count
end

-- return nil if no one valid voted once, or the steamid64
function GM:GetMostVoted()
  local voted = {}
  local max = 0
  local kmax = ""
  for k,v in pairs(GM.game.players) do
    if voted[v.vote] == nil then
      voted[v.vote] = 1
    else
      voted[v.vote] = voted[v.vote]+1
    end

    local count = voted[v.vote]
    if count > max then
      max = count
      kmax = v.vote 
    end
  end

  -- check validity
  if not player.GetBySteamID64(kmax) then
    kmax = nil
  end

  -- check equality
  if kmax then
    for k,v in pairs(voted) do
      if v == max and k ~= kmax then
        kmax = nil
        break
      end
    end
  end

  return kmax
end

-- events

-- when the timer reach 0, go to the next phase
function GM:DoNextPhase()
  local phase = GM.game.phase
  if phase == PHASE.LOBBY then
    local pcount = table.Count(GM.game.players)
    if pcount >= 1 then
      GM:Chat(Color(0,255,0), "Begin game, "..pcount.." players registered.")

      -- give roles to players
      for k,v in pairs(GM.game.players) do
        local p = player.GetBySteamID64(k)
        if p then
          if math.random(0,2) == 0 then
            GM:SetTeam(p, TEAM.WEREWOLF)
          else
            GM:SetTeam(p, TEAM.VILLAGER)
          end

          GM:SetTag(nil, k, "pseudo", 1000, Color(255,255,255), p:Nick())
        end
      end

      -- remove player weapons
      local players = player.GetAll()
      for k,v in pairs(players) do
        v:StripWeapons()
      end

      GM:SetPhase(PHASE.DAY_VOTE)
      GM:AddCountdown(120) -- add 120s
    else
      GM:Chat(Color(255,0,0), "The game can't start because the minimum is 2 players.")
      GM:AddCountdown(30) -- add 30s
    end
  elseif phase == PHASE.DAY_VOTE then
    GM:SetPhase(PHASE.NIGHT_VOTE)
    GM:AddCountdown(60)
  elseif phase == PHASE.NIGHT_VOTE then
    GM:SetPhase(PHASE.DAY_VOTE)
    GM:AddCountdown(120)
  end

  GM:TryEndGame()
end

function GM:ShowTeam(ply)
  local id64 = ply:SteamID64()
  if GM.game.phase == PHASE.LOBBY and not GM.game.players[id64] then
    GM.game.players[id64] = {}
    GM:Chat(ply:Nick().." registered for the next game.")
  end
end

function GM:CanExitVehicle(ply, veh)
  return false
end

function GM:PlayerInitialSpawn(ply) 
  -- send game infos
  net.Start("gm_phase")
    net.WriteInt(GM.game.phase,32)
  net.Send(ply)

  net.Start("gm_countdown")
    net.WriteInt(GM.game.countdown,32)
  net.Send(ply)

  -- chat info
  GM:Chat(ply:Nick().." connected.")

  if GM.game.phase == PHASE.LOBBY then
    GM:PlayerChat(ply, "You can join the next game by pressing F2.")
  else
    GM:PlayerChat(ply, "A game is running, you can spectate and wait to join the next game.")
  end
end

-- when the phase change
function GM:OnPhaseChange(pphase,nphase)
  -- END
  if pphase == PHASE.DAY_VOTE then -- end of day
    -- count votes
    local id64 = GM:GetMostVoted()
    if id64 then
      local vp = player.GetBySteamID64(id64)
      GM:TriggerDeath(id64)
    end

    -- reset stuff
    for k,v in pairs(GM.game.players) do
      local p = player.GetBySteamID64(k)
      if p and p:Team() ~= TEAM.DEAD then
        p:StripWeapon("lgg_vote")
        GM:SetTag(nil, k, "votes", -1, Color(255,0,0), "")
        GM:SetTag(nil, k, "votefor", -1, Color(255,0,0), "")
        p:ExitVehicle()
        v.vote = nil
      end
    end
  elseif pphase == PHASE.NIGHT_VOTE then -- end of day
    -- count votes
    local id64 = GM:GetMostVoted()
    if id64 then
      local vp = player.GetBySteamID64(id64)
      GM:TriggerDeath(id64)
    end

    -- reset stuff
    local werewolves = team.GetPlayers(TEAM.WEREWOLF)
    for k,v in pairs(werewolves) do
      local id64 = v:SteamID64()
      v:StripWeapon("lgg_vote")
      GM:SetTag(nil, id64, "votefor", -1, Color(255,0,0), "")
      GM.game.players[id64].vote = nil
    end
  end

  -- BEGIN
  if nphase == PHASE.LOBBY then -- LOBBY
    -- reset teams
    local players = player.GetAll()
    for k,v in pairs(players) do
      local id64 = v:SteamID64()

      GM:SetTeam(v,TEAM.NONE)
      GM:SetTag(nil, id64, "votefor", -1, Color(255,0,0), "")
    end

    GM.game.players = {}
    GM:Chat("You can join the next game by pressing F2.")
  elseif nphase == PHASE.DAY_VOTE then -- DAY VOTE
    local seats = GM:GetVillagerSeats()
    local seat_count = 1

    GM:Chat(Color(255,255,0), "The sun is rising on the village.")
    for k,v in pairs(GM.game.players) do
      local p = player.GetBySteamID64(k)
      if p and p:Team() ~= TEAM.DEAD then
        p:SetAllowWeaponsInVehicle(true)
        p:EnterVehicle(seats[seat_count])
        seat_count = seat_count+1

        p:Give("lgg_vote")
        v.vote = "nobody"
        GM:SetTag(nil, k, "votes", 500, Color(255,0,0), "0 votes")
      end
    end
  elseif nphase == PHASE.NIGHT_VOTE then -- NIGHT VOTE
    GM:Chat(Color(150,0,0), "The night is falling on the village.")

    local werewolves = team.GetPlayers(TEAM.WEREWOLF)

    for k,v in pairs(werewolves) do
      v:Give("lgg_vote")
      GM.game.players[v:SteamID64()].vote = "nobody"
    end
  end
end

function GM:InitPostEntity() -- load map
  -- load map 
  local fname = "loupgg/maps/"..game.GetMap()..".txt"
  if file.Exists(fname,"DATA") then
    local data = util.JSONToTable(file.Read(fname,"DATA"))
    for k,v in pairs(data) do
      local ent = ents.Create("prop_vehicle_prisoner_pod")
      ent:SetModel("models/nova/airboat_seat.mdl")
      ent:SetKeyValue("vehiclescript", "scripts/vehicles/prisoner_pod.txt")
      ent:SetPos(Vector(v[1],v[2],v[3]))
      ent:SetAngles(Angle(v[4],v[5],v[6]))
      ent:Spawn()
      local phy = ent:GetPhysicsObject()
      if phy and phy:IsValid() then
        phy:EnableMotion(false)
      end
    end

    print("LoupGG: "..table.Count(data).." seats loaded.")
  end
end

function GM:PlayerDisconnected(ply)
  local id64 = ply:SteamID64()
  GM.game.players[id64] = nil

  -- chat info
  GM:Chat(ply:Nick().." disconnected.")
end
