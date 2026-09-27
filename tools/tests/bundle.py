import sys,os
base=os.path.dirname(os.path.abspath(__file__))+'/..'
mods={'TypingRules':'src/TypingRules.lua','WishRules':'new/WishRules.lua','RoundState':'new/RoundState.lua','RoundData':'src/RoundData.lua','RoundBots':'src/RoundBots.lua'}
if len(sys.argv)>2:
    for kv in sys.argv[2:]:
        k,v=kv.split('=');mods[k]=v
out=[open(base+'/test/prelude.lua').read()]
for name,path in mods.items():
    src=open(base+'/'+path).read()
    out.append(f'__modules["{name}"]=function()\n{src}\nend\n')
out.append(open(base+'/test/'+sys.argv[1]).read())
open(base+'/test/bundle.lua','w').write('\n'.join(out))
