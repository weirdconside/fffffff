import os
base=os.path.dirname(os.path.abspath(__file__))+'/..'
mods={'StudTheme':'new/StudTheme.lua','UISound':'new/UISound.lua','ShopIcons':'new/ShopIcons.lua','LobbyUI':'new/LobbyUI.lua','AdminUI':'new/AdminUI.lua','ManualTyping':'src/ManualTyping.lua',
      'TypingRules':'src/TypingRules.lua','StudTransition':'new/StudTransition.lua','TitleLogo':'new/TitleLogo.lua','RoundData':'src/RoundData.lua','ResourceIcons':'src/ResourceIcons.lua',
      'RoundAnimations':'src/RoundAnimations.lua','BaseBadges':'src/BaseBadges.lua','WishRules':'new/WishRules.lua','RoundState':'new/RoundState.lua'}
import sys
vp=sys.argv[1] if len(sys.argv)>1 else None
out=[open(base+'/test/glyphs.lua').read(), open(base+'/test/rbxmock.lua').read(), open(base+'/test/guidump.lua').read(), ('local __VPW,__VPH=%s,%s' % tuple(vp.split('x'))) if vp else 'local __VPW,__VPH=nil,nil']
for name,path in mods.items():
    out.append(f'__modules["{name}"]=function()\n{open(base+"/"+path).read()}\nend\n')
out.append('local __scripts={}')
out.append(f'__scripts["RoundClient"]=function()\n{open(base+"/new/RoundClient.client.lua").read()}\nend\n')
out.append(open(base+'/test/rc.lua').read())
open(base+'/test/rcbundle.lua','w').write('\n'.join(out))
