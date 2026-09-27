CREATED={}
__modules["RoundWorld"]=function()
  return {create=function(data,slot,token,group,runtime)
      local w={players={},layouts={},central={},territories={},center=Vector3.new(0,0,0),cameraMin=Vector3.new(-100,0,-100),cameraMax=Vector3.new(100,0,100),model={Name="ArmyRound_"..token},slot=slot}
      for i,p in ipairs(group) do
        local uid=tostring(p.UserId);local ox=i*300+slot*5000
        local L={lands={},buildings={},nodes={}}
        for n,d in pairs(data.Lands) do L.lands[n]={x=d.pos.x+ox,y=d.pos.y,z=d.pos.z} end
        for k,d in pairs(data.Buildings) do L.buildings[k]={x=d.pos.x+ox,y=L.lands[d.land].y,z=d.pos.z} end
        for k,d in pairs(data.ResourceNodes) do L.nodes[k]={x=d.pos.x+ox,y=L.lands[d.land].y,z=d.pos.z} end
        w.layouts[uid]=L
        w.players[uid]={colour=Color3.fromRGB(100,120,140),home=Vector3.new(L.lands.S1.x,5,L.lands.S1.z)}
      end
      CREATED[#CREATED+1]=w
      return w end,sync=function() end,destroy=function(w) w.destroyed=true end}
end
