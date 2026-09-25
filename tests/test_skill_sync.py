"""Consumer-visible propagation invariants; isolated HOME and local Git remotes."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
ENGINE = REPO / "scripts/skill_sync.py"
HARNESSES = {
    "claude": ".claude/skills",
    "codex": ".agents/skills",
    "openclaw": ".openclaw/workspace/skills",
    "pi": ".pi/agent/skills",
    "copilot": ".copilot/skills",
    "hermes": ".hermes/skills/ai-skillweave",
    "omp": ".omp/agent/skills",
}


def snapshot(root):
    result = {}
    for path in root.rglob("*"):
        rel = str(path.relative_to(root))
        if path.is_symlink():
            result[rel] = ("link", os.readlink(path))
        elif path.is_file():
            result[rel] = ("file", hashlib.sha256(path.read_bytes()).hexdigest(),
                           stat.S_IMODE(path.stat().st_mode), path.stat().st_mtime_ns)
        else:
            result[rel] = ("dir",)
    return result


class SkillSyncTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="skillweave-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.home = self.root / "home with spaces"
        self.home.mkdir()
        self.env = {**os.environ, "HOME": str(self.home), "PYTHONDONTWRITEBYTECODE": "1",
                    "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull,
                    "GIT_ALLOW_PROTOCOL": "file"}
        self.env.pop("SKILLWEAVE_OMP_AGENT_DIR", None)
        for key in ("OMP_PROFILE", "PI_PROFILE", "PI_CONFIG_DIR", "PI_CODING_AGENT_DIR", "XDG_DATA_HOME"):
            self.env.pop(key, None)
        self.source = self.home / ".claude-everything-claude-code/skills"
        self.source.mkdir(parents=True)
        self.all_harnesses = [arg for name in HARNESSES for arg in ("--harness", name)]
        # Unrelated propagation tests use only their local source fixtures.
        preferences = self.home / ".claude/skills-cache/source-preferences.json"
        preferences.parent.mkdir(parents=True, exist_ok=True)
        preferences.write_text(json.dumps({"research_defaults": True, "enabled": {
            source: False for source in ("aws-hcls", "openai-life-sciences", "stjude-cab")
        }}))

    def skill(self, root, name="example", body="Use measured evidence."):
        directory = root / name
        directory.mkdir(parents=True, exist_ok=True)
        (directory / "SKILL.md").write_text(
            f"---\nname: {name}\ndescription: Validate evidence for reproducible analysis.\n---\n\n{body}\n")
        return directory

    def run_sync(self, *args, expected=0):
        command = [sys.executable, str(ENGINE), *args]
        result = subprocess.run(command, env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def offline(self, *args, expected=0):
        return self.run_sync("--offline", *self.all_harnesses, *args, expected=expected)

    def test_updates_assets_modes_deletions_and_preserves_personal_files(self):
        source = self.skill(self.source)
        scripts = source / "scripts"
        scripts.mkdir()
        executable = scripts / "run.sh"
        executable.write_text("#!/bin/sh\nprintf old\\n\n")
        executable.chmod(0o755)
        (source / "obsolete.txt").write_text("old reference")
        self.offline()
        for relative in HARNESSES.values():
            target = self.home / relative / "example"
            self.assertEqual((target / "scripts/run.sh").read_bytes(), executable.read_bytes())
            self.assertEqual(stat.S_IMODE((target / "scripts/run.sh").stat().st_mode), 0o755)
            (target / "personal.txt").write_text("keep my notes")
        self.skill(self.source, body="Use updated evidence.")
        executable.write_text("#!/bin/sh\nprintf new\\n\n")
        (source / "obsolete.txt").unlink()
        self.offline()
        for relative in HARNESSES.values():
            target = self.home / relative / "example"
            self.assertIn("updated evidence", (target / "SKILL.md").read_text())
            self.assertEqual((target / "scripts/run.sh").read_bytes(), executable.read_bytes())
            self.assertFalse((target / "obsolete.txt").exists())
        shutil.rmtree(source)
        self.offline()
        for relative in HARNESSES.values():
            target = self.home / relative / "example"
            self.assertFalse((target / "SKILL.md").exists())
            self.assertEqual((target / "personal.txt").read_text(), "keep my notes")

    def test_edited_managed_and_unowned_skills_are_not_overwritten(self):
        self.skill(self.source)
        custom = self.home / HARNESSES["pi"] / "example"
        custom.mkdir(parents=True)
        (custom / "SKILL.md").write_text("My independent skill")
        self.offline(expected=1)
        self.assertEqual((custom / "SKILL.md").read_text(), "My independent skill")
        managed = self.home / HARNESSES["omp"] / "example/SKILL.md"
        managed.write_text("My edited managed skill")
        self.skill(self.source, body="New upstream text")
        self.offline(expected=1)
        self.assertEqual(managed.read_text(), "My edited managed skill")
        self.assertIn("New upstream text", (self.home / HARNESSES["claude"] / "example/SKILL.md").read_text())

    def test_no_prune_keeps_ownership_for_later_removal(self):
        source = self.skill(self.source)
        self.offline()
        shutil.rmtree(source)
        self.offline("--no-prune")
        for relative in HARNESSES.values():
            self.assertTrue((self.home / relative / "example/SKILL.md").exists())
        self.offline()
        for relative in HARNESSES.values():
            self.assertFalse((self.home / relative / "example/SKILL.md").exists())

    def test_learned_archive_removes_only_delivered_copy(self):
        learned = self.home / ".claude/skills/learned"
        learned.mkdir(parents=True)
        source = self.skill(self.source, name="learned-pattern")
        text = (source / "SKILL.md").read_text()
        shutil.rmtree(source)
        (learned / "learned-pattern.md").write_text(text)
        self.offline()
        for relative in HARNESSES.values():
            self.assertIn("measured evidence", (self.home / relative / "learned-pattern/SKILL.md").read_text())
        archive = learned / "archived"
        archive.mkdir()
        (learned / "learned-pattern.md").rename(archive / "learned-pattern.md")
        self.offline()
        self.assertEqual((archive / "learned-pattern.md").read_text(), text)
        for relative in HARNESSES.values():
            self.assertFalse((self.home / relative / "learned-pattern/SKILL.md").exists())

    def test_preview_never_changes_home(self):
        self.skill(self.source)
        before = snapshot(self.home)
        self.offline("--dry-run")
        self.assertEqual(snapshot(self.home), before)
        self.offline("--check")
        self.assertEqual(snapshot(self.home), before)
        self.offline()
        self.skill(self.source, body="Updated after initial synchronization")
        before = snapshot(self.home)
        self.offline("--dry-run")
        self.assertEqual(snapshot(self.home), before)

    def test_disabled_source_stays_disabled(self):
        science = self.home / ".claude-scientific-skills/skills"
        self.skill(science, name="science-example")
        self.offline()
        self.offline("--without-science")
        self.offline()
        for relative in HARNESSES.values():
            self.assertFalse((self.home / relative / "science-example/SKILL.md").exists())
        self.assertTrue((science / "science-example/SKILL.md").exists())

    def test_identical_legacy_copy_is_adopted_and_missing_assets_are_added(self):
        source = self.skill(self.source)
        target = self.home / HARNESSES["omp"] / "example"
        target.mkdir(parents=True)
        shutil.copy2(source / "SKILL.md", target / "SKILL.md")
        (source / "helper.txt").write_text("required resource")
        self.offline()
        self.assertEqual((target / "helper.txt").read_text(), "required resource")
        self.skill(self.source, body="Revision after ownership migration")
        self.offline()
        self.assertIn("Revision after ownership migration", (target / "SKILL.md").read_text())

    def test_conflict_recovery_backs_up_complete_skill_and_preview_is_read_only(self):
        source = self.skill(self.source)
        self.offline()
        target = self.home / HARNESSES["omp"] / "example"
        (target / "SKILL.md").write_text("personal edits")
        (target / "notes.txt").write_text("keep private notes")
        (source / "helper.txt").write_text("new helper")
        before = snapshot(self.home)
        self.offline("--repair-conflicts", "--dry-run")
        self.assertEqual(snapshot(self.home), before)
        self.offline("--repair-conflicts")
        backup = list((target.parent.parent / "skillweave-backups").glob("*/example"))
        self.assertEqual(len(backup), 1)
        self.assertEqual((backup[0] / "SKILL.md").read_text(), "personal edits")
        self.assertEqual((backup[0] / "notes.txt").read_text(), "keep private notes")
        self.assertEqual((target / "helper.txt").read_text(), "new helper")
        self.offline()
        self.assertEqual(len(list((target.parent.parent / "skillweave-backups").iterdir())), 1)

    def test_conflicting_asset_prevents_partial_skill_update(self):
        source = self.skill(self.source)
        (source / "run.sh").write_text("old program")
        self.offline()
        target = self.home / HARNESSES["omp"] / "example"
        previous = (target / "SKILL.md").read_bytes()
        (target / "run.sh").write_text("locally modified program")
        self.skill(self.source, body="Instructions for the new program")
        (source / "run.sh").write_text("new program")
        self.offline(expected=1)
        self.assertEqual((target / "SKILL.md").read_bytes(), previous)
        self.assertEqual((target / "run.sh").read_text(), "locally modified program")

    def test_declared_names_control_priority_and_legacy_alias_recovery(self):
        science = self.home / ".claude-scientific-skills/skills"
        low = self.skill(self.source, name="canonical")
        low.rename(self.source / "old-folder")
        self.skill(science, name="canonical", body="Lower priority science")
        # ECC wins even though its directory name differs; OMP names come from YAML.
        target = self.home / HARNESSES["omp"]
        legacy = target / "old-folder"
        legacy.mkdir(parents=True)
        shutil.copy2(self.source / "old-folder/SKILL.md", legacy / "SKILL.md")
        before = snapshot(self.home)
        self.offline("--dry-run")
        self.assertEqual(snapshot(self.home), before)
        self.offline()
        self.assertFalse(legacy.exists())
        self.assertIn("measured evidence", (target / "canonical/SKILL.md").read_text())
        self.assertEqual(list(target.glob("*/SKILL.md")), [target / "canonical/SKILL.md"])
        self.assertTrue(list((target.parent / "skillweave-backups").glob("*/old-folder/SKILL.md")))

    def test_legacy_migration_is_per_skill_and_preserves_backups_on_incremental_updates(self):
        self.skill(self.source, "first", "First current instructions")
        self.skill(self.source, "second", "Second current instructions")
        target = self.home / HARNESSES["omp"]
        legacy = self.skill(target, "second", "Old instructions with personal changes")
        (legacy / "notes.txt").write_text("Personal notes")
        # Its old directory happens to be another desired skill's canonical name.
        legacy.rename(target / "first")
        self.skill(target, "personal-only", "Unrelated personal workflow")
        self.offline()
        self.assertIn("First current", (target / "first/SKILL.md").read_text())
        self.assertIn("Second current", (target / "second/SKILL.md").read_text())
        backups = list((target.parent / "skillweave-backups").glob("*/first"))
        self.assertEqual(len(backups), 1)
        self.assertIn("personal changes", (backups[0] / "SKILL.md").read_text())
        self.assertEqual((backups[0] / "notes.txt").read_text(), "Personal notes")
        self.assertIn("Unrelated personal", (target / "personal-only/SKILL.md").read_text())
        self.skill(self.source, "first", "Incremental revision")
        self.offline()
        self.assertIn("Incremental revision", (target / "first/SKILL.md").read_text())
        self.assertEqual(list((target.parent / "skillweave-backups").glob("*/first")), backups)
        (target / "first/SKILL.md").write_text("Later personal edit")
        self.offline(expected=1)
        self.assertEqual((target / "first/SKILL.md").read_text(), "Later personal edit")

    def test_learning_inputs_survive_legacy_descriptor_migration_and_second_sync(self):
        source = self.skill(self.source)
        learned = self.home / ".claude/skills/learned"
        learned.mkdir(parents=True)
        shutil.copy2(source / "SKILL.md", learned / "SKILL.md")
        rule = self.skill(self.root / "personal-input", "personal-rule", "Retain this learned rule")
        shutil.copy2(rule / "SKILL.md", learned / "personal-rule.md")
        (learned / "events").mkdir()
        (learned / "events/private.json").write_text('{"message":"private correction"}')
        nested = self.skill(learned / "saved-input", "example", "Preserve nested learning input")
        self.offline()
        self.offline()
        self.assertEqual((learned / "personal-rule.md").read_bytes(), (rule / "SKILL.md").read_bytes())
        self.assertEqual((learned / "events/private.json").read_text(), '{"message":"private correction"}')
        self.assertFalse((learned / "SKILL.md").exists())
        self.assertTrue(list((self.home / ".claude/skillweave-backups").glob("SKILL.md-*/SKILL.md")))
        self.assertIn("Preserve nested learning input", (nested / "SKILL.md").read_text())
        for relative in HARNESSES.values():
            self.assertIn("Retain this learned rule", (self.home / relative / "personal-rule/SKILL.md").read_text())

    def test_nested_legacy_category_migrates_and_backups_stay_outside_native_discovery(self):
        self.skill(self.source, "category", "New category skill")
        self.skill(self.source, "child", "Current child")
        target = self.home / HARNESSES["hermes"]
        self.skill(target / "category", "child", "Legacy child")
        (target / "category/notes.txt").write_text("Keep category notes")
        self.skill(self.home / ".hermes/skills/skillweave-backups/previous", "old-backup")
        before = snapshot(self.home)
        self.offline("--dry-run")
        self.assertEqual(snapshot(self.home), before)
        self.offline()
        self.assertIn("New category", (target / "category/SKILL.md").read_text())
        self.assertIn("Current child", (target / "child/SKILL.md").read_text())
        self.assertFalse((target / "category/child").exists())
        self.assertFalse((self.home / ".hermes/skills/skillweave-backups").exists())
        backups = self.home / ".hermes/skillweave-backups"
        self.assertEqual(next(backups.glob("*/category/notes.txt")).read_text(), "Keep category notes")
        self.assertIn("Legacy child", next(backups.glob("*/child/SKILL.md")).read_text())
        self.assertTrue(list(backups.glob("*/skillweave-backups/previous/old-backup/SKILL.md")))

    def test_curated_research_sources_preserve_resources_licenses_and_bioskills(self):
        (self.home / ".claude/skills-cache/source-preferences.json").unlink()
        selection = self.run_sync("--list-sources")
        for source in ("aws-hcls", "openai-life-sciences", "stjude-cab"):
            self.assertIn(f"{source}\tenabled\t", selection.stdout)
        self.skill(self.home / ".claude/skills-cache/bioskills-src", "bio-reference")
        aws = self.skill(self.home / ".claude-aws-hcls-skills/skills", "genomics-qc")
        (aws / "workflow.py").write_text("print('QC')")
        openai = self.home / ".claude-openai-life-sciences"
        self.skill(openai / "plugins/life-science-research/skills", "evidence-query")
        self.skill(openai / "plugins/unrelated/skills", "not-selected")
        cab = self.home / ".claude-stjude-cab-skills"
        plot = self.skill(cab, "custom-ES-plot-GSEApy")
        (plot / "plot.py").write_text("print('GSEA')")
        (cab / "LICENSE.txt").write_text("CC BY-NC-SA 4.0")
        (cab / "AUTHORS.md").write_text("Upstream attribution")
        annotation = self.skill(cab, "genomic-regions-annotation")
        (annotation / "reference.bed").symlink_to(self.root / "institution-only.bed")
        # Upgrade the old installer's cached false defaults without selection flags.
        (self.home / ".claude/skills-cache/source-preferences.json").write_text(json.dumps({
            "enabled": {source: False for source in ("aws-hcls", "openai-life-sciences", "stjude-cab")}
        }))
        self.offline()
        target = self.home / HARNESSES["omp"]
        self.assertEqual((target / "genomics-qc/workflow.py").read_text(), "print('QC')")
        self.assertTrue((target / "evidence-query/SKILL.md").is_file())
        self.assertTrue((target / "bio-reference/SKILL.md").is_file())
        self.assertFalse((target / "not-selected").exists())
        self.assertFalse((target / "genomic-regions-annotation").exists())
        self.assertIn("name: custom-es-plot-gseapy", (target / "custom-es-plot-gseapy/SKILL.md").read_text())
        self.assertEqual((target / "custom-es-plot-gseapy/plot.py").read_text(), "print('GSEA')")
        self.assertEqual((target / "custom-es-plot-gseapy/UPSTREAM-LICENSE.txt").read_text(), "CC BY-NC-SA 4.0")
        self.assertEqual((target / "custom-es-plot-gseapy/UPSTREAM-AUTHORS.md").read_text(), "Upstream attribution")
        self.assertIn("name: custom-ES-plot-GSEApy", (plot / "SKILL.md").read_text())
        self.offline("--without-source", "aws-hcls", "--without-source", "openai-life-sciences",
                     "--without-source", "stjude-cab")
        self.offline()
        for name in ("genomics-qc", "evidence-query", "custom-es-plot-gseapy"):
            self.assertFalse((target / name).exists())
        self.assertTrue((target / "bio-reference/SKILL.md").is_file())

    def test_active_omp_profile_controls_model_and_skill_destination(self):
        self.skill(self.source)
        self.env["OMP_PROFILE"] = "research"
        self.env["PI_CODING_AGENT_DIR"] = str(self.home / "unrelated-agent")
        self.run_sync("--offline", "--harness", "omp")
        agent = self.home / ".omp/profiles/research/agent"
        self.assertTrue((agent / "skills/example/SKILL.md").is_file())
        result = subprocess.run([sys.executable, str(REPO / "scripts/setup_model_backend.py"),
                                 "omp", "--backend", "llama.cpp", "--model", "research-local"],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((agent / "models.yml").is_file())
        self.assertFalse((self.home / ".omp/agent/models.yml").exists())
        self.assertFalse((self.home / "unrelated-agent").exists())

    def git(self, cwd, *args):
        result = subprocess.run(["git", "-C", str(cwd), *args], env=self.env,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout.strip()

    def make_source_repo(self, name, destination):
        work = self.root / (name + "-work")
        work.mkdir()
        self.git(work, "init", "--initial-branch=main")
        self.git(work, "config", "user.name", "chazhyseni")
        self.git(work, "config", "user.email", "chaz.hyseni@gmail.com")
        self.skill(work / "skills", name=name)
        self.git(work, "add", ".")
        self.git(work, "commit", "-m", "Initial fixture")
        remote = self.root / (name + ".git")
        self.git(self.root, "clone", "--bare", str(work), str(remote))
        self.git(self.root, "clone", str(remote), str(destination))
        self.git(work, "remote", "add", "origin", str(remote))
        return work

    def test_checks_are_read_only_and_other_sources_update_when_ecc_unchanged(self):
        shutil.rmtree(self.source.parent)
        self.make_source_repo("ecc-example", self.source.parent)
        science_checkout = self.home / ".claude-scientific-skills"
        science_work = self.make_source_repo("science-example", science_checkout)
        self.run_sync(*self.all_harnesses)
        self.skill(science_work / "skills", name="science-example", body="New remote science revision")
        self.git(science_work, "add", ".")
        self.git(science_work, "commit", "-m", "Update science fixture")
        self.git(science_work, "push", "origin", "main")
        before = snapshot(self.home)
        check = self.run_sync("--check", *self.all_harnesses)
        self.assertIn("UPDATE AVAILABLE", check.stdout)
        self.assertEqual(snapshot(self.home), before)
        self.run_sync(*self.all_harnesses)
        for relative in HARNESSES.values():
            self.assertIn("New remote science revision",
                          (self.home / relative / "science-example/SKILL.md").read_text())
        dirty = science_checkout / "skills/science-example/SKILL.md"
        dirty.write_text("Local edit must survive")
        self.run_sync(*self.all_harnesses, expected=1)
        self.assertEqual(dirty.read_text(), "Local edit must survive")

    def recovery_remote(self, remote):
        config = self.home / ".gitconfig"
        self.git(self.root, "config", "--file", str(config),
                 f"url.{remote.as_uri()}.insteadOf", "https://github.com/affaan-m/ECC.git")
        self.env["GIT_CONFIG_GLOBAL"] = str(config)

    def test_install_uses_legacy_and_dirty_sources_without_overwriting_or_network(self):
        self.skill(self.source, body="Legacy source content")
        science = self.home / ".claude-scientific-skills"
        self.make_source_repo("science-example", science)
        self.skill(science / "skills", name="science-example", body="Personal science content")
        before_legacy, before_dirty = snapshot(self.source.parent), snapshot(science)
        self.run_sync("--install", "--harness", "omp")
        delivered = self.home / HARNESSES["omp"]
        self.assertIn("Legacy source content", (delivered / "example/SKILL.md").read_text())
        self.assertIn("Personal science content", (delivered / "science-example/SKILL.md").read_text())
        self.assertEqual(snapshot(self.source.parent), before_legacy)
        self.assertEqual(snapshot(science), before_dirty)
        self.assertFalse((self.home / "skillweave-source-backups").exists())

    def test_source_snapshot_recovery_is_previewable_and_preserves_every_file(self):
        self.make_source_repo("upstream", self.root / "pristine")
        self.recovery_remote(self.root / "upstream.git")
        self.skill(self.source, body="Personal snapshot")
        (self.source.parent / "notes.txt").write_text("Personal source notes")
        before = snapshot(self.source.parent)
        home_before = snapshot(self.home)
        self.run_sync("--repair-sources", "--dry-run", "--harness", "omp")
        self.assertEqual(snapshot(self.home), home_before)
        self.run_sync("--repair-sources", "--harness", "omp")
        backups = list((self.home / "skillweave-source-backups").glob("*/*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(snapshot(backups[0]), before)
        self.assertTrue((self.source.parent / ".git").is_dir())
        self.assertTrue((self.home / HARNESSES["omp"] / "upstream/SKILL.md").is_file())
        self.assertFalse((self.source.parent / "notes.txt").exists())
        self.run_sync("--repair-sources", "--harness", "omp")
        self.assertEqual(list((self.home / "skillweave-source-backups").glob("*/*")), backups)

    def test_dirty_source_recovery_preserves_git_history_ignored_and_untracked_files(self):
        shutil.rmtree(self.source.parent)
        self.make_source_repo("upstream", self.source.parent)
        self.recovery_remote(self.root / "upstream.git")
        self.skill(self.source, name="upstream", body="Uncommitted personal change")
        (self.source.parent / "notes.txt").write_text("Untracked personal notes")
        (self.source.parent / ".git/info/exclude").write_text("ignored.txt\n")
        (self.source.parent / "ignored.txt").write_text("Ignored personal notes")
        before = snapshot(self.source.parent)
        self.run_sync("--repair-sources", "--harness", "omp")
        backup = next((self.home / "skillweave-source-backups").glob("*/*"))
        self.assertEqual(snapshot(backup), before)
        self.assertIn("measured evidence", (self.source / "upstream/SKILL.md").read_text())
        self.assertIn("Uncommitted personal", (backup / "skills/upstream/SKILL.md").read_text())

    def test_failed_source_clone_leaves_original_in_place_without_backup(self):
        self.skill(self.source, body="Original snapshot")
        before = snapshot(self.source.parent)
        self.recovery_remote(self.root / "nonexistent.git")
        self.run_sync("--repair-sources", "--harness", "omp", expected=1)
        self.assertEqual(snapshot(self.source.parent), before)
        self.assertFalse((self.home / "skillweave-source-backups").exists())
        self.assertFalse(list(self.home.glob(".skillweave-clone-*")))

    def test_source_repair_rejects_offline_uninstall_and_target_only_before_writes(self):
        before = snapshot(self.home)
        for args in (("--offline",), ("--uninstall",), ("--only", "omp")):
            result = subprocess.run(["bash", str(REPO / "install.sh"), "--repair-sources", *args],
                                    env=self.env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(snapshot(self.home), before)

    def test_bionemo_uses_published_bundle_and_supports_older_layout(self):
        checkout = self.home / ".claude-bionemo-skills"
        bundle = checkout / "skills/bionemo-agent-toolkit/skills"
        self.skill(checkout / "nim-skills", name="example", body="Original layout")
        self.skill(bundle, name="example", body="Published bundle")
        self.run_sync("--offline", "--without-ecc", "--harness", "omp")
        delivered = self.home / HARNESSES["omp"] / "example/SKILL.md"
        self.assertIn("Published bundle", delivered.read_text())
        shutil.rmtree(bundle)
        self.run_sync("--offline", "--without-ecc", "--harness", "omp")
        self.assertIn("Original layout", delivered.read_text())


if __name__ == "__main__":
    unittest.main()
