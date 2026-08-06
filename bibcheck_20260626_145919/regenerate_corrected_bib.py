import json, re
from pathlib import Path
import sys
run = Path(sys.argv[1])
orig = (run/'input.bib').read_text(encoding='utf-8-sig')
fixes = {
  'ampudia2024shopping': {'doi':'10.1016/j.jmoneco.2024.103618'},
  'argente2021cost': {'doi':'10.1093/jeea/jvaa018'},
  'arregui2022targeted': {'doi':'10.5089/9798400227400.001'},
  'doepke2006inflation': {'doi':'10.1086/508379'},
  'kaplan2017inflation': {'doi':'10.1016/j.jmoneco.2017.08.002'},
  'pallotti2024bears': {'doi':'10.1016/j.jmoneco.2024.103671'},
  'cravino2020household': {'doi':'10.1016/j.jinteco.2020.103303'},
  'claeys2022inflation': {'url':'https://www.bruegel.org/dataset/inflation-inequality-european-union-and-its-drivers'},
  'bobasu2023impact': {'url':'https://www.ecb.europa.eu/press/economic-bulletin/articles/2023/html/ecb.ebart202303_02~d32f2a9b3f.en.html'},
  'charalampakis2022impact': {'url':'https://www.ecb.europa.eu/press/economic-bulletin/focus/2022/html/ecb.ebbox202207_04~a89ec1a6fe.en.html'},
  'sgaravatti2021national': {'url':'https://www.bruegel.org/dataset/national-policies-shield-consumers-rising-energy-prices'},
  'hobijn2005inflation': {'doi':'10.1111/j.1475-4991.2005.00184.x'},
  'jaravel2024distributional': {'url':'https://cepr.org/publications/dp19802'},
}

def split_entries(text):
    starts=[m.start() for m in re.finditer(r'@\w+\s*\{', text)]
    spans=[]
    for s in starts:
        b=text.find('{', s); depth=0; e=None
        for i in range(b, len(text)):
            if text[i]=='{': depth += 1
            elif text[i]=='}':
                depth -= 1
                if depth==0:
                    e=i+1; break
        spans.append((s,e or len(text)))
    return spans

def has_field(entry, field):
    return re.search(r'(?mi)^\s*'+re.escape(field)+r'\s*=', entry) is not None

def insert_field(entry, field, val):
    if has_field(entry, field):
        return entry
    idx = entry.rfind('\n}')
    if idx < 0: idx = entry.rfind('}')
    before = entry[:idx]
    after = entry[idx:]
    lines = before.splitlines()
    # Add a comma to the last nonblank field line if needed.
    for k in range(len(lines)-1, -1, -1):
        if lines[k].strip():
            stripped = lines[k].rstrip()
            if not stripped.endswith(',') and not stripped.endswith('{'):
                lines[k] = stripped + ','
            break
    before = '\n'.join(lines)
    return before + f'\n  {field}={{{val}}}' + after

out=[]; last=0
for s,e in split_entries(orig):
    out.append(orig[last:s])
    entry=orig[s:e]
    m=re.match(r'@\w+\s*\{\s*([^,]+),', entry, re.S)
    key=m.group(1).strip() if m else ''
    if key in fixes:
        for field,val in fixes[key].items(): entry=insert_field(entry, field, val)
    out.append(entry)
    last=e
out.append(orig[last:])
(run/'corrected.bib').write_text(''.join(out), encoding='utf-8')
print('regenerated corrected.bib')
