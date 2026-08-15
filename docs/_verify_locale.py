# Locale consistency check (dev tool, not shipped).
# Scans every authored .lua file for L["..."] usages and confirms each key is listed
# in Locales/enUS.lua, and that every translation file keys only on phrases the
# manifest knows about. A key in code but missing from the manifest still works at
# runtime (the metatable falls back to English) but will never be translated. A key
# in a translation file that is NOT in the manifest is dead weight - usually a phrase
# that was reworded in the code and orphaned here.
#
# Every file under Locales/ is generated from the EverythingLocales repo. This gate
# exists so a lone checkout of CooldownMaster still verifies itself:
#   python docs/_verify_locale.py
import re, io, glob, sys, unicodedata

KEY = re.compile(r'L\["((?:[^"\\]|\\.)*)"\]')
PAIR = re.compile(r'^\s*L\["((?:[^"\\]|\\.)*)"\]\s*=\s*"((?:[^"\\]|\\.)*)"\s*$')
ANY_ENTRY = re.compile(r'^\s*L\[')
SPEC = re.compile(r'%(?:(\d+)\$)?([-+ #0]*)(\d*)(?:\.(\d+))?([a-zA-Z])')
# %c takes a number in Lua 5.1, so it belongs with the numeric conversions
NUMERIC = set('diouxXeEfgGc')
VALID = set('diouxXeEfgGqsc')
SKIP = ('Libs/', 'Locales/', 'tools/', 'docs/')

# A key that swaps one of these for its ASCII twin decodes to bytes the manifest does
# not hold, so it silently never matches. Simplified Chinese arrived in the sibling
# repo with 64 U+2011 hyphens spelled this way and every one read as correct English.
CONFUSABLE = {
    '‑': "U+2011 non-breaking hyphen (want '-')",
    '‐': "U+2010 hyphen (want '-')",
    '–': "U+2013 en dash (want '-')",
    ' ': "U+00A0 non-breaking space (want ' ')",
    '‘': "U+2018 left single quote (want \"'\")",
    '’': "U+2019 right single quote (want \"'\")",
}


def parse_format(fmt):
    """Map argument index -> conversion type, plus counts and malformed specifiers.

    Compared by ARGUMENT INDEX rather than as a flat list, because WoW's string.format
    supports Blizzard's positional extension (%1$s, %2$d) and reordering is the entire
    point of it - a translator who moves the arguments around is correct, not broken.
    """
    args, bad = {}, []
    positional = plain = 0
    nxt = 1
    stripped = fmt.replace('%%', '')
    consumed = set()
    for m in SPEC.finditer(stripped):
        idx, _flags, width, prec, conv = m.groups()
        consumed.add(m.start())
        if conv not in VALID or len(width or '') > 2 or len(prec or '') > 2:
            bad.append(m.group(0))
            continue
        if idx:
            positional += 1
            i = int(idx)
        else:
            plain += 1
            i = nxt
            nxt += 1
        args[i] = conv
    # A '%' the pattern did not consume is a malformed escape - '%$d', a stray '%z', or a
    # lone trailing '%' where the translator meant '%%'. Lua raises on all three.
    for pos, ch in enumerate(stripped):
        if ch == '%' and pos not in consumed:
            bad.append(stripped[pos:pos + 3])
    return args, positional, plain, bad


def format_problems(key, val):
    """(fails, notes). Only fails are gated - a note is legitimate and common."""
    fails, notes = [], []
    kargs, _kp, _kn, kbad = parse_format(key)
    vargs, vpos, vplain, vbad = parse_format(val)

    for b in vbad:
        fails.append("invalid specifier %r" % b)
    if kbad:
        fails.append("invalid specifier in the ENGLISH KEY: %s" % kbad)
    if vpos and vplain:
        fails.append("mixes positional and plain specifiers in one string")

    for i, conv in sorted(vargs.items()):
        kconv = kargs.get(i)
        if kconv is None:
            fails.append("uses argument %d (%%%s) but the key supplies only %d"
                         % (i, conv, len(kargs)))
        elif conv in NUMERIC and kconv not in NUMERIC:
            fails.append("argument %d is %%%s but the key passes a string (%%%s)"
                         % (i, conv, kconv))

    # Dropping an argument is fine: Lua ignores the surplus one that gets passed, and
    # Russian and Korean have no use for English's "%s" plural suffix.
    missing = sorted(set(kargs) - set(vargs))
    if missing and not fails:
        notes.append("does not use argument(s) " + ", ".join(str(i) for i in missing))
    return fails, notes


