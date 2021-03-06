-- shared
local GM = GM
if SERVER then
  util.AddNetworkString("gm_request_choice")
  util.AddNetworkString("gm_player_tag")
  util.AddNetworkString("gm_convars")
  util.AddNetworkString("gm_sound")

  local ch_requests = {}  -- per id 64 requests

  -- API

  -- ask for a unique choice (client-side)
  --- ply: a player
  --- title: window title
  --- choices: a list of {idstr,valuestr}
  --- callback(ply, idstr)
  function GM:RequestChoice(ply, title, choices, callback)
    local id64 = ply:SteamID64()
    ch_requests[id64] = callback

    net.Start("gm_request_choice")
      -- write title
      net.WriteString(title)
      -- write choices
      net.WriteInt(#choices,32)
      for i=1,#choices do
        local ch = choices[i]
        net.WriteString(ch[1])
        net.WriteString(ch[2])
      end
    net.Send(ply)
  end

  -- set tag 
  --- ply: player or table of players, or nil for everyone
  --- steamid64: steam id 64 of the tag target 
  --- tag: tag name
  --- rank: negative value make the tag invisible, high value make the tag on top
  --- color: tag color
  --- value: tag text
  function GM:SetTag(ply, steamid64, tag, rank, color, value)
    net.Start("gm_player_tag")
      net.WriteString(steamid64)
      net.WriteString(tag)
      net.WriteColor(color)
      net.WriteInt(rank,32)
      net.WriteString(value)
    
    if ply == nil then
      net.Broadcast()
    else
      net.Send(ply)
    end
  end

  -- set client(s) convars
  --- ply: player or table of players, or nil for everyone
  --- vars: map of convar -> string value
  function GM:ClientConVars(ply, vars)
    net.Start("gm_convars")
      net.WriteInt(table.Count(vars),32)
      for k,v in pairs(vars) do
        net.WriteString(k)
        net.WriteString(v)
      end

    if ply == nil then
      net.Broadcast()
    else
      net.Send(ply)
    end
  end

  -- play a non spatialized sound
  --- ply: player or table of players, or nil for everyone
  --- volume: 0-1
  --- pitch: 0-255
  function GM:PlaySound(ply, path, volume, pitch)
    if volume == nil then volume = 1 end
    if pitch == nil then pitch = 100 end

    net.Start("gm_sound")
      net.WriteString(path)
      net.WriteFloat(volume)
      net.WriteInt(pitch,32)

    if ply == nil then
      net.Broadcast()
    else
      net.Send(ply)
    end
  end

  -- net events
  net.Receive("gm_request_choice", function(len,ply) -- request choice response
    local id64 = ply:SteamID64()
    local cb = ch_requests[id64]
    local ans = net.ReadString()
    if cb then
      ch_requests[id64] = nil -- free
      cb(ply, ans)
    end
  end)
else -- CLIENT
  -- select frame api (votes, etc...)

  local frame = vgui.Create("DFrame")
  local choices = {}
  local cb_choice = nil

  frame:SetPos(0,0)
  frame:SetSize(300,100)
  frame:SetTitle("Select")
  frame:SetVisible(false)
  frame:SetDraggable(false)
  frame:ShowCloseButton(true)
  frame:SetDeleteOnClose(false)
  frame:Center()
  frame.Paint = function(s, w, h)
    draw.RoundedBox(0,0,0,w,h,Color(30,30,30,200))
    draw.RoundedBox(0,0,0,300,25,Color(30,30,30))
  end

  frame.OnClose = function()
    -- valid empty value
    if cb_choice then cb_choice("") end
    cb_choice = nil
    choices = {}
  end

  local cb = vgui.Create("DComboBox", frame)
  cb:SetPos(20, 30)
  cb:SetSize(260, 30)
  cb:SetSortItems(false)

  local bok = vgui.Create("DButton", frame)
  bok:SetText("ok")
  bok:SetPos(125,70)
  bok:SetSize(50,20)

  bok.DoClick = function()
    -- valid value
    local id = cb:GetSelectedID()
    if cb_choice then cb_choice((choices[id] or {""})[1]) end
    cb_choice = nil
    choices = {}
    frame:Close()
  end

  -- player tags
  local player_tags = {}
  local sorted_player_tags = {}

  local function sort_ptag(a,b)
    return not (a[3] < b[3])
  end

  -- DISPLAY


  function GM:HUDPaint()
  local animtime = (CurTime()*8)
  if lgg_cfg.timerhud == 1 then 
    surface.SetDrawColor(Color(142,92,51))
    surface.SetMaterial(Material("materials/loupgg/loupgg_spwheel1.png"))
    surface.DrawTexturedRectRotated((ScrW()/18),(ScrW()/10),(ScrW()/12),(ScrW()/12),-animtime*2)
    surface.SetMaterial(Material("materials/loupgg/loupgg_spwheel2.png"))
    surface.DrawTexturedRectRotated((ScrW()/10),(ScrW()/20),(ScrW()/16),(ScrW()/16),animtime*2)
    surface.SetDrawColor(Color(114,75,45))
    surface.SetMaterial(Material("materials/loupgg/loupgg_spbase.png"))
    surface.DrawTexturedRectRotated((ScrW()/15),(ScrW()/15),(ScrW()/10),(ScrW()/10),animtime)
    surface.SetDrawColor(Color(166,105,51))
    surface.SetMaterial(Material("materials/loupgg/loupgg_spbase.png"))
    surface.DrawTexturedRectRotated((ScrW()/15),(ScrW()/15),(ScrW()/13),(ScrW()/13),-animtime*2)
    draw.SimpleText(GM.game.countdown,"LoupGG_Title",(ScrW()/15),(ScrW()/15),color_white,1,1)
  elseif lgg_cfg.timerhud == 2 then
    surface.SetDrawColor(Color(142,92,51))
    surface.SetMaterial(Material("materials/loupgg/loupgg_spwheel1.png"))
    surface.DrawTexturedRectRotated((ScrW()/32),(ScrW()/20),(ScrW()/18),(ScrW()/18),-animtime*2)
    surface.SetMaterial(Material("materials/loupgg/loupgg_spwheel1.png"))
    surface.DrawTexturedRectRotated((ScrW()/11),(ScrW()/10),(ScrW()/12),(ScrW()/12),animtime*2)
    surface.SetMaterial(Material("materials/loupgg/loupgg_spwheel2.png"))
    surface.DrawTexturedRectRotated((ScrW()/10),(ScrW()/16/1.8),(ScrW()/16),(ScrW()/16),-animtime*2)
    surface.SetDrawColor(Color(114,75,45))
    surface.SetMaterial(Material("materials/loupgg/loupgg_spbase.png"))
    surface.DrawTexturedRectRotated((ScrW()/15),(ScrW()/15),(ScrW()/10),(ScrW()/10),animtime)
    surface.SetDrawColor(Color(156,98,51))
    surface.SetMaterial(Material("materials/loupgg/loupgg_spbase.png"))
    surface.DrawTexturedRectRotated((ScrW()/15),(ScrW()/15),(ScrW()/13),(ScrW()/13),-animtime*2)
    draw.SimpleText(GM.game.countdown,"LoupGG_Title",(ScrW()/15),ScrW()/15,color_white,1,1)
  end 

  if lgg_cfg.infohud then
    surface.SetMaterial(Material("materials/loupgg/loupgg_ui01.png"))
    surface.SetDrawColor(color_white)
    surface.DrawTexturedRect((ScrW()-ScrW()/2.5),0,ScrW()/2.5,(ScrW()/2.5/5))
    draw.SimpleText(team.GetName(LocalPlayer():Team()),"LoupGG_Title",(ScrW()-ScrW()/2.5)+(ScrW()/2.5)/3.9,(ScrW()/2.5/5)/1.55,Color(5,5,5),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
  end
    -- check tags update
    for k,v in pairs(player_tags) do
      local tags = sorted_player_tags[k]
      if not tags then -- missing tags, update
        tags = {}
        sorted_player_tags[k] = tags

        -- sort player tags
        --- insert
        for l,w in pairs(v) do
          if w[1] >= 0 then -- check rank positive
            table.insert(tags, {w[2],w[3],w[1]})
          end
        end

        --- sort
        table.sort(tags, sort_ptag)
      end

    end

    -- display player tags
    surface.SetFont("LoupGG_tag")
    local font_height = draw.GetFontHeight("LoupGG_tag")
    for k,v in pairs(sorted_player_tags) do
      local p = player.GetBySteamID64(k)
      local lp = LocalPlayer()
      if IsValid(p) then
        local pos = p:EyePos()+Vector(0,0,7)
        local dist = lp:GetPos():Distance(pos)
        local max_dist = 0
        if GM.game.phase == PHASE.DAY_VOTE then
          max_dist = lgg_cfg.day_tag_vision
        else
          max_dist = lgg_cfg.night_tag_vision
        end

        if dist <= 40*max_dist then -- one meter is ~=40 inch
          local spos = pos:ToScreen()

          local shift = -font_height*#v
          for l,w in pairs(v) do 
            -- display tag ({color, value})
            surface.SetTextColor(w[1])
            local width,height = surface.GetTextSize(w[2])
            surface.SetTextPos(spos.x-width/2, spos.y+shift)
            surface.DrawText(w[2])
            shift = shift+height+1
          end
        end
      end
    end
  end

  -- API

  -- ask for a unique choice (client-side)
  --- title: window title
  --- choices: a list of {idstr,valuestr}
  --- callback(idstr)
  function GM:RequestChoice(title, _choices, callback)
    cb_choice = callback
    choices = _choices
    cb:Clear()
    for i=1,#choices do
      cb:AddChoice(choices[i][2])
    end

    if #choices > 0 then
      cb:ChooseOptionID(1)
    end

    frame:SetTitle(title)
    frame:SetVisible(true)
    frame:MakePopup()
  end

  -- NET EVENTS

  net.Receive("gm_request_choice", function(len)
    local title = net.ReadString()
    local size = net.ReadInt(32)
    local chs = {}
    for i=1,size do
      table.insert(chs, {net.ReadString(), net.ReadString()})
    end

    GM:RequestChoice(title, chs, function(choice) -- send choice to server
      net.Start("gm_request_choice")
        net.WriteString(choice)
      net.SendToServer()
    end)
  end)

  -- tag modification
  net.Receive("gm_player_tag", function(len)
    local id64 = net.ReadString()
    local tagname = net.ReadString()
    local color = net.ReadColor()
    local rank = net.ReadInt(32)
    local v = net.ReadString()

    -- get player entry
    local p = player_tags[id64]
    if not p then 
      p = {}
      player_tags[id64] = p
    end

    -- set tag
    p[tagname] = {rank, color, v}

    -- delete sorted_player_tags entry to regenerate
    sorted_player_tags[id64] = nil
  end)

  -- convars
  net.Receive("gm_convars", function(len)
    local size = net.ReadInt(32)

    for i=1,size do
      local name = net.ReadString()
      local value = net.ReadString()

      --[[
      local cvar = GetConVar(name)
      if cvar then
        cvar:SetString(value)
      end
      --]]
      RunConsoleCommand(name,value)
    end
  end)

  -- sound
  local sounds = {}
  net.Receive("gm_sound", function(len)
    local path = net.ReadString()
    local volume = net.ReadFloat()
    local pitch = net.ReadInt(32)

    -- register the sound
    local sound = sounds[path]
    if not sound then
      sounds[path] = CreateSound(LocalPlayer(), path)
      sound = sounds[path]
    end

    sound:Stop()
    sound:PlayEx(volume,pitch)
  end)
end
