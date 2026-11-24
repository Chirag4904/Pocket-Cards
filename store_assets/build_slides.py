"""Builds the 8 Play Store listing images (1080x1920) from real app captures.

Usage: python3 store_assets/build_slides.py
Inputs: store_assets/raw/*.png (simulator captures, demo mode) and
        store_assets/parts/*.png (cropped cards / UI pieces).
Output: store_assets/out/0N_*.png
"""
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent
FONTS = ROOT.parent / "assets" / "fonts"
OUT = ROOT / "out"
OUT.mkdir(exist_ok=True)
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

LOCK_SVG = (
    '<svg viewBox="0 0 24 24" width="100%" height="100%"><path fill="currentColor" '
    'd="M12 1.75a5.25 5.25 0 0 0-5.25 5.25v3H6A2.25 2.25 0 0 0 3.75 12.25v8A2.25 2.25 0 0 0 6 22.5h12'
    'a2.25 2.25 0 0 0 2.25-2.25v-8A2.25 2.25 0 0 0 18 10h-.75V7A5.25 5.25 0 0 0 12 1.75Zm-3.75 5.25'
    'a3.75 3.75 0 1 1 7.5 0v3h-7.5V7ZM12 14a1.75 1.75 0 0 1 .75 3.33V19a.75.75 0 0 1-1.5 0v-1.67'
    'A1.75 1.75 0 0 1 12 14Z"/></svg>'
)

