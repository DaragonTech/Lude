import random, struct, subprocess, sys, math
from decimal import Decimal, getcontext, ROUND_HALF_UP, ROUND_HALF_EVEN
getcontext().prec = 2000
random.seed(1)
def bits(d): return struct.unpack('<Q', struct.pack('<d', d))[0]
def legacy_digits(x):
    # exact digits then round to 17 sig half-up
    if x == 0: return '', 1
    d = Decimal(abs(x))
    s, e = d.as_tuple().digits, d.as_tuple().exponent
    D = ''.join(map(str,s)).lstrip('0')
    decpt = len(''.join(map(str,s))) + e
    # normalize: decpt relative to D after stripping leading zeros (digits tuple has none)
    D = D.rstrip('0')
    if len(D) > 17:
        q = Decimal('0.' + D).quantize(Decimal('1e-17'), rounding=ROUND_HALF_UP)
        if q >= 1: D = '1'; decpt += 1
        else: D = str(q)[2:].rstrip('0') or ''
    return D, decpt
def rnd(D, decpt, keep):
    if keep >= len(D): return D, decpt
    if keep < 0: return '', decpt
    up = D[keep] >= '5'
    D = D[:keep]
    if up:
        n = int(D) + 1 if D else 1
        s = str(n)
        if len(s) > keep:
            decpt += 1
            s = s[:keep] if keep > 0 else '1'
        D = s
    return D, decpt
def dig(D, i): return D[i-1] if 1 <= i <= len(D) else '0'
def fixed(D, decpt, prec):
    ip = '0' if decpt <= 0 else ''.join(dig(D,i) for i in range(1,decpt+1))
    fp = ''.join(dig(D, decpt+i) for i in range(1, prec+1))
    return ip + ('.' + fp if prec > 0 else '')
def expf(D, decpt, prec):
    m = dig(D,1) + ('.' + ''.join(dig(D,1+i) for i in range(1,prec+1)) if prec>0 else '')
    e = 0 if D=='' else decpt-1
    return m + 'e' + ('-' if e<0 else '+') + ('%03d' % abs(e))
def strip(s):
    if 'e' in s: m, e = s.split('e'); e = 'e'+e
    else: m, e = s, ''
    if '.' in m: m = m.rstrip('0').rstrip('.')
    return m + e
def legacy(x, conv, prec):
    sign = '-' if math.copysign(1,x) < 0 else ''
    D, decpt = legacy_digits(x)
    if conv == 'f':
        D, decpt = rnd(D, decpt, decpt+prec); return sign + fixed(D, decpt, prec)
    if conv == 'e':
        if D == '': decpt = 1
        D, decpt = rnd(D, decpt, prec+1); return sign + expf(D, decpt, prec)
    P = prec or 1
    if D == '': decpt = 1
    D, decpt = rnd(D, decpt, P)
    if D == '': decpt = 1
    X = decpt - 1
    body = fixed(D, decpt, P-1-X) if P > X >= -4 else expf(D, decpt, P-1)
    return sign + strip(body)
cases = []
vals = [0.1, 0.5, 1.5, 2.5, 1e20, 2**63, 1/3, 123456789012345678, 1e-5, 5e-324, 1.7976931348623157e308, 1e15, 1e14, 99999999999999.5, 0.000123456, 3.14159265358979, -2.5, 1e100, 2.2250738585072014e-308, 12345.6789, 0.0]
for i in range(3000):
    k = random.randint(0,3)
    if k == 0: v = struct.unpack('<d', struct.pack('<Q', random.getrandbits(64)))[0]
    elif k == 1: v = random.uniform(-1e6,1e6)
    elif k == 2: v = float(random.randint(-10**17, 10**17)) * 10**random.randint(-25,25)
    else: v = round(random.uniform(0, 1000), random.randint(0,6))
    if math.isnan(v) or math.isinf(v): continue
    vals.append(v)
fmts = [('N',None,None),('%.14g','g',14),('%e','e',6),('%.3f','f',3),('%g','g',6),('%.0f','f',0),('%.20f','f',20),('%.1e','e',1),('%.17g','g',17)]
inp = []; exp = []
for v in vals:
    for f, c, p in fmts:
        if c == 'f' and abs(v) > 1e40: continue
        inp.append('p %016x %s' % (bits(v), f))
        exp.append(legacy(v, 'g' if f=='N' else c, 14 if f=='N' else p))
# strtod tests
strs = ['0.1','1e23','2.2250738585072011e-308','4.9e-324','2.4703282292062327e-324','2.4703282292062328e-324','1.7976931348623158e308','1.7976931348623159e308','123456789012345678901234567890','0.000000000000000000000000000001234','  -12.5e-3xyz','1d5','.5','5.','.','e5','1e','0x10','3.14159265358979323846264338327950288','9007199254740993','9007199254740992.5','1'+'0'*400+'e-400','0.'+'0'*300+'1']
for i in range(2000):
    v = struct.unpack('<d', struct.pack('<Q', random.getrandbits(64)))[0]
    if math.isnan(v) or math.isinf(v): continue
    strs.append(repr(v))
    strs.append('%.25e' % v)
    strs.append('%.16e' % v)
for st in strs:
    inp.append('s ' + st)
    # expected via python
    s = st.lstrip(' ')
    import re
    m = re.match(r'[+-]?(\d+\.?\d*|\.\d+)([eEdD][+-]?\d+)?', s)
    if not m: exp.append('%016x 0' % 0); continue
    t = m.group(0).replace('d','e').replace('D','e')
    exp.append('%016x %d' % (bits(float(t)), len(st)-len(s)+m.end()))
open('crt_in.txt','w').write('\n'.join(inp)+'\n')
for exe in sys.argv[1:]:
    out = subprocess.run(['wine', exe], input=open('crt_in.txt').read(), capture_output=True, text=True, env={'WINEDEBUG':'-all', **__import__('os').environ}).stdout.replace('\r','').split('\n')
    bad = 0
    for i,(a,b) in enumerate(zip(inp, exp)):
        if out[i] != b:
            bad += 1
            if bad <= 12: print(exe, 'MISMATCH', a, '| got', out[i], '| exp', b)
    print(exe, 'cases', len(inp), 'bad', bad)
