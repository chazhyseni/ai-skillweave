"""Exercise installed hooks with Claude payloads, including learning evidence gates."""
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
RULE = ("When revising behavior across several execution paths, "
        "never use unverified assumptions instead of checking every affected output.")


class HookTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="skillweave hooks ")
        self.addCleanup(temporary.cleanup)
        self.home = Path(temporary.name)
        self.project = self.home / "project"
        self.project.mkdir()
        self.env = {**os.environ, "HOME": str(self.home), "PYTHONDONTWRITEBYTECODE": "1"}
        self.settings = self.home / ".claude/settings.json"
        self.install()

    def install(self):
        result = subprocess.run(["bash", str(REPO / "scripts/setup-learning-hook.sh")],
                                env=self.env, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def invoke(self, event, session="session-1", **fields):
        payload = {"hook_event_name": event, "session_id": session,
                   "cwd": str(self.project), **fields}
        groups = json.loads(self.settings.read_text())["hooks"][event]
        command = groups[-1]["hooks"][0]["command"]
        return subprocess.run(shlex.split(command), input=json.dumps(payload),
                              env=self.env, cwd=self.home, capture_output=True,
                              text=True, timeout=10)

    def configure_codesight(self):
        (self.project / ".codesight").mkdir()
        (self.home / ".claude.json").write_text(json.dumps({"mcpServers": {"codesight": {}}}))

    def events(self):
        return [json.loads(line) for path in (self.home / ".claude/skills/learned/events").rglob("*.jsonl")
                for line in path.read_text().splitlines()]

    def test_capture_preserves_content_and_same_session_messages_privately(self):
        prompt = 'When handling "quoted" data, never drop tabs\tand Unicode λ.\nKeep newlines.'
        for _ in range(2):
            result = self.invoke("UserPromptSubmit", session="../../escaped", prompt=prompt)
            self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "", ""))
        events = self.events()
        self.assertEqual([e["message"]["content"] for e in events], [prompt, prompt])
        self.assertEqual(events[0]["sessionId"], "../../escaped")
        self.assertEqual(events[0]["skillweave_capture"], "correction")
        for path in (self.home / ".claude/skills/learned/events").rglob("*.jsonl"):
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertFalse((self.home / "escaped").exists())

    def test_ordinary_prompt_does_not_create_learning_state(self):
        result = self.invoke("UserPromptSubmit", prompt="Tell me a joke about a penguin.")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.home / ".claude/skills").exists())

    def test_guard_uses_payload_cwd_and_stderr_and_cleans_only_own_session(self):
        self.configure_codesight()
        fields = {"tool_name": "Glob", "tool_input": {"pattern": "**/*.py"}}
        first = self.invoke("PreToolUse", **fields)
        self.assertEqual(first.returncode, 2)
        self.assertEqual(first.stdout, "")
        self.assertIn("codesight_get_summary", first.stderr)
        self.assertEqual(self.invoke("PreToolUse", **fields).returncode, 0)
        self.assertEqual(self.invoke("PreToolUse", session="other", **fields).returncode, 2)
        self.assertEqual(self.invoke("SessionEnd", reason="other").returncode, 0)
        self.assertEqual(self.invoke("PreToolUse", session="other", **fields).returncode, 0)
        self.assertEqual(self.invoke("PreToolUse", **fields).returncode, 2)

    def test_successful_summary_avoids_reminder_but_error_does_not(self):
        self.configure_codesight()
        fields = {"tool_name": "mcp__codesight__codesight_get_summary", "tool_input": {}}
        self.invoke("PostToolUse", tool_response={"isError": False}, **fields)
        glob = {"tool_name": "Glob", "tool_input": {"pattern": "**/*.py"}}
        self.assertEqual(self.invoke("PreToolUse", **glob).returncode, 0)
        self.invoke("PostToolUse", session="failed", tool_response={"isError": True}, **fields)
        self.assertEqual(self.invoke("PreToolUse", session="failed", **glob).returncode, 2)

    def test_index_without_registered_server_does_not_block(self):
        (self.project / ".codesight").mkdir()
        result = self.invoke("PreToolUse", tool_name="Glob", tool_input={"pattern": "**/*"})
        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "", ""))

    def test_symlinked_capture_destination_is_not_followed(self):
        outside = self.home / "outside"
        outside.mkdir()
        learned = self.home / ".claude/skills/learned"
        learned.mkdir(parents=True)
        (learned / "events").symlink_to(outside, target_is_directory=True)
        result = self.invoke("UserPromptSubmit", prompt=RULE)
        self.assertEqual(result.returncode, 1)
        self.assertIn("symlinked", result.stderr)
        self.assertEqual(list(outside.iterdir()), [])

    def test_upgrade_migrates_registration_and_preserves_unrelated_and_edited_hooks(self):
        settings = json.loads(self.settings.read_text())
        custom = {"type": "command", "command": "printf custom"}
        settings["hooks"]["UserPromptSubmit"] = [{"matcher": "*", "hooks": [custom, {
            "type": "command", "command": shlex.quote(str(REPO / "hooks/learning-capture.sh"))}]}]
        self.settings.write_text(json.dumps(settings))
        target = self.home / ".claude/hooks/learning-capture.sh"
        old = b"#!/bin/bash\necho older-managed-version\n"
        target.write_bytes(old)
        manifest = target.parent / ".skillweave-manifest.json"
        ownership = json.loads(manifest.read_text())
        ownership[target.name] = hashlib.sha256(old).hexdigest()
        manifest.write_text(json.dumps(ownership))
        self.install()
        self.assertEqual(target.read_bytes(), (REPO / "hooks/learning-capture.sh").read_bytes())
        before = self.settings.read_bytes()
        self.install()
        self.assertEqual(self.settings.read_bytes(), before)
        groups = json.loads(before)["hooks"]["UserPromptSubmit"]
        self.assertEqual(groups[0]["hooks"], [custom])
        self.assertNotIn("matcher", groups[1])
        target.write_text("#!/bin/bash\necho personal-hook\n")
        result = self.install()
        self.assertIn("custom files preserved", result.stderr)
        self.assertIn("personal-hook", target.read_text())
        self.assertEqual(self.settings.read_bytes(), before)

    def extract(self):
        result = subprocess.run([sys.executable, str(REPO / "extract-conversation-skills.py"),
                                 "--harness", "claude", "--no-llm"], env=self.env,
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_capture_and_history_share_evidence_identity_then_repeated_rule_becomes_skill(self):
        for _ in range(12):
            self.invoke("UserPromptSubmit", prompt=RULE)
        history = self.home / ".claude/projects/project"
        history.mkdir(parents=True)
        (history / "session-1.jsonl").write_text(json.dumps(self.events()[0]) + "\n")
        result = self.extract()
        self.assertIn("corrections: 1", result.stdout)
        self.assertEqual(list((self.home / ".claude/skills/learned").glob("*.md")), [])
        for index in range(2, 13):
            self.invoke("UserPromptSubmit", session=f"session-{index}", prompt=RULE)
        result = self.extract()
        self.assertIn("corrections: 12", result.stdout)
        skills = list((self.home / ".claude/skills/learned").glob("*.md"))
        self.assertEqual(len(skills), 1)
        self.assertIn("When revising behavior across several execution paths.", skills[0].read_text())
        self.assertIn("never use unverified assumptions instead of checking every affected output.", skills[0].read_text())


if __name__ == "__main__":
    unittest.main()
