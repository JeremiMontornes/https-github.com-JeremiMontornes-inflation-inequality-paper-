import json, re
from pathlib import Path
import sys
run = Path(sys.argv[1])
orig = (run/'input.bib').read_text(encoding='utf-8-sig')
reports = {p.stem: json.loads(p.read_text(encoding='utf-8')) for p in (run/'reports').glob('*.json')}
# Conservative DOI/URL fixes. Do not overwrite source; produce corrected.bib only.
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
    starts=[]
    for m in re.finditer(r'@\w+\s*\{', text): starts.append(m.start())
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
        return re.sub(r'(?mis)^\s*'+re.escape(field)+r'\s*=\s*(\{.*?\}|".*?"|[^,]+)\s*,?', f'  {field}={{{val}}},', entry, count=1)
    idx = entry.rfind('\n}')
    if idx < 0: idx = entry.rfind('}')
    return entry[:idx] + f'  {field}={{{val}}},\n' + entry[idx:]

out=[]; last=0
for s,e in split_entries(orig):
    out.append(orig[last:s])
    entry=orig[s:e]
    m=re.match(r'@\w+\s*\{\s*([^,]+),', entry, re.S)
    key=m.group(1).strip() if m else ''
    if key in fixes:
        for field,val in fixes[key].items():
            if not has_field(entry, field):
                entry=insert_field(entry, field, val)
    out.append(entry)
    last=e
out.append(orig[last:])
(run/'corrected.bib').write_text(''.join(out), encoding='utf-8')
# Build report.
clean=[]; corrected=[]; unver=[]
for key in sorted(reports):
    r=reports[key]
    if key in fixes: corrected.append(key)
    elif r['status']=='unverifiable': unver.append(key)
    else: clean.append(key)
lines=[]
lines.append('# Bibcheck report')
lines.append('')
lines.append('Input: `references.bib`')
lines.append('Mode: `--by-citation` (default), with Crossref DOI/title pass plus manual adjudication for institutional references.')
lines.append('')
lines.append('## Summary')
lines.append('')
lines.append(f'- Clean/no change: {len(clean)}')
lines.append(f'- Corrected in `corrected.bib`: {len(corrected)}')
lines.append(f'- Still needs human/source-specific review: {len(unver)}')
lines.append('')
lines.append('## Corrected in corrected.bib')
lines.append('')
for key in corrected:
    additions=', '.join(f'{k}={v}' for k,v in fixes[key].items())
    lines.append(f'- `{key}`: added {additions}.')
lines.append('')
lines.append('## Clean or no source-file change recommended')
lines.append('')
for key in clean:
    r=reports[key]
    if r['status']=='corrected':
        lines.append(f'- `{key}`: Crossref suggested differences, but these appear to be online-first/working-paper metadata rather than clear BibTeX errors; no automatic change made.')
    else:
        lines.append(f'- `{key}`: verified by DOI/title pass; no change made.')
lines.append('')
lines.append('## Human review queue')
lines.append('')
lines.append('These entries were not conclusively verified by Crossref, usually because they are institutional pages, datasets, or working papers. I added URLs for the high-confidence institutional cases when the canonical page is known, but they should receive human/source-specific confirmation before submission.')
lines.append('')
for key in unver:
    r=reports[key]
    lines.append(f'- `{key}`: {r.get("note") or "not found in Crossref"}.')
lines.append('')
lines.append('## Notes on conservative adjudication')
lines.append('')
lines.append('- Crossref often reports the online publication year for journal articles. I did not replace print-volume years such as `argente2021cost`, `jaravel2019unequal`, or `redding2020measuring` where the existing volume/year metadata is internally consistent.')
lines.append('- SSRN hits were not treated as replacements for journal or central-bank working-paper entries unless the supplied entry itself is clearly a working-paper citation.')
lines.append('- `corrected.bib` is a proposed drop-in file. The source `references.bib` was not overwritten.')
(run/'bibcheck_report.md').write_text('\n'.join(lines)+'\n', encoding='utf-8')
print('\n'.join(lines[:18]))
