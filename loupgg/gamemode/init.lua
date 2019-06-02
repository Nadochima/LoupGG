AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("cfg/shared.lua")
AddCSLuaFile("cfg/client.lua")
AddCSLuaFile("fonts.lua")
AddCSLuaFile("commands.lua")
AddCSLuaFile("gui.lua")
AddCSLuaFile("lib/lang.lua")

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

-- set server convars
function GM:ServerConVars(vars)
  for k,v in pairs(vars) do
    --[[
    local cvar = GetConVar(k)
    if cvar then
      cvar:SetString(v)
    end
    --]]
    RunConsoleCommand(k,v)
  end
end

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

function GM:DiscordMessage(content)
  if lgg_cfg.discord_webhook then
    http.Post(lgg_cfg.discord_webhook, { content = content })
  end
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
  ply:SetTeam(teamid)

  if teamid ~= TEAM.DEAD and teamid ~= TEAM.NONE then
    GM:PlayerChat(ply, team.GetColor(teamid), lang.common.you_are(team.GetName(teamid)))
  end

  -- display role tag for the player
  GM:SetTag(ply, ply:SteamID64(), "role", 999, team.GetColor(teamid), team.GetName(teamid))

  if teamid == TEAM.SPECTATOR or teamid == TEAM.DEAD then -- spectate
    -- remove pseudo, role, votes, votefor for dead/spectator for playing players
    local players = GM:GetPlayers(true, {-TEAM.DEAD})

    ply:Spectate(OBS_MODE_ROAMING)
    GM:SetTag(players, ply:SteamID64(), "role", -1, Color(0,0,0), "")
    GM:SetTag(players, ply:SteamID64(), "pseudo", -1, Color(0,0,0), "")
    GM:SetTag(players, ply:SteamID64(), "votes", -1, Color(0,0,0), "")
    GM:SetTag(players, ply:SteamID64(), "votefor", -1, Color(0,0,0), "")

  elseif teamid == TEAM.CUPID then -- cupid, ask to create couple
    local first_lover = nil
    local second_lover = nil

    local choices = {
      {"nobody",lang.common.nobody()}
    }

    for k,v in pairs(GM.game.players) do
      local p = player.GetBySteamID64(k)
      if p and p:Team() ~= TEAM.DEAD then
        table.insert(choices,{k,p:Nick()})
      end
    end

    GM:RequestChoice(ply, lang.cupid.make_couple(1), choices, function(ply, choice)
      first_lover = choice

      local choices = {
        {"nobody",lang.common.nobody()}
      }

      for k,v in pairs(GM.game.players) do
        local p = player.GetBySteamID64(k)
        if p and p:Team() ~= TEAM.DEAD and k ~= first_lover then
          table.insert(choices,{k,p:Nick()})
        end
      end

      GM:RequestChoice(ply, lang.cupid.make_couple(2), choices, function(ply, choice)
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

        GM:SetTag(fp, second_lover, "lover", 998, team.GetColor(TEAM.CUPID), lang.cupid.lover())
        GM:SetTag(sp, first_lover, "lover", 998, team.GetColor(TEAM.CUPID), lang.cupid.lover())

        GM:PlayerChat(fp, team.GetColor(TEAM.CUPID), lang.cupid.you_love(sp:Nick()))
        GM:PlayerChat(sp, team.GetColor(TEAM.CUPID), lang.cupid.you_love(fp:Nick()))

        GM:PlayerChat(ply, team.GetColor(TEAM.CUPID), lang.cupid.in_love(fp:Nick(), sp:Nick()))
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
  if listener:IsPlayer() and talker:IsPlayer() then -- only if both players
    -- return true to enable hear/read

    if GM.game.phase == PHASE.LOBBY then
      return true
    elseif GM.game.phase == PHASE.DAY_VOTE then -- day vote, alives can talk/hear
      local gpl = GM.game.players[listener:SteamID64()]
      local gpt = GM.game.players[talker:SteamID64()]

      -- day vote, only text/voice chat for the living, everyone can hear
      if gpl and gpt and talker:Team() ~= TEAM.DEAD then return true end
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
          -- little girl
          elseif listener:Team() == TEAM.LITTLE_GIRL and talker:Team() == TEAM.WEREWOLF then return true
          end
        -- deads and shaman
        elseif (listener:Team() == TEAM.SHAMAN and talker:Team() == TEAM.DEAD) or (talker:Team() == TEAM.SHAMAN and listener:Team() == TEAM.DEAD) then return true
        end
      end
    end

    -- spectator, everyone and in function of distance for the voice
    if listener:Team() == TEAM.SPECTATOR then return (listener:GetPos():Distance(talker:GetPos()) <= 40*12) or not is_voice end
    -- deads can talk to each others
    if listener:Team() == TEAM.DEAD and talker:Team() == TEAM.DEAD then return true end

    return false
  else
    return true
  end
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
  deck[TEAM.LITTLE_GIRL] = add(1)
  if r >= 2 then
    deck[TEAM.SISTER] = add(2)
  end
  deck[TEAM.VILLAGER] = add(r) -- add the rest as villagers

  return deck
end

function GM:TriggerDeath(steamid64) -- trigger the special death effects for the role
  local p = player.GetBySteamID64(steamid64)
  local gp = GM.game.players[steamid64]
  if gp and p and p:Team() ~= TEAM.DEAD then
    if p:Team() == TEAM.HUNTER then -- hunter death, can kill someone in the next 10 seconds
      GM:AddCountdown(5)
      GM:Chat(team.GetColor(TEAM.HUNTER), team.GetName(TEAM.HUNTER).." "..lang.hunter.last_stand().."...")

      p:Give("weapon_shotgun")
      p:SelectWeapon("weapon_shotgun")
      timer.Simple(0.1, function() -- make the hunter exit any vehicle for more easy shooting
        p:ExitVehicle()
      end)

      if GM.game.phase == PHASE.NIGHT_VOTE then -- can't kill in front, ask target
        local choices = {
          {"nobody",lang.common.nobody()}
        }
        for k,v in pairs(GM.game.players) do
          local p = player.GetBySteamID64(k)
          if p and p:Team() ~= TEAM.DEAD then
            table.insert(choices,{k,p:Nick()})
          end
        end

        GM:RequestChoice(p, lang.hunter.last_stand(), choices, function(ply, choice)
          local p = player.GetBySteamID64(choice)
          if p and p:Team() ~= TEAM.DEAD and ply:Team() == TEAM.HUNTER then -- kill the target
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
        GM:Chat(team.GetColor(TEAM.CUPID), lang.cupid.death(pl:Nick(),p:Nick()))
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
    local lover_alives = 0
    local alives = 0

    for k,v in pairs(GM.game.players) do
      local p = player.GetBySteamID64(k)
      if p then
        if p:Team() == TEAM.WEREWOLF then werewolves = werewolves+1 
        elseif p:Team() ~= TEAM.DEAD then good_alives = good_alives+1 end

        if p:Team() ~= TEAM.DEAD then
          alives = alives+1

          if v.lover ~= nil then
            lover_alives = lover_alives+1
          end
        end

        players = players+1
      end
    end

    if alives == 2 and lover_alives == 2 then return true,TEAM.CUPID end
    if werewolves == 0 then return true,TEAM.VILLAGER end
    if good_alives < 2 then return true,TEAM.WEREWOLF end
  end

  return false
end

-- end the game if it must
function GM:TryEndGame()
  local gend,winner = GM:CheckEndOfGame() 
  if gend then

    -- win message
    GM:Chat(team.GetColor(winner), lang.common.win(team.GetName(winner)))
    local discord = "```md\n"
    discord = discord.."## "..lang.common.win(team.GetName(winner)).." ##\n"

    -- display summary
    for k,v in pairs(GM.game.players) do
      local p = player.GetBySteamID64(k)
      if p then
        local death = {}
        local ddeath = ""
        if p:Team() == TEAM.DEAD then
          death = {team.GetColor(TEAM.DEAD), " ("..team.GetName(TEAM.DEAD)..")"}
          ddeath = " ("..team.GetName(TEAM.DEAD)..")"
        end

        GM:Chat(team.GetColor(v.role), p:Nick(), Color(255,255,255),lang.common.was(), team.GetColor(v.role), team.GetName(v.role), unpack(death))
        discord = discord..p:Nick()..lang.common.was()..team.GetName(v.role)..ddeath.."\n"

        if lgg_cfg.pointshop then p:PS_GivePoints(lgg_cfg.pointshopGive) p:PS_Notify(lang.pointshop.givemsg(lgg_cfg.pointshopGive)) end
        if lgg_cfg.pointshop2 then p:PS2_AddStandardPoints(lgg_cfg.pointshop2Give, lang.pointshop2.givemsg(lgg_cfg.pointshopGive), false) if table.HasValue( lgg_cfg.pointshop2UserGroup, p:GetUserGroup()) then p:PS2_AddPremiumPoints(lgg_cfg.pointshop2GivePremiun) p:PS_Notify(lang.pointshop2.givemsgpremiun(lgg_cfg.pointshop2GivePremiun)) end end
        p:Kill()
      end
    end

    discord = discord.."```"
    GM:DiscordMessage(discord)
    GM:SetPhase(PHASE.LOBBY)
    GM:SetCountdown(30)
  end

  return gend
end

function GM:ApplyDeath(ply) -- real dead now
  if ply:Team() ~= TEAM.DEAD then
    GM:Chat(team.GetColor(ply:Team()), ply:Nick(), Color(255,255,255),lang.common.death(), team.GetColor(ply:Team()), team.GetName(ply:Team()))

    GM:PlaySound(nil, "lgg/death.wav", 0.45, math.random(90,110))

    ply:Kill()
    GM:SetTeam(ply, TEAM.DEAD)

    if GM:CheckEndOfGame() then -- update game state
      GM:SetCountdown(0)
    end
  end
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
    if game.GetMap() == "lgg_village_v1" then
      for key, ent in pairs(ents.FindByName("lgg_window")) do
        if IsValid( ent ) then
          ent:Fire( "open" )
        end
      end
    end
    local bots = player.GetBots()
    for k,v in pairs(bots) do
      GM:ShowTeam(v)
    end

    local pcount = table.Count(GM.game.players)
    if pcount >= 4 then
      GM:Chat(Color(0,255,0), lang.lobby.begin(pcount))

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
          v.role = selected_role
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

      -- merge sister houses
      local sisters = team.GetPlayers(TEAM.SISTER)
      local sister_house = nil
      for k,v in pairs(sisters) do
        local gp = GM.game.players[v:SteamID64()]
        if gp then
          if sister_house then
            gp.house = sister_house
          else
            sister_house = gp.house
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
      GM:Chat(Color(255,0,0), lang.lobby.not_enough(4))
      GM:AddCountdown(30) -- add 30s
    end
  elseif phase == PHASE.DAY_VOTE then
    GM:SetPhase(PHASE.NIGHT_VOTE)
    if game.GetMap() == "lgg_village_v1" then
      for key, ent in pairs(ents.FindByName("lgg_window")) do
        if IsValid( ent ) then
          ent:Fire( "close" )
        end
      end
    end
  elseif phase == PHASE.NIGHT_VOTE then
    GM:SetPhase(PHASE.NIGHT_POSTVOTE)
  elseif phase == PHASE.NIGHT_POSTVOTE then
    GM:SetPhase(PHASE.NIGHT_END)
  elseif phase == PHASE.NIGHT_END then
    if game.GetMap() == "lgg_village_v1" then
      for key, ent in pairs(ents.FindByName("lgg_window")) do
        if IsValid( ent ) then
          ent:Fire( "open" )
        end
      end
    end
    GM:SetPhase(PHASE.DAY_VOTE)
  end

  GM:TryEndGame()
end

function GM:ShowTeam(ply)
  local id64 = ply:SteamID64()
  if GM.game.phase == PHASE.LOBBY and not GM.game.players[id64] then
    if table.Count(GM.game.players) < 16 then
      GM.game.players[id64] = {}
      GM:Chat(lang.lobby.registered(ply:Nick()))
    else
      GM:PlayerChat(ply, Color(255,0,0), lang.lobby.full())
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
  GM:Chat(lang.common.connected(ply:Nick()))

  GM:SetTeam(ply,TEAM.NONE)

  if GM.game.phase == PHASE.LOBBY then
    GM:PlayerChat(ply, lang.lobby.help())
  else
    GM:PlayerChat(ply, lang.lobby.running())
    GM:SetTeam(ply, TEAM.SPECTATOR)
  end
end

function GM:PlayerSpawn(ply)
  self.BaseClass.PlayerSpawn(self,ply)
  ply:SetCustomCollisionCheck(true)
  ply:GodEnable() -- god mode

  if not ply:IsSuperAdmin() then
    ply:StripWeapon("weapon_physgun")

    if not (GM.game.phase == PHASE.LOBBY) then
      ply:StripWeapons()
    end
  end

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
  elseif pphase == PHASE.NIGHT_END then
    -- trigger deaths
    if GM.game.night_vote then GM:TriggerDeath(GM.game.night_vote) end
    if GM.game.sorcerer_vote then GM:TriggerDeath(GM.game.sorcerer_vote) end

    local werewolves = team.GetPlayers(TEAM.WEREWOLF)
    for k,v in pairs(werewolves) do
      v:StripWeapon("weapon_crowbar")
    end
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

      GM:SetTag(nil, id64, "votes", -1, Color(255,0,0), "")
      GM:SetTag(nil, id64, "role", -1, Color(255,0,0), "")
      GM:SetTag(nil, id64, "votefor", -1, Color(255,0,0), "")
      GM:SetTag(nil, id64, "lover", -1, Color(255,0,0), "")
    end

    GM.game.players = {}
    GM:Chat(lang.lobby.help())

    -- reset effects
    GM:ServerConVars({atmos_dnc_settime = "12"})
    GM:ClientConVars(nil,{
      atmos_dnc_settime = "12",
      pp_colormod = "0",
      pp_colormod_brightness = "0",
      pp_colormod_contrast = "1",
      pp_colormod_mulr = "0",
      pp_colormod_mulg = "0",
      pp_colormod_mulb = "0"
    })

  elseif nphase == PHASE.DAY_VOTE then -- DAY VOTE
    GM:AddCountdown(math.min(10+10*#GM:GetPlayers(true, {-TEAM.DEAD}),120)) -- 10s and 10s per g
    GM:Chat(Color(255,255,0), lang.msg.day())

    if math.random(0,1) == 0 then
      GM:PlaySound(nil, "lgg/day.wav", 0.45)
    else
      GM:PlaySound(nil, "lgg/day_alt.wav", 0.45)
    end

    GM:ServerConVars({atmos_dnc_settime = "12"})
    GM:ClientConVars(nil,{
      atmos_dnc_settime = "12",
      pp_colormod = "0",
      pp_colormod_brightness = "0",
      pp_colormod_contrast = "1",
      pp_colormod_mulr = "0",
      pp_colormod_mulg = "0",
      pp_colormod_mulb = "0"
    })


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
        GM:SetTag(nil, k, "votes", 500, Color(255,0,0), lang.common.votes(0))
      end
    end
  elseif nphase == PHASE.NIGHT_VOTE then -- NIGHT VOTE
    GM:AddCountdown(math.min(10+10*#GM:GetPlayers(false, {TEAM.WEREWOLF}),40)) -- 10s and 10s per g
    GM:Chat(Color(150,0,0), lang.msg.night())
    GM:PlaySound(nil, "lgg/night.wav", 0.45)

    GM:ServerConVars({atmos_dnc_settime = "20"})
    GM:ClientConVars(nil,{
      atmos_dnc_settime = "20",
      pp_colormod = "1",
      pp_colormod_brightness = "-0.01",
      pp_colormod_contrast = "1",
      pp_colormod_mulr = "5",
      pp_colormod_mulg = "0",
      pp_colormod_mulb = "0"
    })

    local good_alives = GM:GetPlayers(true, {-TEAM.DEAD, -TEAM.WEREWOLF})

    local vars_werewolf = {
      pp_colormod = "1",
      pp_colormod_mulr = "50",
      pp_colormod_mulg = "0",
      pp_colormod_mulb = "0"
    }

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
          GM:ClientConVars(p, vars_werewolf)

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
      GM:PlayerChat(v, lang.werewolf.help_vote())
      GM.game.players[v:SteamID64()].vote = "nobody"
    end

    -- ask savior target
    local saviors = team.GetPlayers(TEAM.SAVIOR)

    if #saviors >= 1 then
      -- ask the savior who he want to protect this night
      local choices = {
        {"nobody",lang.common.nobody()}
      }
      for k,v in pairs(GM.game.players) do
        local p = player.GetBySteamID64(k)
        if p and p:Team() ~= TEAM.DEAD then
          table.insert(choices,{k,p:Nick()})
        end
      end

      GM.game.savior_target = nil
      GM:RequestChoice(saviors[1], lang.savior.protect(), choices, function(ply, choice)
        local p = player.GetBySteamID64(choice)
        if p then
          GM.game.savior_target = p:SteamID64()
        end
      end)
    end
  elseif nphase == PHASE.NIGHT_POSTVOTE then -- NIGHT POST/SAVE VOTE
    GM:AddCountdown(math.min(10+5*#GM:GetPlayers(false, {TEAM.SORCERER,TEAM.SAVIOR,TEAM.SHAMAN,TEAM.SEER}),30)) -- 10s and 10s per g

    local info = "( "
    if #team.GetPlayers(TEAM.SORCERER) > 0 then info = info..team.GetName(TEAM.SORCERER).." " end
    if #team.GetPlayers(TEAM.SAVIOR) > 0 then info = info..team.GetName(TEAM.SAVIOR).." " end
    if #team.GetPlayers(TEAM.SHAMAN) > 0 then info = info..team.GetName(TEAM.SHAMAN).." " end
    if #team.GetPlayers(TEAM.SEER) > 0 then info = info..team.GetName(TEAM.SEER).." " end
    info = info..")"

    GM:PlaySound(nil, "lgg/deep_night.wav", 0.45)
    GM:Chat(Color(100,0,50), lang.msg.deep_night())
    GM:Chat(Color(200,200,200), info)
    GM:ServerConVars({atmos_dnc_settime = "0"})
    GM:ClientConVars(nil,{
      atmos_dnc_settime = "0",
      pp_colormod = "1",
      pp_colormod_brightness = "-0.10",
      pp_colormod_contrast = "1.3",
      pp_colormod_mulr = "0",
      pp_colormod_mulg = "0",
      pp_colormod_mulb = "5"
    })

    -- reset werewolf red display (overriden)
    local werewolves = team.GetPlayers(TEAM.WEREWOLF)
    local vars_werewolf = {
      pp_colormod = "1",
      pp_colormod_mulr = "50",
      pp_colormod_mulg = "0",
      pp_colormod_mulb = "0"
    }
    GM:ClientConVars(werewolves, vars_werewolf)

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
  elseif nphase == PHASE.NIGHT_END then -- feast time!
    local p = player.GetBySteamID64(GM.game.night_vote or "nobody")
    local gp = GM.game.players[GM.game.night_vote or "nobody"]
    if p and gp and p:Team() ~= TEAM.DEAD then
      GM:AddCountdown(8)
      -- teleport werewolves to victim house
      local werewolves = team.GetPlayers(TEAM.WEREWOLF)
      for k,v in pairs(werewolves) do
        v:Give("weapon_crowbar")
        v:SelectWeapon("weapon_crowbar")
        v:SetPos(gp.house:GetPos())
      end
    end
  end
end

function GM:InitPostEntity() -- load map
  -- load map 
  local fname = "loupgg/maps/"..game.GetMap()..".txt"
  if file.Exists(fname,"DATA") then
    local data = util.JSONToTable(file.Read(fname,"DATA")) or {}
    if not data.seats then data.seats = {} end
    if not data.houses then data.houses = {} end

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
  GM:Chat(lang.common.disconnected(ply:Nick()))
end

function GM:ShowSpare2(ply)
  if lgg_cfg.lang == "fr" then
    ply:SendLua( "gui.OpenURL( 'https://fr.wikipedia.org/wiki/Les_Loups-garous_de_Thiercelieux' )" )
  else
    ply:SendLua( "gui.OpenURL( 'https://en.wikipedia.org/wiki/The_Werewolves_of_Millers_Hollow' )" )
  end
end