CSS = f"""
@font-face {{ font-family: Doto; src: url('file://{FONTS}/Doto.ttf'); }}
@font-face {{ font-family: Grotesk; src: url('file://{FONTS}/SpaceGrotesk-Regular.ttf'); font-weight: 400; }}
@font-face {{ font-family: Grotesk; src: url('file://{FONTS}/SpaceGrotesk-Medium.ttf'); font-weight: 500; }}
@font-face {{ font-family: Grotesk; src: url('file://{FONTS}/SpaceGrotesk-Bold.ttf'); font-weight: 700; }}
@font-face {{ font-family: Mono; src: url('file://{FONTS}/SpaceMono-Regular.ttf'); }}

* {{ margin: 0; padding: 0; box-sizing: border-box; }}
html, body {{ width: 1080px; height: 1920px; overflow: hidden; }}
body {{ background: #07080c; color: #f4f6fb; font-family: Grotesk; position: relative; }}

/* ambient light + Nothing-style dot grid */
.blob {{ position: absolute; border-radius: 50%; filter: blur(40px); }}
.grid {{ position: absolute; inset: 0;
  background-image: radial-gradient(rgba(255,255,255,.075) 1.6px, transparent 1.8px);
  background-size: 30px 30px;
  -webkit-mask-image: linear-gradient(180deg, #000 0%, rgba(0,0,0,.35) 45%, transparent 85%); }}

.copy {{ position: absolute; left: 84px; right: 84px; top: 118px; z-index: 5; }}
.kicker {{ font-family: Mono; font-size: 25px; letter-spacing: .22em; color: #8d96aa;
  display: flex; align-items: center; gap: 16px; }}
.kicker b {{ color: #d4f46a; font-weight: 400; }}
.kicker i {{ flex: 0 0 56px; height: 2px; background: #2a2f3c; }}
h1 {{ font-family: Doto; font-variation-settings: 'wght' 900, 'ROND' 100; font-weight: 400;
  font-size: 128px; line-height: .98; letter-spacing: -2px; margin-top: 34px; }}
.g {{ background: linear-gradient(95deg, #e4fa96 0%, #d4f46a 50%, #b4e24a 100%);
  -webkit-background-clip: text; background-clip: text; color: transparent; }}
.sub {{ margin-top: 30px; font-size: 38px; line-height: 1.32; color: #a3abbd; max-width: 860px; text-wrap: balance; }}

/* phone */
.phone {{ position: absolute; padding: 15px; border-radius: 96px; z-index: 2;
  background: linear-gradient(150deg, #5a5e68 0%, #1a1b20 18%, #0c0d10 50%, #26272d 82%, #6a6e78 100%);
  box-shadow: 0 0 0 1.5px rgba(255,255,255,.10), 0 70px 140px rgba(0,0,0,.75),
              0 0 120px rgba(212,244,106,.06); }}
.phone::before {{ content: ''; position: absolute; inset: 6px; border-radius: 90px;
  box-shadow: inset 0 0 0 2px rgba(0,0,0,.9); pointer-events: none; }}
.screen {{ border-radius: 82px; overflow: hidden; background: #000; }}
.screen img {{ display: block; width: 100%; }}
.btn {{ position: absolute; width: 6px; border-radius: 3px; background: linear-gradient(90deg,#2b2c31,#6b6e76); }}

/* things breaking out of the frame */
.pop {{ position: absolute; z-index: 4; transform-style: preserve-3d;
  filter: drop-shadow(0 46px 50px rgba(0,0,0,.6)) drop-shadow(0 12px 18px rgba(0,0,0,.35)); }}
.pop img {{ display: block; width: 100%; }}
.chip {{ position: absolute; z-index: 6; display: flex; align-items: center; gap: 14px;
  padding: 18px 28px; border-radius: 999px; font-size: 29px; font-weight: 500;
  background: rgba(22,25,33,.82); border: 1.5px solid rgba(255,255,255,.12);
  box-shadow: 0 24px 50px rgba(0,0,0,.5); backdrop-filter: blur(14px); white-space: nowrap; }}
.dot {{ width: 14px; height: 14px; border-radius: 50%; background: #d4f46a; box-shadow: 0 0 16px #d4f46a; }}
.ico {{ width: 30px; height: 30px; color: #d4f46a; }}
.fade {{ position: absolute; left: 0; right: 0; bottom: 0; z-index: 3;
  background: linear-gradient(180deg, transparent, #07080c 70%); }}

/* a magnified slice of the real screen, lifted out of the phone */
.zoom {{ position: absolute; z-index: 5; background-repeat: no-repeat; background-color: #13161e;
  border: 2px solid rgba(255,255,255,.16);
  box-shadow: 0 0 0 10px rgba(212,244,106,.07), 0 60px 110px rgba(0,0,0,.7), 0 18px 30px rgba(0,0,0,.4); }}
.zoom::after {{ content: ''; position: absolute; inset: 0; border-radius: inherit;
  background: linear-gradient(160deg, rgba(255,255,255,.10), transparent 35%); pointer-events: none; }}
.ripple {{ position: absolute; z-index: 1; border-radius: 50%; border: 3px solid #d4f46a;
  transform: translate(-50%,-50%); }}
"""


def phone(img, left, top, width, transform="", clip_h=None):
    side = (
        f'<div class="btn" style="left:-5px;top:{width*0.36:.0f}px;height:{width*0.13:.0f}px"></div>'
        f'<div class="btn" style="left:-5px;top:{width*0.52:.0f}px;height:{width*0.13:.0f}px"></div>'
        f'<div class="btn" style="right:-5px;top:{width*0.45:.0f}px;height:{width*0.2:.0f}px"></div>'
    )
    return (
        f'<div class="phone" style="left:{left}px;top:{top}px;width:{width}px;transform:{transform}">'
        f'{side}<div class="screen"><img src="file://{ROOT}/raw/{img}"></div></div>'
    )


def pop(part, left, top, width, transform, extra=""):
    return (
        f'<div class="pop" style="left:{left}px;top:{top}px;width:{width}px;transform:{transform};{extra}">'
        f'<img src="file://{ROOT}/parts/{part}"></div>'
    )


def _size(img):
    from PIL import Image
    return Image.open(ROOT / "raw" / img).size


