#!/usr/bin/env python3
"""
=============================================================================
Conversation History to Skills Extractor
=============================================================================
Analyzes conversation history to identify repeated user preferences,
corrections, and patterns that should be encoded as skills.

Usage:
    python3 extract-conversation-skills.py [OPTIONS]

Options:
    --input DIR         Directory with conversation exports (default: ~/.claude/conversations/)
    --output DIR        Directory to write generated skills (default: ~/.claude/skills/learned/)
    --format FORMAT     Output format: claude|ollama|openclaw|universal (default: claude)
    --dry-run           Show what would be extracted without writing files
    --verbose           Show detailed analysis

=============================================================================
"""

import os
import re
import json
import hashlib
from pathlib import Path
from datetime import datetime
from collections import defaultdict
from typing import Dict, List, Set, Tuple, Optional

# =============================================================================
# Configuration
# =============================================================================

# Support multiple harness conversation locations
CLAUDE_HISTORY_PATHS = [
    Path.home() / ".claude" / "conversations",  # Exported conversations
    Path.home() / ".claude" / "history.jsonl",  # Live history (JSONL format)
    Path.home() / ".claude" / "sessions",       # Session files
]
CODEX_HISTORY_PATHS = [
    Path.home() / ".codex" / "history.jsonl",   # Live history
    Path.home() / ".codex" / "sessions",        # Session files
]
OPENCLAW_HISTORY_PATHS = [
    Path.home() / ".openclaw" / "logs",         # Gateway logs
    Path.home() / ".openclaw" / "agents",       # Agent sessions
]
DEFAULT_OUTPUT_DIR = Path.home() / ".claude" / "skills" / "learned"
SUPPORTED_FORMATS = ["claude", "ollama", "openclaw", "universal"]
SUPPORTED_HARNESSES = ["claude", "codex", "openclaw", "all"]

# Patterns that indicate user preferences or corrections
PREFERENCE_PATTERNS = {
    "correction": [
        r"(?:don't|do not|never)\s+(?:do|say|write|generate)\s+",
        r"(?:stop|avoid|please\s+(?:stop|don't))\s+",
        r"(?:that's\s+)?(?:wrong|incorrect|not\s+what)\s+",
        r"(?:i\s+)?(?:asked|said|told)\s+(?:you|for)\s+",
        r"(?:no|i\s+meant|actually)\s+",
        r"(?:this\s+is\s+)?(?:not\s+)?(?:accurate|correct|right)\s*",
    ],
    "requirement": [
        r"(?:must|should|need\s+to|have\s+to)\s+",
        r"(?:always|never)\s+(?:do|use|include|check)\s+",
        r"(?:require|requirement|mandatory|essential)\s+",
        r"(?:100%|zero\s+tolerance|no\s+tolerance)\s+",
        r"(?:i\s+)?(?:want|need|require)\s+",
    ],
    "praise": [
        r"(?:perfect|exactly|great|good|thanks|thank\s+you)\s*",
        r"(?:this\s+is\s+)?(?:what\s+i\s+)?(?:wanted|needed|was\s+looking\s+for)\s*",
        r"(?:keep\s+doing|continue|this\s+approach)\s+",
    ],
    "accuracy": [
        r"(?:accuracy|accurate|precise|exact|correct)\s+",
        r"(?:verify|verification|fact-check|confirm)\s+",
        r"(?:citation|source|reference|evidence)\s+",
        r"(?:hallucinat|fabricat|invent|made\s+up)\s+",
        r"(?:scientific|research|evidence-based)\s+",
    ],
}

# =============================================================================
# Data Structures
# =============================================================================

class ConversationPattern:
    """Represents a pattern extracted from conversation history."""

    def __init__(self, category: str, topic: str, examples: List[str],
                 frequency: int = 1, last_seen: Optional[datetime] = None):
        self.category = category
        self.topic = topic
        self.examples = examples
        self.frequency = frequency
        self.last_seen = last_seen or datetime.now()
        self.severity = self._calculate_severity()

    def _calculate_severity(self) -> str:
        """Calculate severity based on frequency and language."""
        if self.frequency >= 5:
            return "critical"
        elif self.frequency >= 3:
            return "high"
        elif self.frequency >= 2:
            return "medium"
        return "low"

    def to_skill_rule(self) -> str:
        """Convert pattern to a skill rule."""
        return {
            "category": self.category,
            "topic": self.topic,
            "rule": self._generate_rule(),
            "examples": self.examples[:3],  # Keep top 3 examples
            "severity": self.severity,
            "frequency": self.frequency,
        }

    def _generate_rule(self) -> str:
        """Generate a rule statement from examples."""
        # Simple heuristic: extract the imperative from examples
        for example in self.examples:
            if "don't" in example.lower() or "do not" in example.lower():
                return f"NEVER: {example.strip()}"
            elif "must" in example.lower() or "always" in example.lower():
                return f"ALWAYS: {example.strip()}"
            elif "need" in example.lower() or "require" in example.lower():
                return f"REQUIRE: {example.strip()}"
        return f" guideline: {self.topic}"


