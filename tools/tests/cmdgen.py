import os,sys
base=os.path.dirname(os.path.abspath(__file__))+'/..'
rows=[]
for line in open(base+'/commands.txt',encoding='utf-8'):
    line=line.strip()
    if not line or line.startswith('#'): continue
    cat,exp,ru,en=[x.strip() for x in line.split('|')]
    rows.append((cat,exp,ru,en))
def q(s): return '"'+s.replace('\\','\\\\').replace('"','\\"')+'"'
out=['local COMMANDS={']
for cat,exp,ru,en in rows: out.append('{%s,%s,%s,%s},'%(q(cat),q(exp),q(ru),q(en)))
out.append('}')
open(base+'/test/cmdlist_data.lua','w',encoding='utf-8').write('\n'.join(out))
print(len(rows),'rows')
