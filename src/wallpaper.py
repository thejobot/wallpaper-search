#!/usr/bin/python3
# Wallpaper Search engine: keyword -> large, relevant image -> set as desktop picture.
# Primary source: Wallhaven (real wallpapers, JSON API, at least 1920x1080, SFW).
# Fallback: Bing image search (large filter, strict SafeSearch) when Wallhaven has nothing.
import sys, os, re, json, ssl, subprocess, urllib.request, urllib.parse, html, time, zlib, struct

LIGHT_BLUE = (173, 216, 230)          # web "lightblue" #ADD8E6
RESET_WORDS = {"reset all", "reset all monitors", "reset all monitor", "reset"}

CACHE = os.path.expanduser("~/Library/Caches/WallpaperSearch")
STATE = os.path.join(CACHE, "state.json")
MAX_BYTES = 30 * 1024 * 1024      # never download anything monstrous
MIN_WIDTH = 1280                  # reject anything not wallpaper-grade
MAX_TRIES = 8                     # bound download attempts
MIN_ASPECT = 1.2                  # reject portrait / square junk (must be landscape)
MAX_ASPECT = 3.6                  # reject panorama banners that look wrong on a desktop
UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
      "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15")
CTX = ssl.create_default_context()

def load_state():
    try:
        with open(STATE) as f: return json.load(f)
    except Exception:
        return {"used": {}, "last_keyword": "", "current_file": ""}

def save_state(s):
    os.makedirs(CACHE, exist_ok=True)
    with open(STATE, "w") as f: json.dump(s, f)

def notify(msg, title="Wallpaper Search"):
    try:
        subprocess.run(["/usr/bin/osascript", "-e",
            f'display notification "{msg}" with title "{title}"'], timeout=10)
    except Exception: pass

def get(url, timeout=20, headers=None):
    h = {"User-Agent": UA}
    if headers: h.update(headers)
    req = urllib.request.Request(url, headers=h)
    return urllib.request.urlopen(req, timeout=timeout, context=CTX)

def wallhaven_candidates(keyword):
    # Wallhaven is an all-wallpaper site, so the keyword goes in raw -- adding the
    # word "wallpaper" here only shrinks the matches.
    urls = []
    for page in (1, 2, 3):
        q = urllib.parse.urlencode({
            "q": keyword, "sorting": "relevance", "order": "desc",
            "atleast": "1920x1080", "categories": "111", "purity": "100",
            "page": str(page),
        })
        try:
            data = get(f"https://wallhaven.cc/api/v1/search?{q}").read().decode("utf-8", "ignore")
            j = json.loads(data)
        except Exception:
            break
        items = j.get("data", [])
        if not items: break
        for it in items:
            p = it.get("path")
            if p: urls.append(p)
        if page >= int(j.get("meta", {}).get("last_page", page)): break
    return urls

def bing_candidates(keyword, add_word=True):
    # Bing is the general web, so the word "wallpaper" steers it toward desktop-shaped
    # art (toggle in the UI). Strict SafeSearch is enforced two ways: the adlt=strict
    # query param and the SRCHHPGUSR cookie Bing actually reads -- both, so a stray
    # result can't slip through.
    urls = []
    query = (keyword + " wallpaper") if add_word and "wallpaper" not in keyword.lower() else keyword
    safe = {"Cookie": "SRCHHPGUSR=ADLT=STRICT"}
    for first in (1, 36, 71):
        q = urllib.parse.urlencode({"q": query, "adlt": "strict"})
        u = (f"https://www.bing.com/images/search?{q}"
             f"&qft=+filterui:imagesize-large&first={first}")
        try:
            text = html.unescape(get(u, headers=safe).read().decode("utf-8", "ignore"))
        except Exception:
            continue
        for m in re.findall(r'"murl":"(.*?)"', text):
            cand = m.replace("\\/", "/").replace("\\u0026", "&")
            if cand.startswith("http") and cand not in urls:
                urls.append(cand)
    return urls

def candidates(keyword, add_word=True):
    wh = wallhaven_candidates(keyword)
    if wh: return wh, "wallhaven"
    return bing_candidates(keyword, add_word), "bing"

def download(url, dest):
    with get(url, timeout=25) as r:
        ct = r.headers.get("Content-Type", "")
        if "image" not in ct: return False
        buf = b""
        while True:
            chunk = r.read(65536)
            if not chunk: break
            buf += chunk
            if len(buf) > MAX_BYTES: return False
        if len(buf) < 20000: return False
        with open(dest, "wb") as f: f.write(buf)
    return True

def dimensions(path):
    try:
        out = subprocess.check_output(
            ["/usr/bin/sips", "-g", "pixelWidth", "-g", "pixelHeight", path],
            stderr=subprocess.DEVNULL).decode()
        w = int(re.search(r"pixelWidth: (\d+)", out).group(1))
        h = int(re.search(r"pixelHeight: (\d+)", out).group(1))
        return w, h
    except Exception:
        return 0, 0