def zoom(img, box, left, top, width, transform="", radius=40):
    """Crops box=(x, y, w, h) of a raw capture and shows it magnified in its own frame."""
    x, y, w, h = box
    iw, ih = _size(img)
    k = width / w
    return (
        f'<div class="zoom" style="left:{left}px;top:{top}px;width:{width}px;height:{h * k:.0f}px;'
        f'border-radius:{radius}px;transform:{transform};'
        f"background-image:url('file://{ROOT}/raw/{img}');"
        f'background-size:{iw * k:.0f}px {ih * k:.0f}px;background-position:-{x * k:.0f}px -{y * k:.0f}px"></div>'
    )


def ripples(cx, cy, sizes=(180, 300, 430, 570)):
    """Contactless waves, fading outward."""
    return "".join(
        f'<div class="ripple" style="left:{cx}px;top:{cy}px;width:{d}px;height:{d}px;opacity:{0.75 - i * 0.18:.2f}"></div>'
        for i, d in enumerate(sizes)
    )


def chip(text, left, top, icon="dot", rot=0):
    mark = '<span class="dot"></span>' if icon == "dot" else f'<span class="ico">{LOCK_SVG}</span>'
    return f'<div class="chip" style="left:{left}px;top:{top}px;transform:rotate({rot}deg)">{mark}{text}</div>'


def blobs(*specs):
    return "".join(
        f'<div class="blob" style="left:{x}px;top:{y}px;width:{s}px;height:{s}px;'
        f'background:radial-gradient(circle, {c} 0%, transparent 68%)"></div>'
        for x, y, s, c in specs
    )


def copy(num, label, title, sub):
    return (
        f'<div class="copy"><div class="kicker"><b>{num}</b><i></i>{label}</div>'
        f'<h1>{title}</h1><div class="sub">{sub}</div></div>'
    )


