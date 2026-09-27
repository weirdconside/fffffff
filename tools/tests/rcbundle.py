import os
base=os.path.dirname(os.path.abspath(__file__))+'/..'
mods={'StudTheme':'src/StudTheme.lua','ShopIcons':'new/ShopIcons.lua','LobbyUI':'new/LobbyUI.lua','AdminUI':'new/AdminUI.lua','ManualTyping':'src/ManualTyping.lua',
      'TypingRules':'src/TypingRules.lua','StudTransition':'new/StudTransition.lua','RoundData':'src/RoundData.lua','ResourceIcons':'src/ResourceIcons.lua',
      'RoundAnimations':'src/RoundAnimations.lua','BaseBadges':'src/BaseBadges.lua','WishRules':'new/WishRules.lua','RoundState':'new/RoundState.lua'}
out=[open(base+'/test/rbxmock.lua').read()]
for name,path in mods.items():
    out.append(f'__modules["{name}"]=function()\n{open(base+"/"+path).read()}\nend\n')
out.append('local __scripts={}')
out.append(f'__scripts["RoundClient"]=function()\n{open(base+"/new/RoundClient.client.lua").read()}\nend\n')
out.append(open(base+'/test/rc.lua').read())
open(base+'/test/rcbundle.lua','w').write('\n'.join(out))
