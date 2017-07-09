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
  local pphase = GM.game.phase
  GM.game.phase = phase

  net.Start("gm_phase")
    net.WriteInt(GM.game.phase,32)
  net.Broadcast()

  print("set phase to "..table.KeyFromValue(PHASE, phase))

  if GM.OnPhaseChange then GM:OnPhaseChange(pphase, phase) end -- OnPhaseChange event (old,new)
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

function GM:GetHouseSpawns()
  local r = {}
  for k,v in pairs(ents.FindByClass("prop_*")) do
    if v:GetModel() == "models/props_lab/huladoll.mdl" then
      table.insert(r, v)
    end
  end

  return r
end

function GM:SetTeam(ply, teamid)
  -- sister check: same house
  if teamid == TEAM.SISTER then
    local sisters = team.GetPlayers(TEAM.SISTER)
    if #sisters >= 1 then
      local gp = GM.game.players[ply:SteamID64()]
      local sgp = GM.game.players[sisters[1]:SteamID64()]

      if gp and sgp then
        gp.house = sgp.house
      end
    end
  end

  ply:SetTeam(teamid)

  if teamid ~= TEAM.DEAD then
    GM:PlayerChat(ply, team.GetColor(teamid), "You are "..team.GetName(teamid)..".")
  end

  -- display role tag for the player
  GM:SetTag(ply, ply:SteamID64(), "role", 999, team.GetColor(teamid), team.GetName(teamid))

  if teamid == TEAM.SPECTATOR or teamid == TEAM.DEAD then -- spectate
    ply:Spectate(OBS_MODE_ROAMING)
  elseif teamid == TEAM.CUPID then -- cupid, ask to create couple
    local first_lover = nil
    local second_lover = nil

    local choices = {
      {"nobody","nobody"}
    }

    for k,v in pairs(GM.game.players) do
      local p = player.GetBySteamID64(k)
      if p and p:Team() ~= TEAM.DEAD then
        table.insert(choices,{k,p:Nick()})
      end
    end

    GM:RequestChoice(ply, "Make couple (1)", choices, function(ply, choice)
      first_lover = choice

      local choices = {
        {"nobody","nobody"}
      }

      for k,v in pairs(GM.game.players) do
        local p = player.GetBySteamID64(k)
        if p and p:Team() ~= TEAM.DEAD and k ~= first_lover then
          table.insert(choices,{k,p:Nick()})
        end
      end

      GM:RequestChoice(ply, "Make couple (2)", choices, function(ply, choice)
        second_lover = choice

        local pkeys = table.GetKeys(GM.game.players)

        -- make couple
        local fp = player.GetBySteamID64(first_lover)
        if not fp or not GM.game.players[first_lover] then -- select random
          local i = math.random(1,#pkeys)
          first_lover = pkeys[i]
          table.remove(pkeys, i)
          fp = player.GetBySteamID64(first_lover)
        end

        local sp = player.GetBySteamID64(second_lover)
        if not sp or not GM.game.players[second_lover] or second_lover == first_lover then -- select random
          local i = math.random(1,#pkeys)
          second_lover = pkeys[i]
          sp = player.GetBySteamID64(second_lover)
        end

        -- assign lovers

        local gfp = GM.game.players[first_lover]
        local gsp = GM.game.players[second_lover]
        gfp.lover = second_lover
        gsp.lover = first_lover
        gsp.house = gfp.house -- same house

        GM:SetTag(fp, second_lover, "lover", 998, team.GetColor(TEAM.CUPID), "Lover")
        GM:SetTag(sp, first_lover, "lover", 998, team.GetColor(TEAM.CUPID), "Lover")

        GM:PlayerChat(fp, team.GetColor(TEAM.CUPID), "You are in love with "..sp:Nick()..".")
        GM:PlayerChat(sp, team.GetColor(TEAM.CUPID), "You are in love with "..fp:Nick()..".")

        GM:PlayerChat(ply, team.GetColor(TEAM.CUPID), fp:Nick().." and "..sp:Nick().." are now in love.")
      end)
    end)
  end

  -- shared role tags
  if teamid == TEAM.WEREWOLF or teamid == TEAM.SISTER or teamid == TEAM.DEAD or teamid == TEAM.SPECTATOR then
    local list = team.GetPlayers(teamid)
    -- new member
    GM:SetTag(list, ply:SteamID64(), "role", 999, team.GetColor(teamid), team.GetName(teamid))

    -- already presents members
    for k,v in pairs(list) do
      GM:SetTag(ply, v:SteamID64(), "role", 999, team.GetColor(teamid), team.GetName(teamid))
    end
  end
end

-- called to check if a player can hear/read other player voice/chat
function GM:CanPerceive(listener, talker, is_voice)
  -- return true to enable hear/read

  if GM.game.phase == PHASE.LOBBY then
    return true
  elseif GM.game.phase == PHASE.DAY_VOTE then -- day vote, alives can talk/hear
    local gpl = GM.game.players[listener:SteamID64()]
    local gpt = GM.game.players[talker:SteamID64()]

    -- no chat possible at day vote
    if gpl and gpt and talker:Team() ~= TEAM.DEAD and is_voice then return true end
  else -- NIGHT
    local gpl = GM.game.players[listener:SteamID64()]
    local gpt = GM.game.players[talker:SteamID64()]

    if gpl and gpt then -- playing
      if listener:Team() ~= TEAM.DEAD and talker:Team() ~= TEAM.DEAD then -- alive
        -- werewolves
        if listener:Team() == TEAM.WEREWOLF and talker:Team() == TEAM.WEREWOLF then return true
        -- lovers
        elseif gpl.lover == talker:SteamID64() and gpt.lover == listener:SteamID64() then return true
        -- sisters
        elseif listener:Team() == TEAM.SISTER and talker:Team() == TEAM.SISTER then return true
        end
      -- deads and shaman
      elseif listener:Team() == TEAM.SHAMAN and talker:Team() == TEAM.DEAD or talker:Team() == TEAM.SHAMAN and listener:Team() == TEAM.DEAD then return true
      end
    end
  end

  -- spectator, everyone and in function of distance for the voice
  if listener:Team() == TEAM.SPECTATOR then return (listener:GetPos():Distance(talker:GetPos()) <= 40*12) or not is_voice end

  return false
end

function GM:PlayerCanHearPlayersVoice(listener, talker)
  return GM:CanPerceive(listener, talker, true)
end

function GM:PlayerCanSeePlayersChat(txt, team_only, listener, talker)
  return GM:CanPerceive(listener, talker, false)
end

-- generate map of TEAM -> number for n players
function GM:GenerateDeck(n)
  local deck = {}
  local r = n
  local function add(n) -- manage rest
    local amount = math.min(n,r)
    r = r - amount
    return amount
  end

  deck[TEAM.WEREWOLF] = add(math.ceil(n*0.25))
  deck[TEAM.SORCERER] = add(1)
  deck[TEAM.SEER] = add(1)
  deck[TEAM.HUNTER] = add(1)
  deck[TEAM.CUPID] = add(1)
  deck[TEAM.SHAMAN] = add(1)
  deck[TEAM.SAVIOR] = add(1)
  if r >= 2 then
    deck[TEAM.SISTER] = add(2)
  end
  deck[TEAM.VILLAGER] = add(r) -- add the rest as villagers

  return deck
end

function GM:TriggerDeath(steamid64) -- trigger the special death effects for the role
  local p = player.GetBySteamID64(steamid64)
  local gp = GM.game.players[steamid64]
  if gp and p then
    if p:Team() == TEAM.HUNTER then -- hunter death, can kill someone in the next 10 seconds
      GM:AddCountdown(5)
      GM:Chat(team.GetColor(TEAM.HUNTER), team.GetName(TEAM.HUNTER).." last stand...")

      p:Give("weapon_shotgun")
      p:SelectWeapon("weapon_shotgun")

      if GM.game.phase == PHASE.NIGHT_VOTE then -- can't kill in front, ask target
        local choices = {
          {"nobody","nobody"}
        }
        for k,v in pairs(GM.game.players) do
          local p = player.GetBySteamID64(k)
          if p and p:Team() ~= TEAM.DEAD then
            table.insert(choices,{k,p:Nick()})
          end
        end

        GM:RequestChoice(p, "Last stand", choices, function(ply, choice)
          local p = player.GetBySteamID64(choice)
          if p and p:Team() ~= TEAM.DEAD then -- kill the target
            GM:TriggerDeath(choice)
            GM:ApplyDeath(ply)
          end
        end)
      end

      -- timeout hunter last stand
      timer.Simple(10, function()
        if p:Team() == TEAM.HUNTER then
          GM:ApplyDeath(p)
        end
      end)
    else
      GM:ApplyDeath(p)
    end

    if gp.lover ~= nil then -- lovers death
      local gpl = GM.game.players[gp.lover]
      local pl = player.GetBySteamID64(gp.lover)
      if gpl and pl then
        gpl.lover = nil -- prevent recursive call
        GM:Chat(team.GetColor(TEAM.CUPID), pl:Nick().." can't survive in this world without "..p:Nick()..".")
        GM:TriggerDeath(gp.lover)
      end
    end
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
        elseif p:Team() ~= TEAM.DEAD then good_alives = good_alives+1 end

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
    for k,v in pairs(GM.game.players) do
      local p = player.GetBySteamID64(k)
      if p then
        p:Kill()
      end
    end

    GM:Chat(team.GetColor(winner), "The "..team.GetName(winner).." team win !")
    GM:SetPhase(PHASE.LOBBY)
    GM:SetCountdown(30)
  end

  return gend
end

function GM:ApplyDeath(ply) -- real dead now
  GM:Chat(Color(50,0,0), ply:Nick().." is dead and was a ", team.GetColor(ply:Team()), team.GetName(ply:Team()))
  ply:Kill()
  GM:SetTeam(ply, TEAM.DEAD)
end

function GM:CountVotes(steamid64)
  local count = 0
  for k,v in pairs(GM.game.players) do
    local p = player.GetBySteamID64(k)
    if p and p:Team() ~= TEAM.DEAD and v.vote == steamid64 then
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
    local p = player.GetBySteamID64(k)
    if p and p:Team() ~= TEAM.DEAD and GM.game.players[v.vote or "nobody"] then
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

-- return list of players in game
--- policy_all: if true, will match everyone by default, if false, will math no one by default
--- team_list: list of teamid, negative teamid will be excluded, or nil for everyone playing
function GM:GetPlayers(policy_all, team_list)
  local r = {}
  for k,v in pairs(GM.game.players) do
    local p = player.GetBySteamID64(k)
    if p then
      if team_list then
        local excluded = false
        local ok = policy_all
        for l,w in pairs(team_list) do
          if w < 0 and p:Team() == math.abs(w) then excluded = true
          elseif p:Team() == w then ok = true end
        end

        if ok and not excluded then
          table.insert(r, p)
        end
      else
        table.insert(r, p)
      end
    end
  end

  return r
end

-- events

-- when the timer reach 0, go to the next phase
function GM:DoNextPhase()
  local phase = GM.game.phase
  if phase == PHASE.LOBBY then -- START A GAME
    -- bots auto join (for testing)
    local bots = player.GetBots()
    for k,v in pairs(bots) do
      GM:ShowTeam(v)
    end

    local pcount = table.Count(GM.game.players)
    if pcount >= 4 then
      GM:Chat(Color(0,255,0), "Begin game, "..pcount.." players registered.")

      -- give roles to players
      local deck = GM:GenerateDeck(pcount)
      local roles = {}
      for k,v in pairs(deck) do
        table.insert(roles, k)
      end

      local seats = GM:GetVillagerSeats()
      local houses = GM:GetHouseSpawns()

      for k,v in pairs(GM.game.players) do
        local p = player.GetBySteamID64(k)
        if p then
          -- select a role
          local selected_role = nil
          while selected_role == nil do
            local role = roles[math.random(1,#roles)]
            if deck[role] > 0 then
              deck[role] = deck[role]-1
              selected_role = role
            end
          end

          GM:SetTag(nil, k, "role", -1, Color(255,255,255), "")

          -- set role
          GM:SetTeam(p, selected_role)
          if not p:Alive() then
            p:Spawn()
          end
          GM:SetTag(nil, k, "pseudo", 1000, Color(255,255,255), p:Nick())

          -- select permanent seat
          if #seats > 0 then
            local i = math.random(1,#seats)
            v.seat = seats[i]
            table.remove(seats,i)
          end

          -- select permanent house
          if #houses > 0 then
            local i = math.random(1,#houses)
            v.house = houses[i]
            table.remove(houses,i)
          end
        end
      end

      -- remove player weapons
      local players = player.GetAll()
      for k,v in pairs(players) do
        v:StripWeapons()
      end

      GM:SetPhase(PHASE.DAY_VOTE)

      -- add rest in spectators
      local specs = team.GetPlayers(TEAM.NONE)
      for k,v in pairs(specs) do
        GM:SetTeam(v,TEAM.SPECTATOR)
      end
    else
      GM:Chat(Color(255,0,0), "The game can't start because the minimum is 4 players.")
      GM:AddCountdown(30) -- add 30s
    end
  elseif phase == PHASE.DAY_VOTE then
    GM:SetPhase(PHASE.NIGHT_VOTE)
  elseif phase == PHASE.NIGHT_VOTE then
    GM:SetPhase(PHASE.NIGHT_POSTVOTE)
  elseif phase == PHASE.NIGHT_POSTVOTE then
    GM:SetPhase(PHASE.DAY_VOTE)
  end

  GM:TryEndGame()
end

function GM:ShowTeam(ply)
  local id64 = ply:SteamID64()
  if GM.game.phase == PHASE.LOBBY and not GM.game.players[id64] then
    if table.Count(GM.game.players) < 16 then
      GM.game.players[id64] = {}
      GM:Chat(ply:Nick().." registered for the next game.")
    else
      GM:PlayerChat(ply, Color(255,0,0), "Game full.")
    end
  end
end

function GM:CanExitVehicle(ply, veh)
  return false
end

function GM:CanPlayerEnterVehicle(ply, veh, role)
  return GM.game.phase == PHASE.DAY_VOTE
end

function GM:EntityTakeDamage(ent, dmg) -- check hunter last stand with shotgun
  local from = dmg:GetAttacker()
  if ent:IsPlayer() and from:IsPlayer() then
    local idfrom = from:SteamID64()
    local ident = ent:SteamID64()

    if GM.game.players[idfrom] and GM.game.players[ident] and ent:Team() ~= TEAM.DEAD and from:Team() == TEAM.HUNTER then
      GM:TriggerDeath(ident)
      GM:ApplyDeath(from)
    end
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

  GM:SetTeam(ply,TEAM.NONE)

  if GM.game.phase == PHASE.LOBBY then
    GM:PlayerChat(ply, "You can join the next game by pressing F2.")
  else
    GM:PlayerChat(ply, "A game is running, you can spectate and wait to join the next game.")
    GM:SetTeam(ply, TEAM.SPECTATOR)
  end
end

function GM:PlayerSpawn(ply)
  self.BaseClass.PlayerSpawn(self,ply)
  ply:SetCustomCollisionCheck(true)
  ply:GodEnable() -- god mode
  if ply:Team() == TEAM.SPECTATOR or ply:Team() == TEAM.DEAD then 
    ply:Spectate(OBS_MODE_ROAMING)
  end
end

function GM:CanPlayerSuicide(ply)
  return false
end

-- when the phase change
function GM:OnPhaseChange(pphase,nphase)
  -- END
  if pphase == PHASE.DAY_VOTE then -- end of day
    -- count votes
    local id64 = GM:GetMostVoted()
    if id64 then
      local vp = player.GetBySteamID64(id64)
      GM:TriggerDeath(id64) -- kill voted
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
      GM.game.night_vote = id64 -- set night vote
    end

    -- saved by savior
    if GM.game.night_vote == GM.game.savior_target then
      GM.game.night_vote = nil
    end

    -- reset stuff
    local werewolves = team.GetPlayers(TEAM.WEREWOLF)
    for k,v in pairs(werewolves) do
      local id64 = v:SteamID64()
      v:StripWeapon("lgg_vote")
      GM:SetTag(nil, id64, "votefor", -1, Color(255,0,0), "")
      GM.game.players[id64].vote = nil
    end
  elseif pphase == PHASE.NIGHT_POSTVOTE then
    -- remove sorcerer stuff
    local sorcerers = team.GetPlayers(TEAM.SORCERER)
    if #sorcerers >= 1 then
      local sorcerer = sorcerers[1]
      sorcerer:StripWeapon("lgg_life_potion")
      sorcerer:StripWeapon("lgg_death_potion")
    end

    -- remove seer stuff
    local seers = team.GetPlayers(TEAM.SEER)
    if #seers >= 1 then
      local seer = seers[1]
      seer:StripWeapon("lgg_seer_eye")
    end

    -- trigger deaths
    if GM.game.night_vote then GM:TriggerDeath(GM.game.night_vote) end
    if GM.game.sorcerer_vote then GM:TriggerDeath(GM.game.sorcerer_vote) end
  end

  -- BEGIN
  if nphase == PHASE.LOBBY then -- LOBBY
    GM:AddCountdown(30)

    -- reset teams
    local players = player.GetAll()
    for k,v in pairs(players) do
      local id64 = v:SteamID64()
      v:UnSpectate() -- unspectate
      GM:SetTeam(v,TEAM.NONE)
      v:Spawn()

      GM:SetTag(nil, id64, "votefor", -1, Color(255,0,0), "")
      GM:SetTag(nil, id64, "lover", -1, Color(255,0,0), "")
    end

    GM.game.players = {}
    GM:Chat("You can join the next game by pressing F2.")
  elseif nphase == PHASE.DAY_VOTE then -- DAY VOTE
    GM:AddCountdown(math.min(10+10*#GM:GetPlayers(true, {-TEAM.DEAD}),120)) -- 10s and 10s per g

    GM:Chat(Color(255,255,0), "The sun is rising on the village.")

    local werewolves = team.GetPlayers(TEAM.WEREWOLF)

    for k,v in pairs(GM.game.players) do
      local p = player.GetBySteamID64(k)
      if p and p:Team() ~= TEAM.DEAD then
        if p:Team() == TEAM.WEREWOLF then -- reset werewolves
          GM:SetTag(nil, k, "pseudo", 1000, Color(255,255,255), p:Nick()) -- show pseudo tag
          if v.old_model then
            p:SetModel(v.old_model)
          end
        else
          -- show back good alives pseudo for werewolves
          GM:SetTag(werewolves, k, "pseudo", 1000, Color(255,255,255), p:Nick())
        end

        if IsValid(v.seat) then
          p:SetAllowWeaponsInVehicle(true)
          p:EnterVehicle(v.seat)
        end

        p:Give("lgg_vote")
        v.vote = "nobody"
        GM:SetTag(nil, k, "votes", 500, Color(255,0,0), "0 votes")
      end
    end
  elseif nphase == PHASE.NIGHT_VOTE then -- NIGHT VOTE
    GM:AddCountdown(math.min(10+10*#GM:GetPlayers(false, {TEAM.WEREWOLF}),40)) -- 10s and 10s per g
    GM:Chat(Color(150,0,0), "The night is falling on the village.")

    local good_alives = GM:GetPlayers(true, {-TEAM.DEAD, -TEAM.WEREWOLF})

    for k,v in pairs(GM.game.players) do
      local p = player.GetBySteamID64(k)
      if p and p:Team() ~= TEAM.DEAD then
        -- send to house if not werewolf
        if p:Team() ~= TEAM.WEREWOLF then
          if IsValid(v.house) then
            p:SetPos(v.house:GetPos())
          end
        else -- if werewolf, change skin
          v.old_model = p:GetModel()
          p:SetModel("models/player/zombie_fast.mdl")

          -- change werewolf pseudo tag for all good villagers
          GM:SetTag(good_alives, k, "pseudo", 1000, Color(255,150,70), team.GetName(TEAM.WEREWOLF))
        end
      end
    end

    local werewolves = team.GetPlayers(TEAM.WEREWOLF)
    -- hide good alives pseudo for werewolves
    for k,v in pairs(good_alives) do
      GM:SetTag(werewolves, v:SteamID64(), "pseudo", -1, Color(255,150,70), "")
    end

    -- start werewolf vote
    GM.game.night_vote = nil

    for k,v in pairs(werewolves) do
      v:Give("lgg_vote")
      GM.game.players[v:SteamID64()].vote = "nobody"
    end

    -- ask savior target
    local saviors = team.GetPlayers(TEAM.SAVIOR)

    if #saviors >= 1 then
      -- ask the savior who he want to protect this night
      local choices = {
        {"nobody","nobody"}
      }
      for k,v in pairs(GM.game.players) do
        local p = player.GetBySteamID64(k)
        if p and p:Team() ~= TEAM.DEAD then
          table.insert(choices,{k,p:Nick()})
        end
      end

      GM.game.savior_target = nil
      GM:RequestChoice(saviors[1], "Protect", choices, function(ply, choice)
        local p = player.GetBySteamID64(choice)
        if p then
          GM.game.savior_target = p:SteamID64()
        end
      end)
    end
  elseif nphase == PHASE.NIGHT_POSTVOTE then -- NIGHT POST/SAVE VOTE
    GM:AddCountdown(math.min(10+5*#GM:GetPlayers(false, {TEAM.SORCERER,TEAM.SAVIOR,TEAM.SHAMAN,TEAM.SEER}),30)) -- 10s and 10s per g
    GM:Chat(Color(100,0,50), "The night is even darker, some villagers are waking up...")

    -- give sorcerer potions
    GM.game.sorcerer_vote = nil
    local sorcerers = team.GetPlayers(TEAM.SORCERER)
    if #sorcerers >= 1 then
      local sorcerer = sorcerers[1]
      local gp = GM.game.players[sorcerer:SteamID64()]
      if gp then
        if not gp.life_potion_used then sorcerer:Give("lgg_life_potion") end
        if not gp.death_potion_used then sorcerer:Give("lgg_death_potion") end
      end
    end

    -- give seer ability
    local seers = team.GetPlayers(TEAM.SEER)
    if #seers >= 1 then
      local seer = seers[1]
      local gp = GM.game.players[seer:SteamID64()]
      if gp then
        seer:Give("lgg_seer_eye")
        gp.seer_ability_used = false
      end
    end
  end
end

function GM:InitPostEntity() -- load map
  -- load map 
  local fname = "loupgg/maps/"..game.GetMap()..".txt"
  if file.Exists(fname,"DATA") then
    local data = util.JSONToTable(file.Read(fname,"DATA"))
    for k,v in pairs(data.seats) do
      local ent = ents.Create("prop_vehicle_prisoner_pod")
      ent:SetModel("models/nova/airboat_seat.mdl")
      ent:SetKeyValue("vehiclescript", "scripts/vehicles/prisoner_pod.txt")
      ent:SetPos(Vector(v[1],v[2],v[3]))
      ent:SetAngles(Angle(v[4],v[5],v[6]))
      ent:SetRenderMode(RENDERMODE_TRANSALPHA)
      ent:SetColor(Color(0,0,0,0))
      ent:Spawn()
      local phy = ent:GetPhysicsObject()
      if phy and phy:IsValid() then
        phy:EnableMotion(false)
      end
      ent:SetCollisionGroup(COLLISION_GROUP_WORLD)
    end

    print("LoupGG: "..table.Count(data.seats).." seats loaded.")

    for k,v in pairs(data.houses) do
      local ent = ents.Create("prop_physics")
      ent:SetModel("models/props_lab/huladoll.mdl")
      ent:SetPos(Vector(v[1],v[2],v[3]))
      ent:SetAngles(Angle(v[4],v[5],v[6]))
      ent:SetRenderMode(RENDERMODE_TRANSALPHA)
      ent:SetColor(Color(0,0,0,0))
      ent:Spawn()
      local phy = ent:GetPhysicsObject()
      if phy and phy:IsValid() then
        phy:EnableMotion(false)
      end
      ent:SetCollisionGroup(COLLISION_GROUP_WORLD)
    end

    print("LoupGG: "..table.Count(data.houses).." houses loaded.")
  end
end

function GM:PlayerDisconnected(ply)
  local id64 = ply:SteamID64()
  GM.game.players[id64] = nil

  -- chat info
  GM:Chat(ply:Nick().." disconnected.")
end