SLIDES = {
    # 1 — hero: the wallet, with cards bursting out of the phone
    "01_hero": blobs((-260, 520, 1100, "rgba(212,244,106,.10)"), (520, 1000, 900, "rgba(79,224,176,.10)"))
    + copy("01", "POCKET CARDS", 'Your cards.<br>Offline.<br><span class="g">Locked.</span>',
           "A beautiful card wallet that never leaves your phone.")
    + phone("01_home.png", 250, 900, 600, "perspective(2600px) rotateY(-12deg) rotateX(4deg)")
    + pop("orbit.png", -90, 1300, 540, "perspective(1600px) rotateY(24deg) rotateZ(-14deg)")
    + pop("lumen.png", 640, 1010, 500, "perspective(1600px) rotateY(-26deg) rotateZ(11deg)")
    + pop("nova_front.png", 470, 1560, 560, "perspective(1600px) rotateX(16deg) rotateY(-14deg) rotateZ(-5deg)")
    + chip("On-device only", 70, 960, "lock", -3)
    + chip("No internet needed", 600, 870, "dot", 3)
    + '<div class="fade" style="height:160px"></div>',

    # 2 — the card itself in 3D, front and back
    "02_flip": blobs((-200, 700, 1000, "rgba(79,224,176,.12)"), (500, 1150, 900, "rgba(212,244,106,.16)"))
    + copy("02", "TAP · TILT · FLIP", 'Tap. Flip.<br>See it <span class="g">all.</span>',
           "Tilt it, flip it, hold to peek. Your card, in real 3D.")
    + phone("03_detail_visible.png", 300, 980, 580, "perspective(2600px) rotateY(10deg)")
    + pop("nova_back.png", 520, 1420, 560, "perspective(1500px) rotateY(-30deg) rotateZ(9deg)")
    + pop("nova_front.png", 40, 930, 760, "perspective(1500px) rotateX(14deg) rotateY(22deg) rotateZ(-8deg)")
    + chip("Hold to peek", 580, 880, "dot", 4)
    + chip("CVV on the back", 600, 1880, "lock", -2)
    + '<div class="fade" style="height:120px"></div>',

    # 3 — privacy: masked by default, self-wiping clipboard
    "03_private": blobs((420, 620, 1000, "rgba(79,224,176,.14)"), (-300, 1300, 900, "rgba(212,244,106,.10)"))
    + copy("03", "PRIVATE BY DEFAULT", 'Hidden until<br>you <span class="g">need it.</span>',
           "Numbers stay masked. One tap copies, then your clipboard wipes itself in 30 seconds.")
    + phone("02_detail_hidden.png", 120, 960, 600, "perspective(2600px) rotateY(14deg)")
    + pop("copytile.png", 170, 1330, 800, "perspective(1400px) rotateY(-16deg) rotateX(8deg) rotateZ(-3deg)")
    + pop("toast.png", 150, 1640, 880, "perspective(1400px) rotateY(-12deg) rotateZ(2deg)")
    + chip("Masked by default", 560, 975, "lock", 3)
    + '<div class="fade" style="height:110px"></div>',

    # 4 — NFC: tap the card, the form fills itself; the filled card pops out
    "04_scan": blobs((300, 1200, 1000, "rgba(212,244,106,.16)"), (-300, 700, 800, "rgba(79,224,176,.12)"))
    + copy("04", "NFC SCAN", 'Just tap<br>your <span class="g">card.</span>',
           "Hold a card to the back of your phone. Number and expiry fill themselves.")
    + ripples(735, 1700, sizes=(420, 620, 830, 1040))
    + phone("09_scanning.png", 420, 810, 600, "perspective(2600px) rotateY(-10deg)")
    + zoom("10_scanned.png", (54, 590, 1098, 700), 20, 900, 640,
           "perspective(1600px) rotateY(20deg) rotateX(8deg) rotateZ(-8deg)", radius=34)
    + zoom("10_scanned.png", (54, 2140, 1098, 140), 40, 1600, 600,
           "perspective(1600px) rotateY(12deg) rotateZ(-2deg)", radius=24)
    + chip("Android · NFC", 650, 830, "dot", 4)
    + chip("CVV stays private", 60, 1900, "lock", -2)
    + '<div class="fade" style="height:110px"></div>',

    # 5 — bill reminders: the real notification pops out above the phone
    "05_remind": blobs((460, 700, 1000, "rgba(212,244,106,.16)"), (-300, 1300, 900, "rgba(79,224,176,.12)"))
    + copy("05", "BILL REMINDERS", 'Never miss<br>a <span class="g">bill date.</span>',
           "Pick the day your bill comes. Get a nudge before it, sent by your phone.")
    + phone("11_reminder.png", 200, 1010, 620, "perspective(2600px) rotateY(12deg)")
    + zoom("12_notification.png", (24, 174, 1164, 204), 50, 900, 980,
           "perspective(1600px) rotateX(10deg) rotateZ(-2deg)", radius=56)
    + zoom("11_reminder.png", (40, 1700, 960, 420), 480, 1500, 560,
           "perspective(1600px) rotateY(-18deg) rotateZ(4deg)", radius=30)
    + chip("No server needed", 610, 1180, "lock", 3)
    + '<div class="fade" style="height:110px"></div>',

    # 6 — personalisation: skins orbit the phone, the picker pops out
    "06_yours": blobs((-200, 600, 900, "rgba(79,224,176,.14)"), (500, 1200, 900, "rgba(79,224,176,.12)"),
                      (300, 900, 600, "rgba(212,244,106,.10)"))
    + copy("06", "PICK A VIBE", 'Make it<br><span class="g">yours.</span>',
           "Gradients, artwork or your own photo, with logo styles to match.")
    + phone("06_add.png", 250, 860, 580, "perspective(2600px) rotateX(6deg)")
    + pop("orbit.png", -150, 1090, 470, "perspective(1500px) rotateY(30deg) rotateZ(-18deg)")
    + pop("lumen.png", 690, 820, 450, "perspective(1500px) rotateY(-30deg) rotateZ(16deg)")
    + pop("mono.png", 680, 1500, 480, "perspective(1500px) rotateY(-28deg) rotateZ(-12deg)")
    + zoom("06_add.png", (36, 1365, 1140, 330), 40, 1560, 820,
           "perspective(1600px) rotateY(14deg) rotateZ(-3deg)", radius=30)
    + '<div class="fade" style="height:140px"></div>',

    # 7 — sharing: the generated image pops out of the share sheet
    "07_share": blobs((-260, 800, 1000, "rgba(79,224,176,.10)"), (480, 600, 900, "rgba(79,224,176,.14)"))
    + copy("07", "SHARE · COPY", 'Share it<br><span class="g">your way.</span>',
           "Send a card as an image, full or masked, or copy every detail at once.")
    + phone("05_share.png", 440, 900, 580, "perspective(2600px) rotateY(-14deg)")
    + pop("sharecomp.png", 10, 1100, 510, "perspective(1500px) rotateY(24deg) rotateZ(-6deg)")
    + chip("Full or masked", 110, 1880, "dot", -2)
    + chip("Copy all details", 600, 790, "dot", 3)
    + '<div class="fade" style="height:90px"></div>',

    # 8 — backups: the lock pops out of the backup sheet
    "08_backup": blobs((-200, 900, 1000, "rgba(212,244,106,.18)"), (520, 700, 800, "rgba(79,224,176,.10)"))
    + copy("08", "BACKUP · RESTORE", 'Back up with<br>a <span class="g">password.</span>',
           "Encrypted backups you own. Switch phones without losing a single card.")
    + phone("07_backup_clean.png", 220, 940, 640, "perspective(2600px) rotateX(10deg)")
    + '<div class="pop" style="left:690px;top:880px;width:300px;height:300px;'
      'transform:perspective(1200px) rotateY(-24deg) rotateX(10deg) rotateZ(10deg)">'
      '<div style="width:100%;height:100%;border-radius:84px;display:flex;align-items:center;justify-content:center;'
      'background:linear-gradient(140deg,#e4fa96,#d4f46a 50%,#b4e24a);'
      'box-shadow:inset 0 2px 0 rgba(255,255,255,.5), inset 0 -18px 40px rgba(0,0,0,.25), 0 0 120px rgba(212,244,106,.35)">'
      f'<div style="width:150px;height:150px;color:#0a0c11">{LOCK_SVG}</div></div></div>'
    + chip("AES-256 encrypted", 60, 1080, "lock", -4)
    + chip("pocket-cards.pcbackup", 500, 1815, "dot", 3)
    + chip("Restore on any phone", 60, 1740, "dot", -2)
    + '<div class="fade" style="height:230px"></div>',
}


