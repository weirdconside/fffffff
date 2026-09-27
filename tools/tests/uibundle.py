import os
base=os.path.dirname(os.path.abspath(__file__))+'/..'
mods={'StudTheme':'new/StudTheme.lua','UISound':'new/UISound.lua','ShopIcons':'new/ShopIcons.lua','DonationShop':'new/DonationShop.lua','RewardsUI':'new/RewardsUI.lua','DonationCatalog':'new/DonationCatalog.lua',
      'LobbyUI':'new/LobbyUI.lua','AdminUI':'new/AdminUI.lua','ManualTyping':'new/ManualTyping.lua','TypingRules':'new/TypingRules.lua',
      'StudTransition':'new/StudTransition.lua','TitleLogo':'new/TitleLogo.lua'}
scripts={'TitleScreen':'new/TitleScreen.client.lua','DonationClient':'new/DonationClient.client.lua','LobbyAmbience':'new/LobbyAmbience.client.lua','UISounds':'new/UISounds.client.lua'}
out=[open(base+'/test/glyphs.lua').read(), open(base+'/test/rbxmock.lua').read()]
for name,path in mods.items():
    out.append(f'__modules["{name}"]=function()\n{open(base+"/"+path).read()}\nend\n')
out.append('local __scripts={}')
for name,path in scripts.items():
    out.append(f'__scripts["{name}"]=function()\n{open(base+"/"+path).read()}\nend\n')
out.append(open(base+'/test/ui.lua').read())
open(base+'/test/uibundle.lua','w').write('\n'.join(out))
