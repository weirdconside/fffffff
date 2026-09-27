import os
base=os.path.dirname(os.path.abspath(__file__))+'/..'
shared={'StudTheme':'new/StudTheme.lua','UISound':'new/UISound.lua','RoundData':'src/RoundData.lua','TypingRules':'src/TypingRules.lua','DonationCatalog':'new/DonationCatalog.lua'}
server={'RoundState':'new/RoundState.lua','RoundBots':'new/RoundBots.lua','LobbyQueue':'src/LobbyQueue.lua','WishRules':'new/WishRules.lua','Perks':'new/Perks.lua','AdminBrain':'new/AdminBrain.lua'}
out=[open(base+'/test/rbxmock.lua').read(),'local __inst={}']
def wrap(name,path,parent):
    return f'__modules["{name}"]=function()\nlocal script=__inst["{name}"]\n{open(base+"/"+path).read()}\nend\n'
for n,p in shared.items(): out.append(wrap(n,p,'shared'))
for n,p in server.items(): out.append(wrap(n,p,'server'))
out.append('__modules["RoundWorld"]=function() return {create=function() error("world stub") end,sync=function() end,destroy=function() end} end')
out.append('local __scripts={}')
for n,p in (('RoundServer','new/RoundServer.server.lua'),('DonationServer','new/DonationServer.server.lua')):
    out.append(f'__scripts["{n}"]=function()\nlocal script=__inst["{n}"]\n{open(base+"/"+p).read()}\nend\n')
out.append(open(base+'/test/srv.lua').read())
open(base+'/test/srvbundle.lua','w').write('\n'.join(out))
