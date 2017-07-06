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
  -- save village seats
  local data = {}
  for k,v in pairs(ents.FindByClass("prop_vehicle_prisoner_pod")) do
    local pos = v:GetPos()
    local rot = v:GetAngles()
    table.insert(data,{pos.x,pos.y,pos.z,rot.p,rot.y,rot.r})
  end

  file.Write("loupgg/maps/"..game.GetMap()..".txt", util.TableToJSON(data))
  GM:PlayerChat(ply, "LoupGG map "..game.GetMap().." generated.")

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