def confusables_in(key):
    return ["%s at column %d" % (CONFUSABLE[c], i + 1)
            for i, c in enumerate(key) if c in CONFUSABLE]


def strip_comments(s):
    # drop full-line Lua comments so doc examples like L["English string"] in
    # headers don't register as real keys. (Good enough; no block-comment use.)
    return '\n'.join(l for l in s.splitlines() if not l.lstrip().startswith('--'))


def keyset(path):
    s = strip_comments(io.open(path, encoding='utf-8', errors='replace').read())
    return set(m.group(1) for m in KEY.finditer(s))


manifest = keyset('Locales/enUS.lua')

code = {}
for path in glob.glob('**/*.lua', recursive=True):
    p = path.replace('\\', '/')
    if any(p.startswith(s) for s in SKIP):
        continue
    for k in keyset(p):
        code.setdefault(k, []).append(p)

print("distinct keys used in code:", len(code))
print("keys listed in enUS.lua   :", len(manifest))

problems = 0

missing = {k: v for k, v in code.items() if k not in manifest}
print("\nCODE keys MISSING from manifest (work, but are never translated):")
if missing:
    problems += len(missing)
    for k in sorted(missing):
        print("   !", repr(k[:60]), "<-", ", ".join(sorted(set(missing[k]))))
else:
    print("   (none - every code key is in the manifest)")

print("\nTRANSLATION files:")
for path in sorted(glob.glob('Locales/*.lua')):
    p = path.replace('\\', '/')
    if p.endswith('enUS.lua'):
        continue
    ks = keyset(p)
    orphans = sorted(k for k in ks if k not in manifest)

    # A translation whose format specifiers cannot satisfy its English key makes
    # string.format() raise the first time that line is drawn - at runtime, in one
    # language only, where nobody testing in English ever sees it.
    badfmt, noted, confused, unread = [], [], [], 0
    for line in io.open(p, encoding='utf-8').read().splitlines():
        if line.lstrip().startswith('--'):
            continue
        if not ANY_ENTRY.match(line):
            continue
        m = PAIR.match(line)
        # An L[...] line the parser cannot read would be skipped silently and pass. A
        # false negative in a gate is the dangerous kind, so it counts as a problem.
        if not m:
            unread += 1
            continue
        fails, notes = format_problems(m.group(1), m.group(2))
        if fails:
            badfmt.append((m.group(1), fails))
        if notes:
            noted.append((m.group(1), notes))
        why = confusables_in(m.group(1))
        if why:
            confused.append((m.group(1), why))

    print("   %-18s %4d phrases, %d orphaned, %d bad format, %d confusable, %d note(s)"
          % (p, len(ks), len(orphans), len(badfmt), len(confused), len(noted)))
    if orphans:
        problems += len(orphans)
        for k in orphans:
            print("      ! orphan:", ascii(k[:60]))
    if unread:
        problems += unread
        print("      ! %d L[...] line(s) the parser could not read, so they were NOT "
              "checked" % unread)
    for k, why in confused:
        problems += 1
        print("      ! KEY has look-alike punctuation:", ascii(k[:55]))
        for w in why:
            print("        -> %s" % w)
    for k, why in badfmt:
        problems += 1
        print("      ! %s" % repr(k[:55]))
        for w in why:
            print("        -> %s" % w)
    for k, why in noted:
        print("      - note: %s (%s)" % (repr(k[:50]), "; ".join(why)))

sys.exit(1 if problems else 0)
