"""Build only public static assets, using the app's canonical policy and wordmark."""
import argparse
import hashlib
import html
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parent.parent
POLICY = ROOT / "StayGrubby/Legal/PrivacyPolicy.md"
LOGO = ROOT / "StayGrubby/Assets.xcassets/StayGrubbyWordmark.imageset/StayGrubbyWordmark.png"


def inline(text):
    text = html.escape(text)
    text = re.sub(r"\[([^\]]+)\]\((https://[^\s)]+|mailto:[^\s)]+)\)",
                  r'<a href="\2">\1</a>', text)
    return re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)


def policy_html(text):
    blocks = []
    for block in text.strip().split("\n\n"):
        if block.startswith("# "):
            blocks.append(f"<h1>{inline(block[2:])}</h1>")
        elif block.startswith("## "):
            blocks.append(f"<h2>{inline(block[3:])}</h2>")
        else:
            blocks.append(f"<p>{inline(block)}</p>")
    return "\n".join(blocks)


def page(title, route, content, extra_class=""):
    return f'''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="light">
  <meta name="description" content="StayGrubby, a private cooking journal and personal ranking app for iPhone.">
  <title>{html.escape(title)}</title>
  <link rel="canonical" href="https://staygrubby.com{route}">
  <link rel="icon" type="image/png" href="/assets/wordmark.png">
  <link rel="stylesheet" href="/assets/site.css">
</head>
<body>
  <a class="skip" href="#main">Skip to content</a>
  <header class="site-header">
    <a class="brand" href="/" aria-label="StayGrubby home"><img src="/assets/wordmark.png" width="1254" height="1254" alt="#stayGRUBBY"></a>
    <nav aria-label="Main navigation"><a href="/privacy">Privacy</a><a href="/support">Support</a></nav>
  </header>
  <main id="main" class="{extra_class}">{content}</main>
  <footer><span>StayGrubby</span><a href="/privacy">Privacy Policy</a><a href="mailto:support@staygrubby.com">Support</a><a href="mailto:privacy@staygrubby.com">Privacy contact</a></footer>
</body>
</html>
'''


def build(output):
    output.mkdir(parents=True, exist_ok=True)
    allowed = {"index.html", "privacy.html", "support.html", "404.html", "_headers",
               "assets/site.css", "assets/wordmark.png"}
    unexpected = {str(p.relative_to(output)) for p in output.rglob("*") if p.is_file()} - allowed
    if unexpected:
        raise ValueError("Refusing to publish unexpected files: " + ", ".join(sorted(unexpected)))
    (output / "assets").mkdir(exist_ok=True)
    text = POLICY.read_text(encoding="utf-8")
    assert "Effective date: October 20, 2026" in text
    landing = '''<section class="hero">
      <p class="eyebrow">Your cooking. Your taste.</p>
      <h1>Remember what<br>you loved cooking.</h1>
      <p class="intro">Keep a private cooking journal, compare your dishes, and build a ranking that reflects your taste.</p>
      <p class="release">An iPhone app being prepared for release.</p>
      <a class="button" href="/privacy">Read our Privacy Policy <span aria-hidden="true">↗</span></a>
    </section>
    <section class="features" aria-label="About StayGrubby">
      <article><span class="number" aria-hidden="true">01</span><h2>Keep your cooks</h2><p>Record dishes, photos, notes, and the versions you want to remember.</p></article>
      <article><span class="number" aria-hidden="true">02</span><h2>Find your favorites</h2><p>Compare what you have cooked and see your personal ranking take shape.</p></article>
      <article><span class="number" aria-hidden="true">03</span><h2>Make it personal</h2><p>Your cooking library stays private. Choose when to share a dish image using your iPhone’s share sheet.</p></article>
    </section>'''
    (output / "index.html").write_text(page("StayGrubby — Your cooking. Your taste.", "/", landing), encoding="utf-8")
    (output / "privacy.html").write_text(page("Privacy Policy — StayGrubby", "/privacy",
        '<article class="policy">\n' + policy_html(text) + '\n</article>', "reading"), encoding="utf-8")
    support = '''<article class="policy"><p class="eyebrow">Here to help</p><h1>Support</h1>
      <p>For questions about StayGrubby, email <a href="mailto:support@staygrubby.com">support@staygrubby.com</a>.</p>
      <p>Include what you were trying to do and your app and iOS version. Please do not send passwords, sign-in codes, or private keys.</p>
      <p>For privacy questions, contact <a href="mailto:privacy@staygrubby.com">privacy@staygrubby.com</a> or read our <a href="/privacy">Privacy Policy</a>.</p></article>'''
    (output / "support.html").write_text(page("Support — StayGrubby", "/support", support, "reading"), encoding="utf-8")
    (output / "404.html").write_text(page("Page not found — StayGrubby", "/",
        '<article class="policy"><h1>Page not found</h1><p><a href="/">Return to StayGrubby</a></p></article>', "reading"), encoding="utf-8")
    shutil.copyfile(LOGO, output / "assets/wordmark.png")
    shutil.copyfile(ROOT / "Website/site.css", output / "assets/site.css")
    shutil.copyfile(ROOT / "Website/headers.txt", output / "_headers")
    print("Built static site; canonical policy SHA-256: " + hashlib.sha256(text.encode()).hexdigest())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "Website/public")
    build(parser.parse_args().output)