class ConversationAnalyzer:
    """Analyzes conversation history to extract patterns."""

    def __init__(self, input_dir: Path, output_dir: Path, output_format: str = "claude"):
        self.input_dir = input_dir
        self.output_dir = output_dir
        self.output_format = output_format
        self.patterns: Dict[str, List[ConversationPattern]] = defaultdict(list)
        self.user_preferences: Dict[str, any] = {}
        self.learned_corrections: List[Dict] = []

    def analyze(self) -> Dict:
        """Run full analysis on conversation history."""
        conversations = self._load_conversations()

        if not conversations:
            print(f"No conversations found in {self.input_dir}")
            return {"patterns": [], "preferences": {}, "corrections": []}

        for conv in conversations:
            self._analyze_conversation(conv)

        self._aggregate_patterns()

        return {
            "patterns": self._patterns_to_dict(),
            "preferences": self.user_preferences,
            "corrections": self.learned_corrections,
        }

    def _load_conversations(self) -> List[Dict]:
        """Load conversations from input directory or JSONL files."""
        conversations = []

        # Handle JSONL file (Claude Code history.jsonl)
        if self.input_dir.is_file() and self.input_dir.suffix == ".jsonl":
            try:
                with open(self.input_dir, "r", encoding="utf-8") as f:
                    for line_num, line in enumerate(f):
                        line = line.strip()
                        if not line:
                            continue
                        try:
                            data = json.loads(line)
                            conversations.append({
                                "path": self.input_dir,
                                "data": data,
                                "timestamp": data.get("timestamp") or datetime.now(),
                                "line": line_num,
                            })
                        except json.JSONDecodeError:
                            continue
            except IOError as e:
                print(f"Warning: Could not load {self.input_dir}: {e}")
            return conversations

        if not self.input_dir.exists():
            return conversations

        # Support multiple formats
        for file_path in self.input_dir.glob("*.json"):
            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    conversations.append({
                        "path": file_path,
                        "data": data,
                        "timestamp": self._extract_timestamp(file_path),
                    })
            except (json.JSONDecodeError, IOError) as e:
                print(f"Warning: Could not load {file_path}: {e}")

        # Also try markdown format
        for file_path in self.input_dir.glob("*.md"):
            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read()
                    conversations.append({
                        "path": file_path,
                        "data": {"content": content},
                        "timestamp": self._extract_timestamp(file_path),
                    })
            except IOError as e:
                print(f"Warning: Could not load {file_path}: {e}")

        # Also try JSONL files in directory
        for file_path in self.input_dir.glob("*.jsonl"):
            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    for line_num, line in enumerate(f):
                        line = line.strip()
                        if not line:
                            continue
                        try:
                            data = json.loads(line)
                            conversations.append({
                                "path": file_path,
                                "data": data,
                                "timestamp": data.get("timestamp") or datetime.now(),
                                "line": line_num,
                            })
                        except json.JSONDecodeError:
                            continue
            except IOError as e:
                print(f"Warning: Could not load {file_path}: {e}")

        return sorted(conversations, key=lambda x: x["timestamp"] or datetime.min)

    def _extract_timestamp(self, file_path: Path) -> Optional[datetime]:
        """Extract timestamp from filename or file metadata."""
        # Try to parse from filename (e.g., 2024-01-15_conversation.json)
        match = re.search(r"(\d{4}-\d{2}-\d{2})", file_path.name)
        if match:
            try:
                return datetime.strptime(match.group(1), "%Y-%m-%d")
            except ValueError:
                pass

        # Fall back to file modification time
        try:
            return datetime.fromtimestamp(file_path.stat().st_mtime)
        except OSError:
            return None

    def _analyze_conversation(self, conv: Dict) -> None:
        """Analyze a single conversation for patterns."""
        content = self._extract_content(conv)

        if not content:
            return

        # Find corrections
        for pattern_type, patterns in PREFERENCE_PATTERNS.items():
            for pattern in patterns:
                matches = re.finditer(pattern, content, re.IGNORECASE | re.MULTILINE)
                for match in matches:
                    # Get context around the match
                    start = max(0, match.start() - 50)
                    end = min(len(content), match.end() + 100)
                    context = content[start:end].strip()

                    self._record_pattern(pattern_type, match.group(), context, conv.get("timestamp"))

    def _extract_content(self, conv: Dict) -> str:
        """Extract text content from conversation data."""
        data = conv.get("data", {})

        # JSON format with messages
        if "messages" in data:
            return "\n".join(
                msg.get("content", "") for msg in data["messages"]
                if isinstance(msg, dict)
            )

        # Raw content
        if "content" in data:
            return data["content"]

        # Try to serialize
        return json.dumps(data) if data else ""

    def _record_pattern(self, pattern_type: str, match: str,
                        context: str, timestamp: Optional[datetime]) -> None:
        """Record a detected pattern."""
        # Categorize the pattern
        category = self._categorize_pattern(pattern_type, context)
        topic = self._extract_topic(context)

        # Find existing pattern or create new
        existing = self._find_similar_pattern(category, topic)

        if existing:
            existing.frequency += 1
            existing.examples.append(context[:200])
            existing.last_seen = timestamp or datetime.now()
        else:
            self.patterns[category].append(ConversationPattern(
                category=category,
                topic=topic,
                examples=[context[:200]],
                frequency=1,
                last_seen=timestamp,
            ))

    def _categorize_pattern(self, pattern_type: str, context: str) -> str:
        """Categorize the pattern based on type and content."""
        context_lower = context.lower()

        if any(word in context_lower for word in PREFERENCE_PATTERNS["accuracy"]):
            return "accuracy"
        elif pattern_type == "correction":
            return "corrections"
        elif pattern_type == "requirement":
            return "requirements"
        elif pattern_type == "praise":
            return "preferences"

        return "other"

    def _extract_topic(self, context: str) -> str:
        """Extract the main topic from context."""
        # Simple keyword extraction
        keywords = {
            "scientific accuracy": ["accuracy", "scientific", "verify", "citation", "source"],
            "code quality": ["code", "test", "lint", "type", "security"],
            "communication": ["concise", "direct", "summary", "explain"],
            "research": ["research", "paper", "study", "evidence", "literature"],
        }

        context_lower = context.lower()
        for topic, words in keywords.items():
            if any(word in context_lower for word in words):
                return topic

        return "general"

    def _find_similar_pattern(self, category: str, topic: str) -> Optional[ConversationPattern]:
        """Find an existing pattern similar to the given one."""
        for pattern in self.patterns.get(category, []):
            if pattern.topic.lower() == topic.lower():
                return pattern
        return None

    def _aggregate_patterns(self) -> None:
        """Aggregate patterns and extract user preferences."""
        for category, patterns in self.patterns.items():
            # Sort by frequency
            patterns.sort(key=lambda p: p.frequency, reverse=True)

            # Extract high-frequency patterns as preferences
            for pattern in patterns:
                if pattern.frequency >= 2 or pattern.severity in ["critical", "high"]:
                    self.user_preferences[pattern.topic] = pattern.to_skill_rule()

                    if pattern.category == "corrections":
                        self.learned_corrections.append({
                            "topic": pattern.topic,
                            "issue": pattern.examples[0][:100] if pattern.examples else "",
                            "frequency": pattern.frequency,
                            "prevention": pattern._generate_rule(),
                        })

    def _patterns_to_dict(self) -> Dict:
        """Convert patterns to dictionary format."""
        result = {}
        for category, patterns in self.patterns.items():
            result[category] = [p.to_skill_rule() for p in patterns]
        return result

    def generate_skills(self, analysis_result: Dict, dry_run: bool = False) -> List[str]:
        """Generate skill files from analysis results."""
        generated_files = []

        # Create output directory
        if not dry_run:
            self.output_dir.mkdir(parents=True, exist_ok=True)

        # Generate skill for each high-priority pattern
        preferences = analysis_result.get("preferences", {})

        for topic, rule_data in preferences.items():
            if rule_data.get("severity") in ["critical", "high"]:
                skill_content = self._generate_skill_content(topic, rule_data)
                file_name = self._slugify(topic) + self._get_file_extension()

                if dry_run:
                    print(f"[DRY RUN] Would create: {file_name}")
                    print(f"  Content preview: {skill_content[:200]}...")
                else:
                    file_path = self.output_dir / file_name
                    with open(file_path, "w", encoding="utf-8") as f:
                        f.write(skill_content)
                    generated_files.append(str(file_path))

        # Generate user preferences file
        prefs_content = self._generate_preferences_file(analysis_result)

        if dry_run:
            print(f"[DRY RUN] Would create: user-preferences.json")
        else:
            prefs_path = self.output_dir.parent / "user-preferences.json" if self.output_dir.parent else Path("user-preferences.json")
            with open(prefs_path, "w", encoding="utf-8") as f:
                f.write(json.dumps(prefs_content, indent=2, default=str))

        return generated_files

    def _generate_skill_content(self, topic: str, rule_data: Dict) -> str:
        """Generate skill file content based on output format."""
        if self.output_format == "claude":
            return self._generate_claude_skill(topic, rule_data)
        elif self.output_format == "ollama":
            return self._generate_ollama_skill(topic, rule_data)
        elif self.output_format == "openclaw":
            return self._generate_openclaw_skill(topic, rule_data)
        else:
            return self._generate_universal_skill(topic, rule_data)

    def _generate_claude_skill(self, topic: str, rule_data: Dict) -> str:
        """Generate Claude Code skill format."""
        slug = self._slugify(topic)
        return f'''---
name: {slug}
description: Auto-generated skill from conversation history: {topic}
origin: conversation-analysis
tags: [learned, {rule_data.get('category', 'general')}]
version: 1.0.0
---

# {topic.title()}

*Auto-generated from conversation history analysis.*

## Priority

{rule_data.get('severity', 'medium').upper()}

## When to Activate

- When working on tasks related to {rule_data.get('topic', 'this area')}
- When the user has previously corrected similar issues
- When quality verification is needed

## Core Rule

{rule_data.get('rule', 'Follow best practices.')}

## Examples from History

'''
        for i, example in enumerate(rule_data.get('examples', [])[:3], 1):
            content += f"### Example {i}\n\n{example}\n\n"

        content += f'''## Related Preferences

- Frequency in history: {rule_data.get('frequency', 1)} occurrences
- Category: {rule_data.get('category', 'general')}
'''
        return content

    def _generate_ollama_skill(self, topic: str, rule_data: Dict) -> str:
        """Generate Ollama YAML skill format."""
        return f'''# Ollama Skill: {topic}
# Auto-generated from conversation history

skill:
  name: {self._slugify(topic)}
  description: "Auto-generated: {topic}"
  priority: {rule_data.get('severity', 'medium')}
  trigger:
    keywords:
      - "{rule_data.get('topic', topic)}"
  system_prompt: |
    {rule_data.get('rule', 'Follow best practices.')}

    Historical context:
    - Observed {rule_data.get('frequency', 1)} times in conversations
    - Category: {rule_data.get('category', 'general')}
'''

    def _generate_openclaw_skill(self, topic: str, rule_data: Dict) -> str:
        """Generate OpenClaw JSON skill format."""
        return json.dumps({
            "name": self._slugify(topic),
            "description": f"Auto-generated: {topic}",
            "priority": rule_data.get("severity", "medium"),
            "trigger": {
                "keywords": [rule_data.get("topic", topic)],
            },
            "injection_mode": "system_prompt",
            "content": {
                "rule": rule_data.get("rule", "Follow best practices."),
                "historical_context": {
                    "frequency": rule_data.get("frequency", 1),
                    "category": rule_data.get("category", "general"),
                },
            },
        }, indent=2)

    def _generate_universal_skill(self, topic: str, rule_data: Dict) -> str:
        """Generate harness-agnostic universal skill format."""
        return f'''# Universal Skill: {topic}
# Format: Markdown (works with any AI agent harness)
# Auto-generated from conversation history

## Metadata

- **Name**: {self._slugify(topic)}
- **Priority**: {rule_data.get('severity', 'medium').upper()}
- **Category**: {rule_data.get('category', 'general')}
- **Observed**: {rule_data.get('frequency', 1)} times

## Rule

{rule_data.get('rule', 'Follow best practices.')}

## Activation Triggers

Activate this skill when:
- Working on: {rule_data.get('topic', 'related tasks')}
- User has shown concern about this area
- Quality verification is needed

## Historical Context

This skill was learned from repeated user feedback:

'''
        for i, example in enumerate(rule_data.get("examples", [])[:3], 1):
            content += f"**Instance {i}:** {example}\n\n"

        return content

    def _generate_preferences_file(self, analysis_result: Dict) -> Dict:
        """Generate unified user preferences JSON."""
        return {
            "version": "1.0",
            "generated": datetime.now().isoformat(),
            "source": "conversation-history-analysis",
            "preferences": analysis_result.get("preferences", {}),
            "corrections": analysis_result.get("corrections", []),
        }

    def _slugify(self, text: str) -> str:
        """Convert text to URL-safe slug."""
        slug = text.lower()
        slug = re.sub(r"[^a-z0-9]+", "-", slug)
        slug = slug.strip("-")
        return slug[:50]  # Limit length

    def _get_file_extension(self) -> str:
        """Get file extension based on output format."""
        extensions = {
            "claude": ".md",
            "ollama": ".yaml",
            "openclaw": ".json",
            "universal": ".md",
        }
        return extensions.get(self.output_format, ".md")


