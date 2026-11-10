#!/usr/bin/env python3
"""Extract factual Forever item fields; never import Classic fallback or addon code.
Usage: python3 tools/import-gear-catalog.py /path/to/WoW-Classic-Item-Caches
Pinned upstream revision is recorded in the generated file. Offline, deterministic.
"""
import hashlib, html, json, re, subprocess, sys
from pathlib import Path
root = Path(sys.argv[1])
raw = (root / 'Forever Cache.json').read_bytes()
revision = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()
SLOTS = {'Head':'HEAD','Neck':'NECK','Shoulder':'SHOULDER','Back':'CLOAK','Chest':'CHEST',
         'Wrist':'WRIST','Hands':'HAND','Waist':'WAIST','Legs':'LEGS','Feet':'FEET','Finger':'FINGER',
         'Trinket':'TRINKET','One-Hand':'WEAPON','Main Hand':'WEAPONMAINHAND','Off Hand':'WEAPONOFFHAND',
         'Two-Hand':'2HWEAPON','Held In Off-hand':'HOLDABLE','Ranged':'RANGED','Relic':'RELIC'}
STATS = {3:'AGILITY',4:'STRENGTH',5:'INTELLECT',6:'SPIRIT',7:'STAMINA'}
def lua(x):
    if x is None: return 'nil'
    if isinstance(x, bool): return str(x).lower()
    if isinstance(x, (float,int)): return str(x)
    if isinstance(x, str): return json.dumps(x,ensure_ascii=False).replace('\\u2019', "'")
    if isinstance(x,list): return '{'+','.join(map(lua,x))+'}'
    return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in sorted(x.items()))+'}'
def number(pattern, text):
    m=re.search(pattern,text)
    return float(m[1]) if m else None
sources={x["key"]:x for x in json.loads((root / "itemDatabaseSources.json").read_text())}
items=[]
for x in json.loads(raw):
    assert x['itemExpansion']=='Forever'
    h=x['tooltipHtml']
    m=re.search(r'<tr><td>([^<]+)</td><th><!--scstart(\d+):(-?\d+)-->(.*?)<!--scend-->',h)
    if not m or m[1] not in SLOTS: continue
    # Internal/test items and unknown-only sources are not gearing recommendations.
    if x['name'].startswith(('[','zz','ZZ')) or re.match(r'^\d+ ',x['name']): continue
    if set(x['sourceTypes']) <= {'Other'}: continue
    loc='INVTYPE_'+SLOTS[m[1]]
    cls,sub=int(m[2]),int(m[3])
    if cls==4 and sub==6: loc='INVTYPE_SHIELD'
    plain=html.unescape(re.sub(r'<[^>]*>',' ',h))
    plain=re.sub(r'\s+',' ',plain)
    # Only base stats before item effects/sets; no accidental set-bonus attribution.
    base=h.split('<!--ebstats-->')[0]
    stats={}
    for code,value in re.findall(r'<!--stat(\d+)-->\+([\d.]+)',base):
        if int(code) in STATS: stats['ITEM_MOD_'+STATS[int(code)]+'_SHORT']=float(value)
    for key,pattern in [
        ('ITEM_MOD_SPELL_POWER_SHORT',r'Equip: Increases damage and healing done by magical spells and effects by up to\s+([\d.]+)'),
        ('ITEM_MOD_SPELL_HEALING_DONE_SHORT',r'Equip: Increases healing done by up to\s+([\d.]+)'),
        ('ITEM_MOD_SPELL_DAMAGE_DONE_SHORT',r'and damage done by up to\s+([\d.]+) for all magical'),
        ('ITEM_MOD_ATTACK_POWER_SHORT',r'Equip: \+([\d.]+) Attack Power'),
        ('ITEM_MOD_MANA_REGENERATION_SHORT',r'Equip: Restores ([\d.]+) mana per 5 sec'),
    ]:
        value=number(pattern,plain)
        if value is not None: stats[key]=value
    armor=number(r'<!--amr-->([\d.]+)',base)
    if armor is not None: stats['RESISTANCE0_NAME']=armor
    dps=number(r'<!--dps-->\(([\d.]+)',h)
    if dps is not None: stats['ITEM_MOD_DAMAGE_PER_SECOND_SHORT']=dps
    classes=re.search(r'Classes: (.*?)(?:Requires|Sell Price|Equip:|Durability|$)',plain)
    row=dict(id=x['itemId'],name=x['name'],equipLoc=loc,classID=cls,subclassID=sub,
        subtype=html.unescape(re.sub('<[^>]*>','',m[4])),level=number(r'<!--ilvl-->(\d+)',h),
        minLevel=number(r'<!--rlvl-->(\d+)',h),stats=stats,sources=[sources[k]['name'] for k in x['sourceKeys'] if k in sources],
        sourceTypes=[sources[k]['type'] for k in x['sourceKeys'] if k in sources],
        bosses=x['bossNames'],icon=x['iconName'],classes=classes[1].strip() if classes else None,
        restrictions=bool(re.search(r'Requires (?!Level)|Races:|Classes:|Unique',plain)),
        effects=bool(re.search(r'Chance on hit:|Use:|Set :|Set:|<!--useEffect',h)))
    items.append(row)
items.sort(key=lambda x:x['id'])
assert len(items)>5000 and len({x['id'] for x in items})==len(items)
out=Path('HearthAndHustle/Data/GearCatalog.lua')
out.write_text('-- Generated factual item reference. See tools/import-gear-catalog.py and THIRD_PARTY_NOTICES.txt.\nlocal _,FP=...\nFP.GearCatalog={revision='+lua(revision)+',date="2026-11-07",sha256='+lua(hashlib.sha256(raw).hexdigest())+',items={\n'+''.join(lua(x)+',\n' for x in items)+'}}\n')
print(len(items),'Forever item records;',out.stat().st_size,'bytes;',revision)