# How far each composition is lifted to close the gap under the headline.
SHIFT = {"01_hero": 110, "02_flip": 240, "03_private": 230, "04_scan": 200, "05_remind": 160,
         "06_yours": 110, "07_share": 120, "08_backup": 40}


def lift(name, body):
    """Wraps everything after the headline block in a stage moved up by SHIFT."""
    start = body.index('<div class="copy">')
    end = body.index("</div></div>", body.index('<div class="sub">', start)) + len("</div></div>")
    dy = SHIFT.get(name, 0)
    return (body[:end] + f'<div style="position:absolute;left:0;right:0;top:-{dy}px;height:{1920 + dy}px">'
            + body[end:] + "</div>")


def main():
    for name, body in SLIDES.items():
        body = lift(name, body)
        html = ROOT / f".{name}.html"
        html.write_text(f"<!doctype html><html><head><meta charset='utf-8'><style>{CSS}</style></head>"
                        f"<body><div class='grid'></div>{body}</body></html>")
        out = OUT / f"{name}.png"
        subprocess.run([
            CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
            "--allow-file-access-from-files", "--force-device-scale-factor=1",
            "--virtual-time-budget=4000", "--window-size=1080,1920",
            f"--screenshot={out}", f"file://{html}",
        ], check=True, capture_output=True)
        html.unlink()
        print("wrote", out.relative_to(ROOT.parent))


