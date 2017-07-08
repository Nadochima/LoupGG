local GM = GM

local cmds = {}

function GM:PlayerSay(ply, txt, is_team)
  txt = string.lower(txt)
  local args = string.Split(txt," ")
  local sadmin = ply:IsSuperAdmin()

  if table.Count(args) > 0 and (args[1] == "!lgg" or args[1] == "/lgg") then
    if table.Count(args) > 1 then -- a command
      local cmd = cmds[args[2]]
      if cmd then
        if not cmd[1] or sadmin then
          local r = cmd[3](ply, args)
          if not r then -- error, display usage
            GM:PlayerChat(ply, "Usage: "..args[2].." "..cmd[2])
          end
        else
          GM:PlayerChat(ply, Color(255,0,0), "Superadmin required.")
        end
      else -- print list
        GM:PlayerChat(ply, "!lgg "..args[2].." unknown command.")
        GM:PlayerChat(ply, "Commands:")
        for k,v in pairs(cmds) do
          local col = Color(0,255,125)
          if v[1] then col = Color(255,0,0) end
          GM:PlayerChat(ply, "    ",col,k,Color(255,255,255)," "..v[2])
        end
      end
    else -- no command, print list
      GM:PlayerChat(ply, "Commands:")
      for k,v in pairs(cmds) do
        local col = Color(0,255,125)
        if v[1] then col = Color(255,0,0) end
        GM:PlayerChat(ply, "    ",col,k,Color(255,255,255)," "..v[2])
      end
    end

    return ""
  end

  return txt
end

-- register a lgg command
--- name: command name
--- sadmin: if true, require super admin
--- help: help usage text (ex: "arg1 arg2 [arg3]")
--- callback(ply, args): can return false to print help text
function GM:RegisterCommand(name, sadmin, help, callback)
  cmds[name] = {sadmin,help,callback}
end

-- COMMANDS

GM:RegisterCommand("savemap", true, "", function(ply, args)
  -- save village seats/houses
  local data = {}

  data.seats = {}
  for k,v in pairs(GM:GetVillagerSeats()) do
    local pos = v:GetPos()
    local rot = v:GetAngles()
    table.insert(data.seats,{pos.x,pos.y,pos.z,rot.p,rot.y,rot.r})
  end

  data.houses = {}
  for k,v in pairs(GM:GetHouseSpawns()) do
    local pos = v:GetPos()
    local rot = v:GetAngles()
    table.insert(data.houses,{pos.x,pos.y,pos.z,rot.p,rot.y,rot.r})
  end

  file.Write("loupgg/maps/"..game.GetMap()..".txt", util.TableToJSON(data))
  GM:PlayerChat(ply, "LoupGG map "..game.GetMap().." generated ("..#data.seats.." seats, "..#data.houses.." houses).")

  return true
end)

GM:RegisterCommand("countdown", true, "seconds", function(ply, args)
  if args[3] ~= nil then
    local n = tonumber(args[3])
    GM:SetCountdown(n)
    return true
  end

  return false
end)

GM:RegisterCommand("stop", true, "", function(ply, args)
  for k,v in pairs(GM.game.players) do
    local p = player.GetBySteamID64(k)
    if p and p:Team() ~= TEAM.DEAD then
      GM:ApplyDeath(p)
    end
  end

  GM:SetCountdown(0)

  return true
end)


GM:RegisterCommand("test", true, "", function(ply, args)
  local choices = {}
  for i=1,5 do
    table.insert(choices,{"id_"..i, "#"..i})
  end

  GM:RequestChoice(ply, "Test select", choices, function(ply, idchoice)
    GM:PlayerChat(ply, "You choose ["..idchoice.."].")
  end)

  GM:SetTag(ply, ply:SteamID64(), "name", 1000, Color(255,255,255), ply:Nick())
  GM:SetTag(ply, ply:SteamID64(), "vote", 0, Color(255,0,0), "Vote "..math.random(1,100))

  return true
end)

GM:RegisterCommand("setrole", true, "nick role", function(ply, args)
  if #args >= 4 then
    -- search team
    local teamid = TEAM[string.upper(args[4])] or TEAM.NONE

    -- search player
    for k,v in pairs(GM.game.players) do
      local p = player.GetBySteamID64(k)
      if p and string.find(string.upper(p:Nick()), string.upper(args[3])) then
        GM:SetTeam(p,teamid)
        GM:PlayerChat(ply, p:Nick().." role set to ",team.GetColor(teamid), team.GetName(teamid))
        return true
      end
    end

    GM:PlayerChat(ply, "Lobby player not found.")

    return true
  end

  return false
end)

GM:RegisterCommand("map", true, "show|hide", function(ply, args)
  if #args >= 3 then
    if args[3] == "show" then
      local seats = GM:GetVillagerSeats()
      for k,v in pairs(seats) do
        v:SetColor(Color(255,255,255,255))
      end

      local houses = GM:GetHouseSpawns()
      for k,v in pairs(houses) do
        v:SetColor(Color(255,255,255,255))
      end

      return true
    elseif args[3] == "hide" then
      local seats = GM:GetVillagerSeats()
      for k,v in pairs(seats) do
        v:SetColor(Color(0,0,0,0))
      end

      local houses = GM:GetHouseSpawns()
      for k,v in pairs(houses) do
        v:SetColor(Color(0,0,0,0))
      end

      return true
    end
  end

  return false
end)
