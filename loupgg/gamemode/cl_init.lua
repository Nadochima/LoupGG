local GM = GM

include("shared.lua")
include("fonts.lua")

-- net events
net.Receive("gm_chat", function(len)
  local n = net.ReadInt(32)
  local ar = {}
  for i=1,n do
    local t = net.ReadInt(32)
    if t == 0 then
      table.insert(ar, net.ReadColor())
    elseif t == 1 then
      table.insert(ar, net.ReadString())
    end
  end

  chat.AddText(unpack(ar))
end)

net.Receive("gm_countdown", function(len)
  GM.game.countdown = net.ReadInt(32)
end)

net.Receive("gm_phase", function(len)
  GM.game.phase = net.ReadInt(32)
end)

-- events
function GM:OnCountdown()
end

function GM:PlayerSpawn(ply)
  self.BaseClass.PlayerSpawn(self,ply)
  ply:SetCustomCollisionCheck(true)
end
