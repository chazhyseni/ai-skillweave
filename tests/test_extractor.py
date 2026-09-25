"""No-model extraction must preserve explicit rules without sending history away."""
import http.server
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import unittest

REPO = Path(__file__).resolve().parents[1]


class NoModelExtractionTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="skillweave-no-model-")
        self.addCleanup(temporary.cleanup)
        self.home = Path(temporary.name)
        self.source = self.home / "history"
        self.source.mkdir()
        self.output = self.home / "learned"
        self.requests = []
        requests = self.requests

        class RejectInference(http.server.BaseHTTPRequestHandler):
            def do_POST(self):
                requests.append(self.path)
                self.send_error(500, "No inference permitted in this scenario")

            def log_message(self, *args):
                pass

        self.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), RejectInference)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.thread.join)
        self.addCleanup(self.server.shutdown)
        self.env = {key: value for key, value in os.environ.items() if not key.startswith("SKILLWEAVE_LLM_")}
        self.env.update(HOME=str(self.home), PYTHONDONTWRITEBYTECODE="1",
                        SKILLWEAVE_LLM_BASE_URL=f"http://127.0.0.1:{self.server.server_port}")

    def extract_rule(self, rule):
        # Enough independent sessions to pass both evidence and confidence gates.
        for index in range(12):
            (self.source / f"session-{index}.jsonl").write_text(json.dumps({
                "type": "user", "message": {"role": "user", "content": rule},
            }) + "\n")
        result = subprocess.run([
            sys.executable, str(REPO / "extract-conversation-skills.py"),
            "--no-llm", "--input", str(self.source), "--output", str(self.output),
            "--harness", "claude",
        ], env=self.env, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.requests, [], "No-model extraction sent conversation history to a provider")
        self.assertIn("passing: 1", result.stdout)
        return list(self.output.glob("*.md"))

    def test_repeated_conditional_instruction_produces_source_grounded_skill(self):
        files = self.extract_rule(
            "When revising behavior across several execution paths, "
            "never use unverified assumptions instead of checking every affected output."
        )
        self.assertEqual(len(files), 1)
        content = files[0].read_text()
        self.assertIn("When revising behavior across several execution paths.", content)
        self.assertIn("never use unverified assumptions instead of checking every affected output.", content)

    def test_underspecified_correction_is_rejected_instead_of_inventing_context(self):
        files = self.extract_rule(
            "Never use unverified assumptions instead of checking every affected output."
        )
        self.assertEqual(files, [])


if __name__ == "__main__":
    unittest.main()
