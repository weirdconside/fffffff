import os, sys
base=os.path.dirname(os.path.abspath(__file__))+'/..'
w,h=(int(x) for x in (sys.argv[1] if len(sys.argv)>1 else '1280x720').split('x'))
mods={'StudTheme':'new/StudTheme.lua','UISound':'new/UISound.lua','ShopIcons':'new/ShopIcons.lua','DonationShop':'new/DonationShop.lua','DonationCatalog':'new/DonationCatalog.lua',
      'LobbyUI':'new/LobbyUI.lua','AdminUI':'new/AdminUI.lua','ManualTyping':'new/ManualTyping.lua','TypingRules':'new/TypingRules.lua',
      'StudTransition':'new/StudTransition.lua','TitleLogo':'new/TitleLogo.lua'}
extra=sys.argv[2:]   # name=path modules added by later steps
for e in extra:
    k,v=e.split('='); mods[k]=v
out=[open(base+'/test/glyphs.lua').read(), open(base+'/test/rbxmock.lua').read(), open(base+'/test/guidump.lua').read(), f'local __VPW,__VPH={w},{h}']
for name,path in mods.items():
    out.append(f'__modules["{name}"]=function()\n{open(base+"/"+path).read()}\nend\n')
out.append('local __scripts={}')
out.append(f'__scripts["TitleScreen"]=function()\n{open(base+"/new/TitleScreen.client.lua").read()}\nend\n')
out.append(open(base+'/test/'+(__import__('os').environ.get('SCENARIO','layout.lua'))).read())
open(base+'/test/layoutbundle.lua','w').write('\n'.join(out))
