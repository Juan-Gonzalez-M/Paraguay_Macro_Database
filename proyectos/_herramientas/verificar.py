"""Verifica carpetas de proyectos: manifiesto vs. archivos, diccionario vs. datos,
rangos del README, fechas ISO y marcadores sin reemplazar.
Uso: python3 _herramientas/verificar.py 01_a1_reservas_liquidez [otras carpetas...]"""
import csv, os, re, sys, glob, collections
base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
csv.field_size_limit(10**9)
for d in sorted(sys.argv[1:]):
    P = os.path.join(base, d); D = os.path.join(P, 'datos'); probs = []
    man = list(csv.DictReader(open(os.path.join(D, '00_manifiesto.csv'), encoding='utf-8')))
    for m in man:
        f = os.path.join(D, m['archivo'])
        if not os.path.exists(f): probs.append('falta ' + m['archivo']); continue
        rows = list(csv.DictReader(open(f, encoding='utf-8')))
        if len(rows) != int(m['filas']): probs.append(f"filas {m['archivo']}: {len(rows)} vs {m['filas']}")
        if rows and 'fecha' in rows[0] and m['desde']:
            fs = [r['fecha'] for r in rows if r['fecha']]
            if min(fs) != m['desde'] or max(fs) != m['hasta']: probs.append('rango ' + m['archivo'])
            bad = [x for x in fs if not re.fullmatch(r'\d{4}-\d{2}-\d{2}', x)]
            if bad: probs.append(f'fechas no ISO en {m["archivo"]}: {bad[:2]}')
    dic = list(csv.DictReader(open(os.path.join(D, 'diccionario_series.csv'), encoding='utf-8')))
    obs = collections.defaultdict(list)
    for f in glob.glob(os.path.join(D, 'series_*.csv')):
        if f.endswith('_ancho.csv'): continue
        for r in csv.DictReader(open(f, encoding='utf-8')): obs[r['serie']].append(r['fecha'])
    for r in dic:
        o = obs.get(r['serie'], [])
        if not o or min(o) != r['desde'] or max(o) != r['hasta'] or len(o) != int(r['n_obs']): probs.append('dicc ' + r['serie'])
    readme = open(os.path.join(P, 'README.md'), encoding='utf-8').read()
    if '{{' in readme: probs.append('placeholder sin reemplazar')
    dd = {r['serie']: r for r in dic}; nrow = 0
    for line in readme.splitlines():
        mm = re.match(r'\| `([^`]+)` \|', line)
        if mm and mm.group(1) in dd:
            c = [x.strip() for x in line.split('|')]
            r = dd[mm.group(1)]; nrow += 1
            if c[5] != r['desde'] or c[6] != r['hasta']: probs.append('README rango ' + r['serie'])
    for m in man:
        for mm in re.finditer(r'\| `datos/%s` \| ([\d.]+) \| \d+ \| ([^|]+) \| ([^|]+) \|' % re.escape(m['archivo']), readme):
            if mm.group(2).strip() != (m['desde'] or '—') or mm.group(3).strip() != (m['hasta'] or '—'): probs.append('README manifiesto ' + m['archivo'])
    size = sum(os.path.getsize(f) for f in glob.glob(D + '/**', recursive=True) if os.path.isfile(f)) / 1e6
    print(f"{d}: {len(man)} archivos, {len(dic)} series, {nrow} filas de serie en README, {size:.1f} MB -> {'OK' if not probs else probs[:8]}")