FEATURE_CSS = CSS.replace("width: 1080px; height: 1920px;", "width: 1024px; height: 500px;") + """
.wordmark { font-family: Doto; font-variation-settings: 'wght' 900, 'ROND' 100;
  font-size: 118px; line-height: 1; letter-spacing: -2px; }
.fan { position: absolute; left: 676px; top: 96px; width: 290px; height: 183px;
  transform: perspective(1400px) rotateX(16deg) rotateY(-14deg); transform-style: preserve-3d; }
.fan .pop { left: 0; top: 0; width: 290px; transform-origin: 50% 230%; }
"""


def build_feature():
    """1024x500 Play feature graphic, rendered at 2x then downsampled for crisp edges.

    Wordmark on the left; on the right the real wallet screen, with a card
    and the real bill-reminder notification popping out of it.
    """
    phone_html = phone("01_home.png", 0, 0, 600, "")
    body = (
        blobs((-300, -320, 860, "rgba(212,244,106,.20)"), (560, 80, 700, "rgba(79,224,176,.14)"))
        + '<div style="position:absolute;inset:0;opacity:.45">' + ripples(820, 300, sizes=(360, 520, 680)) + '</div>'
        + '<div style="position:absolute;left:60px;top:70px;z-index:5;width:560px">'
          '<div class="kicker" style="font-size:15px;gap:12px"><b>●</b><i style="flex-basis:30px"></i>'
          'OFFLINE · NFC SCAN · REMINDERS</div>'
          '<div class="wordmark" style="margin-top:24px">pocket<span class="g">.</span></div>'
          '<div style="margin-top:22px;font-size:27px;line-height:1.3;color:#f4f6fb;font-weight:500">'
          'Your cards, beautifully kept.</div>'
          '<div style="margin-top:6px;font-size:21px;line-height:1.35;color:#8d96aa">'
          'Encrypted on your phone. Never online.</div></div>'
        # the phone, scaled down and tilted, running off the bottom edge
        + f'<div style="position:absolute;left:690px;top:58px;width:600px;z-index:2;'
          f'transform-origin:0 0;transform:scale(.42) perspective(2600px) rotateY(-14deg) rotateZ(4deg)">'
          f'<div style="position:relative">{phone_html}</div></div>'
        + pop("nova_front.png", 560, 236, 270, "perspective(1400px) rotateY(24deg) rotateZ(-10deg)")
        + zoom("12_notification.png", (24, 174, 1164, 204), 580, 36, 400,
               "perspective(1400px) rotateX(8deg) rotateZ(-3deg)", radius=26)
        + '<div class="fade" style="height:70px;z-index:4"></div>'
    )
    body = body.replace('class="chip" style="', 'class="chip" style="font-size:20px;padding:11px 20px;')
    html = ROOT / ".feature.html"
    html.write_text(f"<!doctype html><html><head><meta charset='utf-8'><style>{FEATURE_CSS}</style></head>"
                    f"<body><div class='grid'></div>{body}</body></html>")
    big = OUT / ".feature@2x.png"
    subprocess.run([
        CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
        "--allow-file-access-from-files", "--force-device-scale-factor=2",
        "--virtual-time-budget=4000", "--window-size=1024,500",
        f"--screenshot={big}", f"file://{html}",
    ], check=True, capture_output=True)
    html.unlink()
    from PIL import Image  # Play wants 24-bit (no alpha)
    Image.open(big).convert("RGB").resize((1024, 500), Image.LANCZOS).save(OUT / "feature_graphic.png", optimize=True)
    big.unlink()
    print("wrote", (OUT / "feature_graphic.png").relative_to(ROOT.parent))


if __name__ == "__main__":
    import sys
    if "--feature" not in sys.argv:
        main()
    build_feature()