def make_solid_png(rgb, w, h, dest):
    # Pure-stdlib solid-color PNG (no Pillow). 8-bit truecolor; a flat field
    # compresses to a few hundred bytes regardless of dimensions.
    px = bytes(rgb)
    row = b"\x00" + px * w                 # filter byte 0 + w RGB pixels
    comp = zlib.compress(row * h, 9)
    def chunk(typ, data):
        body = typ + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xffffffff)
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)   # bit depth 8, color type 2 (RGB)
    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
           + chunk(b"IDAT", comp) + chunk(b"IEND", b""))
    with open(dest, "wb") as f:
        f.write(png)

def reset_all():
    # Special command: type "reset all" -> paint every display a flat light blue.
    os.makedirs(CACHE, exist_ok=True)
    dest = os.path.join(CACHE, "reset_lightblue.png")
    make_solid_png(LIGHT_BLUE, 2560, 1440, dest)
    set_wallpaper(dest)
    state = load_state()
    state["last_keyword"] = "reset all"
    state["current_file"] = dest
    save_state(state)
    notify("All monitors reset to light blue.")
    return 0

def set_wallpaper(path):
    # Finder mechanic (reliable on the main display) plus System Events for every display.
    # Running this while inside a given Mission Control space themes that space.
    subprocess.run(["/usr/bin/osascript", "-e",
        f'tell application "Finder" to set desktop picture to POSIX file "{path}"'], check=False)
    subprocess.run(["/usr/bin/osascript", "-e",
        f'tell application "System Events" to set picture of every desktop to "{path}"'], check=False)

def main():
    if len(sys.argv) < 2:
        print("usage: wallpaper.py <keyword> [--dry] [--no-wallpaper-word]"); return 1
    dry = "--dry" in sys.argv
    # The word "wallpaper" is appended to the search by default; the UI toggle can drop it.
    add_word = "--no-wallpaper-word" not in sys.argv
    keyword = " ".join(a for a in sys.argv[1:] if not a.startswith("--")).strip()
    if not keyword: return 1

    # "reset all" is a command, not a search: blank every monitor to light blue.
    if keyword.lower() in RESET_WORDS:
        return reset_all()

    state = load_state()
    used = set(state["used"].get(keyword, []))

    cands, source = candidates(keyword, add_word)
    if not cands:
        notify(f'No images found for "{keyword}".'); return 2

    fresh = [c for c in cands if c not in used]
    if not fresh:                      # exhausted, start the cycle over
        used = set(); fresh = cands

    os.makedirs(CACHE, exist_ok=True)
    tmp = os.path.join(CACHE, "dl.tmp")
    keep = os.path.join(CACHE, "best.tmp")
    picked = None
    best = None                        # (width, url) fallback
    tries = 0
    for url in fresh:
        if tries >= MAX_TRIES: break
        try:
            if not download(url, tmp): continue
            tries += 1
            w, h = dimensions(tmp)
            if w < MIN_WIDTH or w*h == 0: continue
            aspect = w / h
            if aspect < MIN_ASPECT or aspect > MAX_ASPECT:
                continue                  # portrait, square, or banner -> not a wallpaper
            if best is None or w > best[0]:
                os.replace(tmp, keep); best = (w, url)
                picked = url
                break                     # first wallpaper-shaped, large hit -> take it
        except Exception:
            continue

    if best is not None:
        os.replace(keep, tmp)             # winning bytes are in tmp
    if not picked:
        notify(f'Could not fetch a large image for "{keyword}".'); return 3

    # Normalize to a clean JPEG that "Set Desktop Picture" always accepts.
    stamp = str(int(time.time()))
    final = os.path.join(CACHE, f"wp_{stamp}.jpg")
    try:
        subprocess.run(["/usr/bin/sips", "-s", "format", "jpeg", tmp, "--out", final],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        final = tmp

    w, h = dimensions(final)

    if dry:
        print(f"[{source}] PICKED {picked}\n  {w}x{h} -> {final}\n  "
              f"candidates={len(cands)} fresh={len(fresh)} tries={tries}")
        return 0

    set_wallpaper(final)

    used.add(picked)
    state["used"][keyword] = list(used)
    state["last_keyword"] = keyword
    state["current_file"] = final
    save_state(state)
    # Keep only the current file so the cache never grows.
    for fn in os.listdir(CACHE):
        p = os.path.join(CACHE, fn)
        if (fn.startswith("wp_") and p != final) or fn.endswith(".tmp"):
            try: os.remove(p)
            except Exception: pass

    notify(f'{keyword}  ({w} x {h})')
    return 0

sys.exit(main())