# =============================================================================
# CLI Interface
# =============================================================================

def main():
    import argparse

    parser = argparse.ArgumentParser(
        description="Extract skills from conversation history",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )

    parser.add_argument(
        "--input",
        type=Path,
        default=None,
        help="Input directory or file with conversations (auto-detects if not specified)",
    )

    parser.add_argument(
        "--harness",
        type=str,
        choices=SUPPORTED_HARNESSES,
        default="all",
        help="Which harness to extract from (default: all)",
    )

    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help=f"Output directory for skills (default: {DEFAULT_OUTPUT_DIR})",
    )

    parser.add_argument(
        "--format",
        choices=SUPPORTED_FORMATS,
        default="claude",
        help=f"Output format (default: claude)",
    )

    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be generated without writing files",
    )

    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Show detailed analysis output",
    )

    args = parser.parse_args()

    print("=" * 70)
    print("Conversation History to Skills Extractor")
    print("=" * 70)
    print(f"Harness: {args.harness}")
    print(f"Output: {args.output}")
    print(f"Format: {args.format}")
    print()

    # Auto-detect input sources based on harness selection
    input_sources = []

    if args.harness in ["claude", "all"]:
        for path in CLAUDE_HISTORY_PATHS:
            if path.exists():
                input_sources.append(("claude", path))
                break

    if args.harness in ["codex", "all"]:
        for path in CODEX_HISTORY_PATHS:
            if path.exists():
                input_sources.append(("codex", path))
                break

    if args.harness in ["openclaw", "all"]:
        for path in OPENCLAW_HISTORY_PATHS:
            if path.exists():
                input_sources.append(("openclaw", path))
                break

    if not input_sources:
        print("No conversation history found for selected harness(es).")
        print(f"Searched: {CLAUDE_HISTORY_PATHS + CODEX_HISTORY_PATHS + OPENCLAW_HISTORY_PATHS}")
        return 1

    print("Input sources:")
    for harness, path in input_sources:
        print(f"  - {harness}: {path}")
    print()

    # Run analysis on all sources
    all_results = {"patterns": {}, "preferences": {}, "corrections": []}

    for harness, input_path in input_sources:
        print(f"\nAnalyzing {harness} history...")
        analyzer = ConversationAnalyzer(input_path, args.output, args.format)
        results = analyzer.analyze()

        # Merge results
        for key in ["preferences", "corrections"]:
            if key in results:
                if isinstance(results[key], list):
                    all_results[key].extend(results[key])
                else:
                    all_results[key].update(results[key])

        for category, patterns in results.get("patterns", {}).items():
            if category not in all_results["patterns"]:
                all_results["patterns"][category] = []
            all_results["patterns"][category].extend(patterns)

    results = all_results

    # Print summary
    print("\nAnalysis Summary")
    print("-" * 40)

    patterns = results.get("patterns", {})
    total_patterns = sum(len(v) for v in patterns.values())
    print(f"Patterns found: {total_patterns}")

    for category, items in patterns.items():
        if items:
            print(f"  - {category}: {len(items)} patterns")

    preferences = results.get("preferences", {})
    print(f"\nUser preferences extracted: {len(preferences)}")

    corrections = results.get("corrections", [])
    print(f"Learned corrections: {len(corrections)}")

    # Generate skills
    print("\nGenerating skills...")
    generated = analyzer.generate_skills(results, dry_run=args.dry_run)

    if args.dry_run:
        print("\n[DRY RUN] No files written.")
    else:
        print(f"\nGenerated {len(generated)} skill files:")
        for file_path in generated:
            print(f"  - {file_path}")

    # Print detailed output if verbose
    if args.verbose:
        print("\n" + "=" * 70)
        print("Detailed Pattern Analysis")
        print("=" * 70)
        print(json.dumps(results, indent=2, default=str))

    print("\n" + "=" * 70)
    print("Analysis complete!")
    print("=" * 70)


if __name__ == "__main__":
    main()
