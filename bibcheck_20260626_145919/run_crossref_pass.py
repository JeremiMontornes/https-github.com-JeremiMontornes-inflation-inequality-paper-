import json, re, time, urllib.parse, urllib.request, html, unicodedata
from pathlib import Path
import sys
run = Path(sys.argv[1])
entries_dir = run / 'entries'
reports_dir = run / 'reports'
reports_dir.mkdir(exist_ok=True)
for p in reports_dir.glob('*.json'):
    p.unlink()

def parse_entry(text):
    m = re.match(r'\s*@(\w+)\s*\{\s*([^,]+),', text, re.S)
    d = {'_type': m.group(1) if m else '', '_key': m.group(2).strip() if m else ''}
    body = text[m.end(): text.rfind('}')] if m and text.rfind('}') > m.end() else text
    i = 0
    n = len(body)
    while i < n:
        while i < n and body[i] in ' \t\r\n,': i += 1
        j = i
        while j < n and re.match(r'[A-Za-z0-9_-]', body[j]): j += 1
        if j == i: break
        name = body[i:j].lower()
        while j < n and body[j].isspace(): j += 1
        if j >= n or body[j] != '=': break
        j += 1
        while j < n and body[j].isspace(): j += 1
        if j < n and body[j] == '{':
            start = j + 1; depth = 1; j += 1
            while j < n and depth:
                if body[j] == '{': depth += 1
                elif body[j] == '}': depth -= 1
                j += 1
            val = body[start:j-1]
        elif j < n and body[j] == '"':
            start = j + 1; j += 1
            while j < n and body[j] != '"': j += 1
            val = body[start:j]; j += 1
        else:
            start = j
            while j < n and body[j] != ',': j += 1
            val = body[start:j].strip()
        d[name] = re.sub(r'\s+', ' ', val).strip()
        while j < n and body[j] != ',': j += 1
        if j < n and body[j] == ',': j += 1
        i = j
    return d

def latex_to_text(s):
    if not s: return ''
    repl = {
        r"{\'e}": 'e', r"\'e": 'e', r"{\`e}": 'e', r"\`e": 'e',
        r"{\`E}": 'e', r"{\~n}": 'n', r"\~n": 'n', r"{\"o}": 'o',
        r"\&": '&', '{': '', '}': '', '--': '-'
    }
    t = s
    for a,b in repl.items(): t = t.replace(a,b)
    return t

def norm(s):
    s = html.unescape(latex_to_text(s or '')).lower()
    s = ''.join(c for c in unicodedata.normalize('NFKD', s) if not unicodedata.combining(c))
    s = re.sub(r'[^a-z0-9]+', ' ', s)
    return re.sub(r'\s+', ' ', s).strip()

def get_json(url):
    req = urllib.request.Request(url, headers={'User-Agent':'CodexBibcheck/1.0 (mailto:none@example.com)'})
    with urllib.request.urlopen(req, timeout=25) as r:
        return json.loads(r.read().decode('utf-8'))

def first(arr):
    return arr[0] if isinstance(arr, list) and arr else None

def year_from(m):
    for k in ('published', 'published-print', 'published-online', 'issued'):
        dp = (((m.get(k) or {}).get('date-parts') or []))
        if dp and dp[0]: return str(dp[0][0])
    return None

def meta_from_crossref_item(m):
    return {
        'title': first(m.get('title')),
        'year': year_from(m),
        'journal': first(m.get('container-title')),
        'volume': m.get('volume'),
        'number': m.get('issue'),
        'pages': m.get('page'),
        'doi': m.get('DOI'),
        'url': m.get('URL') or (('https://doi.org/' + m['DOI']) if m.get('DOI') else None),
    }

def query_crossref(f):
    if f.get('doi'):
        url = 'https://api.crossref.org/works/' + urllib.parse.quote(f['doi'])
        return meta_from_crossref_item(get_json(url)['message']), ''
    title = f.get('title','')
    url = 'https://api.crossref.org/works?rows=5&query.title=' + urllib.parse.quote(title)
    items = get_json(url)['message'].get('items', [])
    nt = norm(title)
    for item in items:
        mt = meta_from_crossref_item(item)
        if norm(mt.get('title')) == nt:
            return mt, ''
    if items:
        mt = meta_from_crossref_item(items[0])
        return None, 'Crossref top hit title mismatch: ' + str(mt.get('title'))
    return None, 'No Crossref hit'

results=[]
for file in sorted(entries_dir.glob('*.bib')):
    entry = file.read_text(encoding='utf-8-sig')
    f = parse_entry(entry)
    key = f.get('_key') or file.stem
    issues=[]; status='unverifiable'; note=''; meta=None
    try:
        meta, note = query_crossref(f)
        if meta:
            status='clean'
            for field in ['title','year','journal','volume','number','pages','doi']:
                if field in f and meta.get(field):
                    a, b = f[field], str(meta[field])
                    if norm(a) != norm(b):
                        issues.append({'field':field,'original':a,'corrected':b,'reason':'Crossref canonical metadata differs'})
            if issues:
                status='corrected'
        time.sleep(0.15)
    except Exception as e:
        note = str(e)
    one = (meta or {}).get('title') or f.get('title','')
    obj = {'key':key,'status':status,'one_sentence':one,'canonical_url':(meta or {}).get('url'),'issues':issues,'note':note,'original_bib':entry,'corrected_bib':entry}
    (reports_dir / f'{key}.json').write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding='utf-8')
    results.append(obj)
(run / 'crossref_pass.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
for r in results:
    print(f"{r['key']}: {r['status']} {r['canonical_url'] or ''} {r['note']}")
