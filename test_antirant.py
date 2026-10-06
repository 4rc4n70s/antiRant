"""Autoverificación offline de la composición del prompt: python3 -m unittest test_antirant -v"""
import importlib.machinery
import importlib.util
import os
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
loader = importlib.machinery.SourceFileLoader("antirant_mod", str(HERE / "antirant"))
spec = importlib.util.spec_from_loader("antirant_mod", loader)
ar = importlib.util.module_from_spec(spec)
loader.exec_module(ar)

MEMORY = """# tetsu
## Vocabulario
- Hyprland = hiperland
- Omarchy
plain line

## Alias
- el chat = WhatsApp
"""


class PromptComposition(unittest.TestCase):
    base = (HERE / "prompt.md").read_text()

    def memfile(self, text=MEMORY):
        p = Path(tempfile.mkdtemp()) / "tetsu.md"
        p.write_text(text, encoding="utf-8")
        return p

    def test_default_is_unchanged(self):
        self.assertEqual(ar.build_prompt(self.base), self.base)
        self.assertEqual(ar.build_prompt(self.base, True), self.base + ar.JSON_ADDENDUM)

    def test_vocabulary_is_appended(self):
        vocab = ar.read_vocabulary(self.memfile())
        self.assertEqual(vocab.splitlines(), ["- Hyprland = hiperland", "- Omarchy", "- plain line"])
        prompt = ar.build_prompt(self.base, True, vocab)
        self.assertTrue(prompt.startswith(self.base + ar.JSON_ADDENDUM))
        self.assertIn("Hyprland = hiperland", prompt)
        self.assertIn("No agregues ninguna que no aparezca", prompt)
        self.assertNotIn("WhatsApp", prompt)  # other sections never leave

    def test_missing_file_or_section(self):
        self.assertEqual(ar.read_vocabulary("/nonexistent/tetsu.md"), "")
        self.assertEqual(ar.read_vocabulary(self.memfile("## Alias\n- a = b\n")), "")
        self.assertEqual(ar.build_prompt(self.base, False, ""), self.base)

    def test_context_path(self):
        os.environ.pop("ANTIRANT_CONTEXT", None)
        self.assertIsNone(ar.context_path(["--json"]))
        self.assertEqual(ar.context_path(["--json", "--context", "/x.md"]), "/x.md")
        self.assertEqual(ar.context_path(["--context=/y.md"]), "/y.md")
        os.environ["ANTIRANT_CONTEXT"] = "/z.md"
        try:
            self.assertEqual(ar.context_path([]), "/z.md")
        finally:
            del os.environ["ANTIRANT_CONTEXT"]


if __name__ == "__main__":
    unittest.main()


class MultilineCommentTest(unittest.TestCase):
    def test_examples_inside_comments_are_ignored(self):
        import tempfile
        md = ("## Vocabulario\n<!-- Ejemplos:\n- Hyprland = hiperland\n-->\n- Tetsu\n"
              "## Alias\n- el chat = WhatsApp\n")
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as f:
            f.write(md)
        self.assertEqual(ar.read_vocabulary(f.name), "- Tetsu")
