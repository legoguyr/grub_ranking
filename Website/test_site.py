"""Public-output and canonical-policy regression checks; no live services."""
from html.parser import HTMLParser
from pathlib import Path
import tempfile
import unittest
from urllib.parse import urlparse

from build import build, POLICY, LOGO


class Document(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.tags = []
        self.article_text = []
        self.in_policy = False
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        self.tags.append((tag, attrs))
        if tag == "article" and attrs.get("class") == "policy":
            self.in_policy = True

    def handle_endtag(self, tag):
        if tag == "article":
            self.in_policy = False

    def handle_data(self, data):
        if self.in_policy:
            self.article_text.append(data)


class SiteTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.output = Path(self.temp.name)
        build(self.output)

    def test_publish_directory_is_an_exact_public_allowlist(self):
        self.assertEqual({str(p.relative_to(self.output)) for p in self.output.rglob("*") if p.is_file()},
            {"index.html", "privacy.html", "support.html", "404.html", "assets/site.css", "assets/wordmark.png", "_headers"})
        self.assertEqual((self.output / "assets/wordmark.png").read_bytes(), LOGO.read_bytes())

    def test_policy_is_rendered_from_the_complete_canonical_document(self):
        doc = Document((self.output / "privacy.html").read_text())
        canonical = POLICY.read_text()
        import re
        expected = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", canonical)
        expected = expected.replace("**", "").replace("#", "")
        self.assertEqual(" ".join("".join(doc.article_text).split()), " ".join(expected.split()))
        self.assertIn("October 20, 2026", " ".join(doc.article_text))

    def test_build_refuses_unexpected_files_in_publish_directory(self):
        (self.output / "internal-notes.md").write_text("Synthetic internal fixture")
        with self.assertRaises(ValueError):
            build(self.output)

    def test_links_assets_and_semantic_accessibility(self):
        for name in ["index.html", "privacy.html", "support.html", "404.html"]:
            doc = Document((self.output / name).read_text())
            self.assertEqual(sum(tag == "h1" for tag, _ in doc.tags), 1)
            self.assertIn(("html", {"lang": "en"}), doc.tags)
            self.assertTrue(any(tag == "main" and attrs.get("id") == "main" for tag, attrs in doc.tags))
            self.assertFalse(any(tag in {"script", "iframe", "form"} for tag, _ in doc.tags))
            for tag, attrs in doc.tags:
                if tag == "img":
                    self.assertTrue(attrs.get("alt"))
                for key in ["href", "src"]:
                    value = attrs.get(key, "")
                    if not value or value.startswith("#"):
                        continue
                    url = urlparse(value)
                    if url.scheme == "mailto":
                        self.assertIn(url.path, ["privacy@staygrubby.com", "support@staygrubby.com"])
                    elif url.scheme:
                        self.assertEqual(url.scheme, "https")
                        self.assertEqual(url.netloc, "staygrubby.com")
                    else:
                        path = "index.html" if value == "/" else value.lstrip("/")
                        if "." not in Path(path).name:
                            path += ".html"
                        self.assertTrue((self.output / path).is_file(), value)

    def test_security_headers_and_no_remote_dependencies(self):
        headers = (self.output / "_headers").read_text()
        for directive in ["default-src 'none'", "style-src 'self'", "img-src 'self'",
                          "frame-ancestors 'none'", "form-action 'none'", "base-uri 'none'",
                          "X-Content-Type-Options: nosniff", "Referrer-Policy: no-referrer"]:
            self.assertIn(directive, headers)
        css = (self.output / "assets/site.css").read_text()
        for prohibited in ["@import", "url(", "@font-face"]:
            self.assertNotIn(prohibited, css)
        self.assertIn(":focus-visible", css)
        self.assertIn("max-width: 640px", css)


if __name__ == "__main__":
    unittest.main()
