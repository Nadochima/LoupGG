-- shared
local GM = GM

if SERVER then
  util.AddNetworkString("gm_request_choice")

  local ch_requests = {}  -- per id 64 requests

  -- API

  -- ask for a unique choice (client-side)
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

  -- net events
  net.Receive("gm_request_choice", function(len,ply) -- request choice response
    local id64 = ply:SteamID64()
    local cb = ch_requests[id64]
    local ans = net.ReadString()
    if cb then
      cb(ply, ans)
      ch_requests[id64] = nil -- free
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

    cb:ChooseOptionID(1)

    frame:SetTitle(title)
    frame:SetVisible(true)
    frame:MakePopup()
  end

  -- net events
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
end
