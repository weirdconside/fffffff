local Icons=__modules["ShopIcons"]()
local holder=Instance.new("Frame")
for _,spec in ipairs(ICON_SPECS) do
  local view,model=Icons.build(holder,spec[1],{count=spec[2]})
  for _,p in ipairs(model:GetDescendants()) do
    if p:IsA("BasePart") then
      local c=p.CFrame;local r=c.r
      local shape=tostring(p.Shape or "Block")
      local col=p.Color
      print(("PART|%s|%s|%s|%.4f %.4f %.4f|%.4f %.4f %.4f|%.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f|%.3f %.3f %.3f|%.2f"):format(
        spec[1]..(spec[2] or ""),p.ClassName,shape,p.Size.X,p.Size.Y,p.Size.Z,c.p.X,c.p.Y,c.p.Z,
        r[1],r[2],r[3],r[4],r[5],r[6],r[7],r[8],r[9],col.R,col.G,col.B,p.Transparency or 0))
    end
  end
end
