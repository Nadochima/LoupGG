AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("fonts.lua")

local GM = GM

include("shared.lua")

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

-- events

function GM:DoNextPhase()
  local phase = GM.game.phase
  if phase == PHASE.LOBBY then
    local pcount = table.Count(GM.game.players)
    if pcount >= 1 then
      GM:Chat(Color(0,255,0), "Begin game, "..pcount.." players registered.")
      GM:SetPhase(PHASE.DAY_VOTE)
      GM:AddCountdown(20) -- add 120s
    else
      GM:Chat(Color(255,0,0), "The game can't start because the minimum is 2 players.")
      GM:AddCountdown(30) -- add 30s
    end
  elseif phase == PHASE.DAY_VOTE then
    GM:SetPhase(PHASE.LOBBY)
    GM:AddCountdown(30) -- add 30s
  end
end

function GM:ShowTeam(ply)
  local id64 = ply:SteamID64()
  if GM.game.phase == PHASE.LOBBY and not GM.game.players[id64] then
    GM.game.players[id64] = true
    GM:Chat(ply:Nick().." registered for the next game.")
  end
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

function GM:PlayerSpawn(ply)
end

function GM:OnPhaseChange(pphase,nphase)
  if nphase == PHASE.LOBBY then
    GM:Chat("You can join the next game by pressing F2.")
  elseif nphase == PHASE.DAY_VOTE then
    -- give roles to players
    for k,v in pairs(GM.game.players) do
      local p = player.GetBySteamID64(k)
      if p then
        if math.random(0,2) == 0 then
          GM:PlayerJoinTeam(p, TEAM.WEREWOLF)
        else
          GM:PlayerJoinTeam(p, TEAM.VILLAGER)
        end
      end
    end

    GM:Chat(Color(255,255,0), "The sun is rising on the village.")
  end
end

function GM:OnPlayerChangedTeam(ply, pteam, nteam)
  if nteam == TEAM.VILLAGER then
    GM:PlayerChat(ply, Color(0,255,0), "You are a villager.")
  elseif nteam == TEAM.WEREWOLF then
    GM:PlayerChat(ply, Color(255,0,0), "You are a werewolf.")
  end
end

function GM:PlayerDisconnected(ply)
  local id64 = ply:SteamID64()
  GM.game.players[id64] = nil

  -- chat info
  GM:Chat(ply:Nick().." disconnected.")
end
