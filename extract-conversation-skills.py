#!/usr/bin/env python3
"""
=============================================================================
Conversation History to Skills Extractor — ALMA-Inspired Pipeline
=============================================================================
4-stage pipeline for extracting concise, generalizable skills from
conversation histories across multiple AI agent harnesses.

Stages:
  1. Ingestion  — Parse histories, classify utterances into memory types
  2. Learning   — Group similar patterns, require min evidence, score confidence
  3. Consolidation — Deduplicate, abstract, generalization filter
  4. Output     — Write concise SKILL.md files with condition+strategy form

Based on patterns from:
  - ALMA (RBKunnela/ALMA-memory): memory types, confidence scoring, decay
  - Reflexion (Shinn et al.): extract from failures, distill to plans
  - mem0: LLM-based extraction, entity linking
  - ai-linter: quality enforcement (≤500 lines, ≤5000 tokens)

Usage:
    python3 extract-conversation-skills.py [OPTIONS]

Options:
    --input DIR         Directory with conversation exports (auto-detect if not set)
    --output DIR        Directory to write generated skills (default: ~/.claude/skills/learned/)
    --harness H         Which harness to extract from: claude|codex|openclaw|all (default: all)
    --dry-run           Show what would be extracted without writing files
    --verbose           Show detailed analysis
    --stats             Show usage/decay statistics only (no extraction)
    --prune             Remove decayed/low-quality skills
=============================================================================
"""

import os
# Prevent huggingface tokenizers from enabling parallelism before fork,
# which causes deadlock warnings and slowdowns when subprocess is used.
os.environ["TOKENIZERS_PARALLELISM"] = "false"

import re
import json
import hashlib
import math
from pathlib import Path
from datetime import datetime, timedelta
from collections import defaultdict
from dataclasses import dataclass, field
from typing import Dict, List, Set, Tuple, Optional
import time
from concurrent.futures import ThreadPoolExecutor, as_completed


# =============================================================================
# Dependency auto-install
# =============================================================================

def _ensure_deps(verbose: bool = False):
    """Ensure scikit-learn and numpy are available.
    
    sentence-transformers is intentionally NOT checked here — importing it
    can crash the Python process on systems with abseil-cpp/pyarrow version
    conflicts (SIGABRT, not catchable via except Exception). It is imported
    lazily inside _cluster_by_similarity with a try/except that falls back
    to Jaccard clustering if unavailable.
    """
    required = {
        "scikit-learn": "scikit-learn>=1.5.0",
        "numpy": "numpy>=1.26.0",
    }
    missing = []
    for module, pkg in required.items():
        try:
            __import__(module.replace("-", "_"))
        except ImportError:
            missing.append(pkg)
    
    if missing:
        if verbose:
            print(f"  [DEPS] Installing: {', '.join(missing)}...")
        import subprocess, sys
        in_venv = sys.prefix != getattr(sys, "base_prefix", sys.prefix)
        cmd = [sys.executable, "-m", "pip", "install", "--quiet"] + missing
        if not in_venv:
            cmd.append("--user")
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"  [WARN] Failed to auto-install dependencies: {result.stderr[:200]}")
            print(f"  [WARN] Please run: pip install {' '.join(missing)}")
            return False
        if verbose:
            print(f"  [DEPS] Installed: {', '.join(missing)}")
    return True


# =============================================================================
# Configuration
# =============================================================================

CLAUDE_HISTORY_PATHS = [
    Path.home() / ".claude" / "projects",   # Claude Code: projects/<project>/<session-id>.jsonl
]
CODEX_HISTORY_PATHS = [
    Path.home() / ".codex" / "sessions",     # Codex: sessions/YYYY/MM/DD/rollout-*.jsonl
]
OPENCLAW_HISTORY_PATHS = [
    Path.home() / ".openclaw" / "agents",    # OpenClaw: agents/main/sessions/*.jsonl
]
PI_HISTORY_PATHS = [
    Path.home() / ".pi" / "agent" / "sessions",  # Pi: agent/sessions/<project>/*.jsonl
]
DEFAULT_OUTPUT_DIR = Path.home() / ".claude" / "skills" / "learned"
USAGE_FILE = DEFAULT_OUTPUT_DIR / ".usage.json"

# Model routing hierarchy: try in order until one works
# Note: Claude Code CLI (-p flag) requires ANTHROPIC_API_KEY, so we check first
MODEL_PRIORITY = [
    {"name": "ollama-cloud", "type": "ollama", "model": "qwen3.5:cloud", "timeout": 180},  # Ollama cloud (best quality, no local GPU needed)
    {"name": "ollama-local", "type": "ollama", "model": "qwen3.6:latest", "timeout": 240},  # Local qwen3.6 (fallback, slower but private)
]

# Pipeline thresholds (ALMA-inspired)
MIN_OCCURRENCES = 3
MIN_CONFIDENCE = 0.5
GROUP_SIMILARITY = 0.5       # Jaccard threshold for grouping
DEDUP_SIMILARITY = 0.85      # Token overlap for deduplication
MAX_SKILL_LINES = 50
MAX_EXAMPLES_STORED = 5
DECAY_HALF_LIFE_DAYS = 90
PRUNE_THRESHOLD = 0.2
FEEDBACK_MIN_SAMPLES = 5

MEMORY_TYPES = ["heuristic", "anti_pattern", "preference", "domain_knowledge"]
GENERALIZABLE_TYPES = {"heuristic", "anti_pattern"}


def _try_get_completion(prompt: str, timeout: int = 60, verbose: bool = False) -> Optional[str]:
    """Try to get completion from models in priority order. Returns first successful response.
    
    Tries standard Ollama HTTP API first (reliable, fast), then falls back to subprocess.
    """
    import subprocess
    
    for model_config in MODEL_PRIORITY:
        model_name = model_config["name"]
        model_type = model_config["type"]
        model_id = model_config["model"]
        model_timeout = model_config["timeout"]
        
        if verbose:
            print(f"  [LLM-TRY] {model_name} ({model_id})...")
        
        try:
            if model_type == "ollama":
                # --- PRIMARY: Standard Ollama HTTP API ---
                try:
                    import urllib.request
                    import urllib.error
                    req = urllib.request.Request(
                        "http://localhost:11434/api/generate",
                        data=json.dumps({
                            "model": model_id,
                            "prompt": prompt,
                            "stream": False,
                            "options": {"temperature": 0.3, "num_predict": 512}
                        }).encode("utf-8"),
                        headers={"Content-Type": "application/json"},
                        method="POST"
                    )
                    with urllib.request.urlopen(req, timeout=min(timeout, model_timeout)) as resp:
                        data = json.loads(resp.read().decode("utf-8"))
                        response_text = data.get("response", "").strip()
                        if response_text:
                            if verbose:
                                print(f"  [LLM-OK] {model_name} (HTTP API) returned {len(response_text)} chars")
                            return response_text
                except (urllib.error.URLError, urllib.error.HTTPError, ConnectionRefusedError) as e:
                    if verbose:
                        print(f"  [LLM-FALLBACK] HTTP API unavailable ({type(e).__name__}), trying subprocess...")
                except Exception as e:
                    if verbose:
                        print(f"  [LLM-FALLBACK] HTTP API error ({type(e).__name__}), trying subprocess...")
                
                # --- FALLBACK: Subprocess via ollama run ---
                result = subprocess.run(
                    ["ollama", "run", model_id, prompt],
                    capture_output=True, text=True, timeout=min(timeout, model_timeout),
                    stdin=subprocess.DEVNULL,
                )
                if result.returncode == 0 and result.stdout.strip():
                    if verbose:
                        print(f"  [LLM-OK] {model_name} (subprocess) returned {len(result.stdout)} chars")
                    return result.stdout.strip()
                elif verbose:
                    print(f"  [LLM-FAIL] {model_name}: {result.stderr[:100] if result.stderr else 'empty output'}")
        
        except subprocess.TimeoutExpired:
            if verbose:
                print(f"  [LLM-TIMEOUT] {model_name} after {model_timeout}s")
        except Exception as e:
            if verbose:
                print(f"  [LLM-ERROR] {model_name}: {type(e).__name__}")
    
    if verbose:
        print(f"  [LLM-ALL-FAIL] All models failed")
    return None

# Regex markers per memory type
# Frustration/escalation signals — strong evidence this is a real correction
FRUSTRATION_MARKERS = [
    r"\b(?:again|still|keep(?:ing)?|once more|repeatedly)\s+(?:telling|saying|asking|explaining)\b",
    r"\b(?:I (?:keep|already|just)\s+(?:told|said|asked|explained|mentioned))\b",
    r"\b(?:for the (?:last|nth)\s+time)\b",
    r"\b(?:I've (?:said|told|explained)\s+this\s+(?:before|already|multiple times))\b",
    r"\b(?:this is (?:the \d+|third|fourth|fifth|nth)\s+time)\b",
    r"\b(?:still (?:wrong|incorrect|not right|broken|failing))\b",
    r"\b(?:WRONG|INCORRECT|NO!|STOP)\b",
    r"\b(?:didn't I (?:just|already)\s+(?:say|tell|explain))\b",
]

CLASSIFICATION_MARKERS = {
    "anti_pattern": [
        r"(?:don't|do not|never)\s+(?:do|say|write|generate|use|include|fabricat|hallucinat|invent|assume|claim|state|present)\s+",
        r"(?:stop|avoid)\s+(?:fabricat|hallucinat|inventing|making|generating|assuming|claiming|presenting)\s+",
        r"(?:that's\s+)?(?:wrong|incorrect|not\s+what)\s+(?:I\s+)?(?:asked|meant|wanted|said)\s+",
        r"\b(?:fabricat|hallucinat|made\s+up)\w+",
        r"(?:no,?\s+i\s+meant|actually,?\s+I\s+meant)\s+",
        r"(?:unreliable|unverified|unsourced|bogus|made-up)\s+(?:claim|info|data|source|result)\s*",
    ],
    "heuristic": [
        r"(?:always|usually|typically)\s+(?:do|use|include|check|verify|cite|reference|cross-?check)\s+",
        r"(?:the\s+(?:best|right|correct|proper)\s+way)\s+(?:is|to)\s+",
        r"(?:i\s+)?(?:found\s+that|learned\s+that|discovered\s+that)\s+",
        r"(?:works\s+(?:best|better|well))\s+",
        r"(?:prefer|recommend|suggest)\s+\w+\s+(?:over|instead\s+of|vs)\s+",
        r"(?:make\s+sure|ensure|always\s+verify)\s+",
        r"(?:you\s+(?:should|must|need\s+to)\s+(?:always|always\s+)?(?:cite|verify|check|cross-reference))\s+",
    ],
    "preference": [
        r"(?:i\s+(?:prefer|like|want|need))\s+",
        r"(?:my\s+(?:style|preference|convention))\s+(?:is|uses)\s+",
        r"(?:use\s+tabs|use\s+spaces|2-space|4-space)",
        r"(?:please\s+(?:always|never))\s+",
    ],
    "domain_knowledge": [
        r"(?:the\s+(?:api|endpoint|url|server|database)\s+(?:is|at|on))\s+",
        r"(?:the\s+(?:config|setting|variable|flag)\s+(?:is|should\s+be))\s+",
        r"(?:version\s+\d+\.\d+)",
    ],
}

# Patterns to SKIP — not corrections, just noise
SKIP_PATTERNS = [
    re.compile(r"^\s*(?:what|where|when|who|why|how|which|is|are|can|does|did)\b.*\?\s*$", re.IGNORECASE),  # pure questions
    re.compile(r"(?:Do\s+NOT|NEVER)\s+(?:use|run|call|execute)\s+(?:Read|Bash|Grep|Glob|Edit|Write|any\s+other\s+tool)", re.IGNORECASE),  # system tool restrictions
    re.compile(r"^\s*(?:yes|no|ok|okay|done|sure|right|correct|good)\s*[.!?]?\s*$", re.IGNORECASE),  # trivial responses
    re.compile(r"^\s*[\*\-\#]+\s*"),  # markdown bullets/headers leaked from compacted context
    re.compile(r"\(From compacted session\)", re.IGNORECASE),  # compacted session artifacts
    # System prompt instructions that leak into user messages (Claude Code compaction artifacts)
    re.compile(r"^Before providing your final summary", re.IGNORECASE),
    re.compile(r"^IMPORTANT:\s*ensure that this step", re.IGNORECASE),
    re.compile(r"^This should be verbatim", re.IGNORECASE),
    re.compile(r"^wrap your analysis in\s+<", re.IGNORECASE),
    re.compile(r"ensure you'?ve?\s+covered all necessary points", re.IGNORECASE),
    re.compile(r"DIRECTLY in line with the user'?s most recent", re.IGNORECASE),
    re.compile(r"no drift in task interpretation", re.IGNORECASE),
    # Generic agent instructions not from user
    re.compile(r"^(?:First|Then|Next|Finally),?\s+(?:think|analyze|review|check|verify)", re.IGNORECASE),
    re.compile(r"^<analysis>", re.IGNORECASE),
    re.compile(r"^Step \d+:", re.IGNORECASE),
]

# Quality gate: conditions that indicate we failed to abstract properly
GENERIC_CONDITIONS = {
    "when the relevant context arises",
    "when appropriate",
    "when working with the relevant topic",
    "when needed",
    "when applicable",
}

# Project-specific identifiers → not generalizable
PROJECT_SPECIFIC_PATTERNS = [
    r"(?:/|\\)(?:src|lib|app|pkg|cmd|internal|scripts|configs?)/\S+",
    r"(?:https?://\S+)",
    r"(?:0x[0-9a-fA-F]+)",
    r"(?:ghp_|gho_|github_pat_)\w+",
    r"(?:\b[A-Z][a-z]+[A-Z]\w*\b)",
    r"(?:import\s+\w+\s+from\s+['\"]\.\/)",
    r"(?:localhost:\d+)",
    r"(?:\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})",
    r"(?:api[_-]?key|secret|password|token)\s*[:=]",
]

MAX_CONTEXT_CHARS = 1000


# Common stop words to exclude from keyword extraction
STOP_WORDS = {
    "that", "this", "with", "from", "have", "will", "been", "they", "them",
    "what", "where", "which", "there", "their", "about", "would", "could",
    "should", "into", "than", "then", "also", "just", "more", "some", "very",
    "when", "only", "even", "must", "here", "like", "well", "back", "still",
    "each", "does", "before", "after", "between", "through", "during",
    "without", "within", "along", "using", "these", "those", "being", "because",
    "doing", "going", "getting", "having", "looking", "making", "thing",
    "things", "something", "anything", "everything", "nothing", "really",
    "actually", "basically", "literally", "probably", "maybe", "perhaps",
}


# =============================================================================
# Data Structures
# =============================================================================

@dataclass
class RawCorrection:
    """A single correction/event from conversation history."""
    memory_type: str
    raw_text: str
    timestamp: Optional[datetime] = None
    harness: str = "unknown"
    project: str = "unknown"  # project/session origin for cross-project validation
    session_id: str = ""      # session file stem for dedup and provenance

    @property
    def words(self) -> Set[str]:
        return set(re.findall(r"\b\w+\b", self.raw_text.lower()))


@dataclass
class PatternGroup:
    """A group of similar corrections that may become a skill."""
    memory_type: str
    corrections: List[RawCorrection] = field(default_factory=list)
    condition: str = ""
    strategy: str = ""
    anti_pattern: str = ""
    short_name: str = ""   # LLM-generated 3-5 word imperative name
    scope: str = "universal"
    confidence: float = 0.0
    frequency: int = 0
    project_count: int = 0   # number of distinct projects this appears in
    harness_count: int = 0   # number of distinct harnesses
    id: str = ""  # Unique identifier for batch processing

    def __post_init__(self):
        if not self.id:
            # Generate ID from first correction's hash + memory_type
            import hashlib
            if self.corrections:
                hash_input = f"{self.memory_type}:{self.corrections[0].session_id}:{self.frequency}"
                self.id = hashlib.sha256(hash_input.encode()).hexdigest()[:12]
            else:
                self.id = f"unknown-{id(self)}"

    @property
    def representative_words(self) -> Set[str]:
        all_words: Set[str] = set()
        for c in self.corrections:
            all_words |= c.words
        return all_words

    def compute_confidence(self, min_occ: int = MIN_OCCURRENCES) -> float:
        if self.frequency < 1:
            return 0.0
        # Cross-project bonus: corrections from more projects = more generalizable
        project_bonus = min(self.project_count / 3.0, 1.0) * 0.3
        sample_factor = min(self.frequency / 20.0, 1.0)
        base = sample_factor * (0.5 + 0.5 * min(self.frequency / max(min_occ, 1), 1.0))
        return min(base + project_bonus, 1.0)


@dataclass
class SkillOutput:
    """A skill ready to be written as SKILL.md."""
    name: str
    memory_type: str
    condition: str
    strategy: str
    anti_pattern: str
    scope: str
    confidence: float
    frequency: int
    project_count: int = 0
    harness_count: int = 0
    created_at: str = ""
    updated_at: str = ""
    created_at: str = ""
    updated_at: str = ""


@dataclass
class UsageRecord:
    """Track how often a learned skill is loaded/used/ignored."""
    loads: int = 0
    uses: int = 0
    ignores: int = 0
    last_loaded: Optional[str] = None
    last_used: Optional[str] = None
    feedback_score: float = 0.0


# =============================================================================
# Stage 1: Ingestion
# =============================================================================

class Ingestion:
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        self.compiled_markers = {
            mtype: [re.compile(p, re.IGNORECASE) for p in patterns]
            for mtype, patterns in CLASSIFICATION_MARKERS.items()
        }
        self.compiled_frustration = [re.compile(p, re.IGNORECASE) for p in FRUSTRATION_MARKERS]
        
        # Multi-turn detection: escalation signal patterns (lower confidence)
        self.escalation_patterns = [
            re.compile(r'\b(hmm?|uhh?|wait|hold on)\b', re.IGNORECASE),
            re.compile(r'\b(not quite|not really|sort of|kind of)\b', re.IGNORECASE),
            re.compile(r'\b(that\'s not what|that\'s not right|something\'s off)\b', re.IGNORECASE),
            re.compile(r'\b(no,? (but|however|wait))\b', re.IGNORECASE),
            re.compile(r'\b(you\'re missing|you missed|you forgot)\b', re.IGNORECASE),
        ]

    def score_utterance(self, text: str) -> Tuple[Optional[str], float]:
        """
        Classify utterance and return (memory_type, confidence).
        
        Confidence levels:
          0.95+ = Direct anti-pattern match ("don't", "never", "wrong...instead")
          0.80+ = Frustration/escalation marker (strong signal)
          0.60+ = Heuristic pattern match (preference, best practice)
          0.30-0.50 = Escalation/hesitation (weak signal, needs LLM)
          0.00-0.25 = No match (skip)
        
        Returns (None, 0.0) for noise/irrelevant utterances.
        """
        if not text or len(text.strip()) < 10:
            return None, 0.0
        
        text_lower = text.lower().strip()
        
        # Skip noise patterns first
        for skip_pat in SKIP_PATTERNS:
            if skip_pat.search(text):
                return None, 0.0
        
        # ANTI-PATTERN: Strong direct corrections
        strong_anti_patterns = [
            r'^\s*(no|don\'t|do not|never|avoid)\b',
            r'\b(should not|must not|cannot|can\'t|won\'t)\b',
            r'\b(wrong|incorrect|mistake|buggy|broken)\b.*\b(use|try|should|need|instead)\b',
            r'^\s*(actually|instead)\b',
            r'\brather than\b|\binstead of\b',
            r'\b(don\'t|do not|never)\b.*\b(use|do|make|create|generate)\b',
            r'\b(that won\'t work|that doesn\'t work|this fails|this breaks)\b',
            r'\b(you should|it should|this should|we should)\b.*\b(not|instead|rather)\b',
            r'\b(reconsider|rethink|redo|start over|try again)\b',
        ]
        for pattern in strong_anti_patterns:
            if re.search(pattern, text_lower, re.IGNORECASE):
                return "anti_pattern", 0.95
        
        # Frustration/escalation markers → strong signal
        for fpat in self.compiled_frustration:
            if fpat.search(text):
                return "anti_pattern", 0.85
        
        # Near-miss / clarification / polite redirection
        medium_anti_patterns = [
            r'\b(not quite|close but|that\'s not|this is wrong|you missed|you forgot)\b',
            r'\b(i meant|what i meant|i was trying to say)\b',
            r'\b(can you|could you|please)\b.*\b(instead|rather|change|fix|correct)\b',
        ]
        for pattern in medium_anti_patterns:
            if re.search(pattern, text_lower, re.IGNORECASE):
                return "anti_pattern", 0.65
        
        # Escalation/hesitation signals (weak anti-pattern)
        for epat in self.escalation_patterns:
            if epat.search(text):
                return "anti_pattern", 0.40
        
        # HEURISTIC: User preferences and best practices
        strong_heuristic_patterns = [
            r'\b(i prefer|we prefer|i always|we always|i usually|i like to|we like to)\b',
            r'\b(best practice|convention|standard|idiomatic|canonical)\b',
            r'\b(should|must|need to|have to)\b.*\b(always|every|all|never|none)\b',
        ]
        for pattern in strong_heuristic_patterns:
            if re.search(pattern, text_lower, re.IGNORECASE):
                return "heuristic", 0.75
        
        medium_heuristic_patterns = [
            r'\b(make sure|ensure|be sure|double-check|verify)\b.*\b(that|to|you)\b',
            r'\b(remember to|don\'t forget|keep in mind|bear in mind)\b',
            r'\b(it would be better|it\'s better to|preferably|ideally)\b',
            r'\b(i want|i need|we need|i expect)\b.*\b(to be|to have|to use)\b',
        ]
        for pattern in medium_heuristic_patterns:
            if re.search(pattern, text_lower, re.IGNORECASE):
                return "heuristic", 0.55
        
        return None, 0.0

    def classify_utterance(self, text: str) -> Optional[str]:
        """Backward-compatible wrapper that returns only the memory type."""
        mtype, _ = self.score_utterance(text)
        return mtype

    def classify_utterance(self, text: str) -> Optional[str]:
        """
        Classify utterance as correction/heuristic ONLY if it's a DIRECT instruction.
        
        Key insight: Most conversation messages are DESCRIPTIONS of problems,
        not corrections. We only want direct feedback like:
        - "No, use X instead of Y"
        - "Don't do Z"
        - "I prefer using..."
        
        Skip messages that describe issues without giving direction:
        - "The user said there was a bug" (description, not correction)
        - "We need to fix the issue" (task, not feedback)
        """
        if not text or len(text.strip()) < 10:
            return None
        
        text_lower = text.lower().strip()
        
        # Skip noise patterns first
        for skip_pat in SKIP_PATTERNS:
            if skip_pat.search(text):
                return None
        
        # ANTI-PATTERN: Direct corrections (user telling AI what NOT to do)
        direct_anti_patterns = [
            r'^\s*(no|don\'t|do not|never|avoid)\b',  # Starts with negation/command
            r'\b(should not|must not|cannot|can\'t|won\'t)\b',  # Modal negation
            r'\b(wrong|incorrect|mistake|buggy|broken)\b.*\b(use|try|should|need|instead)\b',  # Problem + solution
            r'^\s*(actually|instead)\b',  # Correction markers at start
            r'\brather than\b|\binstead of\b',  # Explicit preference
            r'\b(don\'t|do not|never)\b.*\b(use|do|make|create|generate)\b',  # Don't do X
            r'\b(not quite|close but|that\'s not|this is wrong|you missed|you forgot)\b',  # Near-miss / missed
            r'\b(i meant|what i meant|i was trying to say)\b',  # Clarification = correction
            r'\b(can you|could you|please)\b.*\b(instead|rather|change|fix|correct)\b',  # Polite redirection
            r'\b(that won\'t work|that doesn\'t work|this fails|this breaks)\b',  # Output rejection
            r'\b(you should|it should|this should|we should)\b.*\b(not|instead|rather)\b',  # Should + negation
            r'\b(reconsider|rethink|redo|start over|try again)\b',  # Start-over signals
        ]
        for pattern in direct_anti_patterns:
            if re.search(pattern, text_lower, re.IGNORECASE):
                return "anti_pattern"
        
        # Frustration/escalation markers → strong signal for anti_pattern
        for fpat in self.compiled_frustration:
            if fpat.search(text):
                return "anti_pattern"
        
        # HEURISTIC: User preferences and best practices
        heuristic_patterns = [
            r'\b(i prefer|we prefer|i always|we always|i usually|i like to|we like to)\b',  # Preference statements
            r'\b(best practice|convention|standard|idiomatic|canonical)\b',  # Best practices
            r'\b(should|must|need to|have to)\b.*\b(always|every|all|never|none)\b',  # Universal rules
            r'\b(make sure|ensure|be sure|double-check|verify)\b.*\b(that|to|you)\b',  # Verification requests
            r'\b(remember to|don\'t forget|keep in mind|bear in mind)\b',  # Reminder = preference
            r'\b(it would be better|it\'s better to|preferably|ideally)\b',  # Comparative preference
            r'\b(i want|i need|we need|i expect)\b.*\b(to be|to have|to use)\b',  # Explicit expectation
        ]
        for pattern in heuristic_patterns:
            if re.search(pattern, text_lower, re.IGNORECASE):
                return "heuristic"
        
        return None

    def extract_corrections(self, conversations: List[Dict], harness: str = "unknown") -> List[RawCorrection]:
        """Extract corrections from conversations with multi-turn detection.
        
        Within a session, buffers recent utterances and merges sequences where
        the user escalates (hesitation → frustration → correction) into a single
        rich correction that captures the full reasoning.
        """
        corrections = []
        for conv in conversations:
            content = self._extract_user_messages(conv)
            if not content:
                continue
            # Derive project and session from file path
            fpath = conv.get("path", Path(""))
            project = self._derive_project(fpath, harness)
            session_id = fpath.stem if hasattr(fpath, 'stem') else ""
            utterances = re.split(r"(?<=[.!?])\s+|\n{2,}", content)
            
            # Multi-turn detection: buffer recent utterances with scores
            # Each entry: (utterance_text, mtype, confidence, is_escalation)
            window: List[Tuple[str, Optional[str], float]] = []
            MAX_WINDOW = 5  # Look back at most 5 utterances
            
            for utt in utterances:
                utt = utt.strip()
                if len(utt) < 10:
                    continue
                
                mtype, confidence = self.score_utterance(utt)
                window.append((utt, mtype, confidence))
                
                # If window exceeds size, pop oldest
                if len(window) > MAX_WINDOW:
                    window.pop(0)
                
                if mtype is None:
                    continue
                
                # Single-turn high-confidence correction: emit immediately
                if confidence >= 0.65:
                    corrections.append(RawCorrection(
                        memory_type=mtype,
                        raw_text=utt[:MAX_CONTEXT_CHARS],
                        timestamp=self._extract_timestamp(conv),
                        harness=harness,
                        project=project,
                        session_id=session_id,
                    ))
                    continue
                
                # Multi-turn detection: current utterance is medium/low confidence
                # but preceded by escalation signals. Merge the whole sequence.
                if confidence >= 0.30 and len(window) >= 2:
                    # Check for escalation sequence in previous utterances
                    escalation_utts = []
                    for prev_utt, prev_mtype, prev_conf in window[:-1]:
                        if prev_conf > 0.0 and prev_conf < 0.65:
                            escalation_utts.append(prev_utt)
                    
                    if escalation_utts:
                        # Build merged correction from escalation + current
                        merged_text = " ".join(escalation_utts + [utt])
                        merged_text = merged_text[:MAX_CONTEXT_CHARS]
                        # Take the highest-confidence type
                        best_mtype = mtype
                        best_conf = confidence
                        for _, pm, pc in window:
                            if pm and pc > best_conf:
                                best_mtype = pm
                                best_conf = pc
                        
                        corrections.append(RawCorrection(
                            memory_type=best_mtype,
                            raw_text=merged_text,
                            timestamp=self._extract_timestamp(conv),
                            harness=harness,
                            project=project,
                            session_id=session_id,
                        ))
                        # Clear window to avoid double-counting
                        window.clear()
                        continue
                
                # Low-confidence match (< 0.30) but not part of escalation sequence
                # Don't emit — it'll likely be noise
                if self.verbose and confidence > 0.0:
                    print(f"  [SKIP] Low-confidence ({confidence:.2f}): {utt[:80]}...")
            
        return corrections

    @staticmethod
    def _derive_project(fpath: Path, harness: str) -> str:
        """Extract project identifier from conversation file path."""
        parts = list(fpath.parents) if hasattr(fpath, 'parents') else []
        if harness == "claude" and len(parts) >= 2:
            # ~/.claude/projects/<project-path>/session.jsonl
            return parts[0].name  # project-path directory name
        if harness == "codex" and len(parts) >= 3:
            # ~/.codex/sessions/YYYY/MM/DD/rollout-uuid.jsonl
            return f"codex-{parts[2].name}"  # date-based grouping
        if harness == "pi" and len(parts) >= 2:
            return parts[0].name
        if harness == "openclaw" and len(parts) >= 2:
            return parts[0].name
        return "unknown"

    def _extract_user_messages(self, conv: Dict) -> str:
        data = conv.get("data", {})

        # Claude Code: streaming event log with type=user, message.content as list of objects
        if data.get("type") == "user":
            msg = data.get("message", {})
            content = msg.get("content", "")
            if isinstance(content, list):
                parts = []
                for part in content:
                    if isinstance(part, dict) and part.get("type") == "text":
                        parts.append(part.get("text", ""))
                return "\n".join(parts)
            if isinstance(content, str):
                return content
            return ""

        # Codex: event_msg with payload.type=user_message
        if data.get("type") == "event_msg":
            payload = data.get("payload", {})
            if payload.get("type") == "user_message":
                return payload.get("message", "")

        # OpenClaw/Pi: message type with message.content
        if data.get("type") == "message":
            msg = data.get("message", {})
            role = msg.get("role", "")
            if role not in ("user", "human"):
                return ""
            content = msg.get("content", "")
            if isinstance(content, list):
                parts = []
                for part in content:
                    if isinstance(part, dict) and part.get("type") == "text":
                        parts.append(part.get("text", ""))
                return "\n".join(parts)
            if isinstance(content, str):
                return content
            return ""

        # Generic: messages array (common export format)
        if "messages" in data:
            parts = []
            for msg in data["messages"]:
                if isinstance(msg, dict) and msg.get("role") in ("user", "human"):
                    content = msg.get("content", "")
                    if isinstance(content, list):
                        for part in content:
                            if isinstance(part, dict) and part.get("type") == "text":
                                parts.append(part.get("text", ""))
                    elif isinstance(content, str):
                        parts.append(content)
            return "\n".join(parts)

        # Fallback: plain content
        if "content" in data:
            return data["content"]
        return ""

    def _extract_timestamp(self, conv: Dict) -> Optional[datetime]:
        ts = conv.get("timestamp")
        if isinstance(ts, datetime):
            return ts
        if isinstance(ts, str):
            try:
                return datetime.fromisoformat(ts)
            except (ValueError, TypeError):
                pass
        return None

    def load_conversations(self, input_path: Path) -> List[Dict]:
        conversations = []
        if input_path.is_file() and input_path.suffix == ".jsonl":
            try:
                with open(input_path, "r", encoding="utf-8") as f:
                    for line_num, line in enumerate(f):
                        line = line.strip()
                        if not line:
                            continue
                        try:
                            data = json.loads(line)
                            conversations.append({
                                "path": input_path, "data": data,
                                "timestamp": data.get("timestamp"), "line": line_num,
                            })
                        except json.JSONDecodeError:
                            continue
            except IOError:
                pass
            return conversations

        if not input_path.exists():
            return conversations

        # Recursively find all .jsonl files (handles nested structures like
        # ~/.claude/projects/<project>/<session>.jsonl and
        # ~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl)
        for fp in input_path.rglob("*.jsonl"):
            try:
                with open(fp, "r", encoding="utf-8") as f:
                    for line_num, line in enumerate(f):
                        line = line.strip()
                        if not line:
                            continue
                        try:
                            data = json.loads(line)
                            conversations.append({
                                "path": fp, "data": data,
                                "timestamp": data.get("timestamp"), "line": line_num,
                            })
                        except json.JSONDecodeError:
                            continue
            except IOError:
                continue

        return conversations


# =============================================================================
# Stage 2: Learning
# =============================================================================

class Learning:
    def __init__(self, verbose: bool = False, min_occurrences: int = MIN_OCCURRENCES):
        self.verbose = verbose
        self.min_occurrences = min_occurrences

    def group_corrections(self, corrections: List[RawCorrection]) -> List[PatternGroup]:
        by_type: Dict[str, List[RawCorrection]] = defaultdict(list)
        for c in corrections:
            by_type[c.memory_type].append(c)

        groups: List[PatternGroup] = []
        for mtype, type_corrections in by_type.items():
            clusters = self._cluster_by_similarity(type_corrections, GROUP_SIMILARITY)
            for cluster in clusters:
                group = PatternGroup(memory_type=mtype, corrections=cluster)
                group.frequency = len(cluster)
                # Deduplicate by session (same session = same conversation, not independent evidence)
                unique_sessions = set(c.session_id for c in cluster if c.session_id)
                unique_projects = set(c.project for c in cluster if c.project != "unknown")
                group.project_count = len(unique_projects)
                group.harness_count = len(set(c.harness for c in cluster))
                # Adjust frequency: count unique sessions, not raw line count
                group.frequency = max(len(unique_sessions), 1)
                group.confidence = group.compute_confidence(min_occ=self.min_occurrences)
                groups.append(group)
        return groups

    def apply_thresholds(self, groups: List[PatternGroup]) -> List[PatternGroup]:
        passing = []
        for g in groups:
            if g.frequency < self.min_occurrences:
                if self.verbose:
                    print(f"  [SKIP] {g.memory_type} group (freq={g.frequency} < {self.min_occurrences})")
                continue
            if g.confidence < MIN_CONFIDENCE:
                if self.verbose:
                    print(f"  [SKIP] {g.memory_type} group (conf={g.confidence:.2f} < {MIN_CONFIDENCE})")
                continue
            if g.memory_type not in GENERALIZABLE_TYPES:
                if self.verbose:
                    print(f"  [SKIP] {g.memory_type} group (not generalizable)")
                continue
            passing.append(g)
        return passing

    def _cluster_by_similarity(self, corrections: List[RawCorrection], threshold: float) -> List[List[RawCorrection]]:
        """Cluster corrections by semantic similarity using sentence embeddings.
        
        Uses sklearn AgglomerativeClustering on normalized embeddings for robust,
        deterministic clusters. Falls back to Jaccard only if deps are missing.
        
        On systems with abseil-cpp/pyarrow version conflicts, importing
        sentence-transformers can cause SIGABRT (uncatchable in Python). We
        run the ENTIRE embedding pipeline in a subprocess so the parent survives
        any C++ library crashes and falls back to Jaccard.
        """
        import subprocess, sys, tempfile, json, os
        
        if self.verbose:
            print(f"  [CLUSTER] Attempting embedding-based clustering for {len(corrections)} corrections...")
        
        # Build a temp script that does the embedding + clustering in isolation
        texts = [c.raw_text for c in corrections]
        script = '''
import sys, json
from sentence_transformers import SentenceTransformer
from sklearn.cluster import AgglomerativeClustering
import numpy as np

texts = json.loads(sys.argv[1])
threshold = float(sys.argv[2])
verbose = sys.argv[3] == "1"

if len(texts) == 1:
    print(json.dumps([[0]]))
    sys.exit(0)

encoder = SentenceTransformer('all-MiniLM-L6-v2')
embeddings = encoder.encode(texts, show_progress_bar=False)

norms = np.linalg.norm(embeddings, axis=1, keepdims=True)
norms[norms == 0] = 1
embeddings = embeddings / norms

distance_threshold = max(0.15, 1.0 - threshold)
clustering = AgglomerativeClustering(
    n_clusters=None,
    distance_threshold=distance_threshold,
    metric="cosine",
    linkage="average",
)
labels = clustering.fit_predict(embeddings)

# Group indices by label
from collections import defaultdict
clusters_dict = defaultdict(list)
for idx, label in enumerate(labels):
    clusters_dict[int(label)].append(idx)
clusters = list(clusters_dict.values())

if verbose:
    sizes = [len(c) for c in clusters]
    print(f"[CLUSTER-OK] {len(clusters)} clusters (sizes: {sizes}, threshold={threshold})", file=sys.stderr)

print(json.dumps(clusters))
'''
        try:
            with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
                f.write(script)
                tmp_script = f.name
            
            result = subprocess.run(
                [sys.executable, tmp_script, json.dumps(texts), str(threshold), "1" if self.verbose else "0"],
                capture_output=True, text=True, timeout=120
            )
            os.unlink(tmp_script)
            
            if result.returncode == 0:
                cluster_indices = json.loads(result.stdout.strip())
                clusters = []
                for idxs in cluster_indices:
                    cluster = [corrections[i] for i in idxs]
                    clusters.append(cluster)
                if self.verbose:
                    sizes = [len(c) for c in clusters]
                    print(f"  [CLUSTER] {len(clusters)} clusters from embedding (sizes: {sizes})")
                return clusters
            else:
                if self.verbose:
                    err = result.stderr.strip()[:200]
                    print(f"  [CLUSTER] Embedding subprocess failed ({result.returncode}): {err}")
        except Exception as e:
            if self.verbose:
                print(f"  [CLUSTER] Embedding subprocess error ({type(e).__name__}): {e}")
        finally:
            try:
                os.unlink(tmp_script)
            except Exception:
                pass
        
        # Fallback: Jaccard word overlap
        if self.verbose:
            print(f"  [CLUSTER] Using Jaccard fallback")
        clusters: List[List[RawCorrection]] = []
        used = set()
        for i, c1 in enumerate(corrections):
            if i in used:
                continue
            cluster = [c1]
            used.add(i)
            for j, c2 in enumerate(corrections):
                if j in used or j == i:
                    continue
                sim = self._jaccard(c1.words, c2.words)
                if sim >= threshold:
                    cluster.append(c2)
                    used.add(j)
            clusters.append(cluster)
        return clusters

    @staticmethod
    def _jaccard(a: Set[str], b: Set[str]) -> float:
        if not a or not b:
            return 0.0
        return len(a & b) / len(a | b)


# =============================================================================
# Stage 3: Consolidation
# =============================================================================

class Consolidation:
    def __init__(self, verbose: bool = False, use_llm: bool = False, llm_model: str = None):
        self.verbose = verbose
        self.use_llm = use_llm
        self.llm_model = llm_model or "qwen3.5:cloud"  # Default, but routing will try all models
        self.project_specific_re = [re.compile(p) for p in PROJECT_SPECIFIC_PATTERNS]

    def deduplicate(self, groups: List[PatternGroup]) -> List[PatternGroup]:
        if not groups:
            return []
        merged: List[PatternGroup] = []
        used = set()
        for i, g1 in enumerate(groups):
            if i in used:
                continue
            current = g1
            used.add(i)
            for j, g2 in enumerate(groups):
                if j in used or j == i:
                    continue
                if g1.memory_type != g2.memory_type:
                    continue
                sim = self._token_overlap(current.representative_words, g2.representative_words)
                if sim >= DEDUP_SIMILARITY:
                    current.corrections.extend(g2.corrections)
                    current.frequency += g2.frequency
                    current.confidence = current.compute_confidence(min_occ=MIN_OCCURRENCES)
                    used.add(j)
                    if self.verbose:
                        print(f"  [MERGE] Deduped group ({sim:.2f} similarity)")
            merged.append(current)
        return merged

    def abstract_group(self, group: PatternGroup) -> PatternGroup:
        """LLM-only abstraction. No templates, no keywords."""
        distilled = self._llm_distill(group)
        if distilled:
            if len(distilled) == 4:
                group.condition, group.strategy, group.anti_pattern, group.short_name = distilled
            else:
                group.condition, group.strategy, group.anti_pattern = distilled[:3]
            group.scope = self._determine_scope(group)
            return group
        # If LLM fails, mark as unabstracted so downstream rejects
        group.condition = ""
        group.strategy = ""
        return group

    def _llm_distill(self, group: PatternGroup) -> Optional[Tuple[str, str, str]]:
        """LLM-only abstraction via single-pass distillation."""
        if not self.use_llm:
            return None
        return self._llm_distill_single(group)

    def _validate_complete(self, text: str, field_name: str) -> bool:
        """Validate that a field is complete (not truncated)."""
        if not text or len(text) < 30:
            return False
        truncation_endings = [
            ' init', ' preven', ' specifi', ' identif', ' enab', ' ensur',
            ' impl', ' valid', ' analy', ' proces', ' gener', ' docu',
            ' meth', ' compat', ' serial', ' cross', ' fur', ' cons',
            ' due ', ' becau', ' result', ' lead', ' caus',
        ]
        for ending in truncation_endings:
            if text.rstrip().endswith(ending):
                return False
        words = text.split()
        if words:
            last_word = words[-1].lower().rstrip('.,;:!?')
            short_real_words = {'to', 'of', 'in', 'on', 'at', 'be', 'by', 'or', 'an', 'as', 'if', 'is', 'it', 'we', 'he', 'she', 'the', 'and', 'but', 'for', 'not', 'with', 'from', 'that', 'this', 'when', 'what', 'how', 'why', 'who'}
            if len(last_word) <= 2 and last_word not in {'i', 'a'}:
                return False
            if len(last_word) == 3 and last_word not in short_real_words:
                return False
            if len(last_word) == 1 and len(text) > 50:
                return False
        if text.rstrip().endswith(('ing', 'ate', 'ify', 'ize', 'ise', 'ct', 'pt', 'rm', 'ble')):
            complete_endings = {'ing', 'ated', 'ified', 'ized', 'ised', 'cted', 'pted', 'rmed', 'bled'}
            if not any(text.rstrip().endswith(e) for e in complete_endings):
                return False
        if not text.rstrip().endswith(('.', ';', '!', '?')):
            return False
        if len(text.split()) < 6:
            return False
        return True

    def _llm_distill_single(self, group: PatternGroup) -> Optional[Tuple[str, str, str]]:
        """Fallback: distill a single group (used when batch fails)."""
        samples = sorted(group.corrections, key=lambda c: len(c.raw_text), reverse=True)[:3]
        prompt = f"""You are distilling repeated user corrections into a concise, generalizable skill.

Memory type: {group.memory_type}
Occurrence count: {group.frequency}
Harnesses: {set(c.harness for c in samples)}

User corrections:
{chr(10).join(f'- {c.raw_text}' for c in samples)}

Produce exactly 4 lines:
SHORT_NAME: <3-5 word imperative slug, e.g. "verify-output-completeness" or "test-before-commit" — NO "when-a-..." prefixes>
CONDITION: <when this context arises — GENERAL and transferable, not tied to specific tools or domains, 1 sentence>
STRATEGY: <what to do, complete sentence, use semicolons to separate steps>
ANTI-PATTERN: <what not to do, 1 sentence> (only for anti_pattern type, otherwise write "NONE")

Rules:
- SHORT_NAME must be an imperative verb phrase: "verify-X", "avoid-X", "prefer-X" — 3-5 words max
- CONDITION must be GENERAL — strip domain specifics (e.g., "batch visualization" → "iterative tasks")
- Abstract away project-specific details (file paths, URLs, class names, tool names)
- Be complete — do NOT truncate mid-word
- Write complete sentences that end with a period
- No markdown, no quotes, just plain text"""

        try:
            # Use model routing hierarchy instead of hardcoded ollama
            output = _try_get_completion(prompt, timeout=90, verbose=self.verbose)
            
            if not output:
                return None
            
            # Strip ANSI escape codes
            ansi_re = re.compile(r'\x1b\[[0-9;]*[a-zA-Z]')
            output = ansi_re.sub('', output)
            condition = strategy = anti_pattern = short_name = ""
            for line in output.split("\n"):
                line = line.strip()
                if line.upper().startswith("SHORT_NAME:"):
                    short_name = line.split(":", 1)[1].strip().lower().replace(" ", "-")
                elif line.upper().startswith("CONDITION:"):
                    condition = line.split(":", 1)[1].strip()
                elif line.upper().startswith("STRATEGY:"):
                    strategy = line.split(":", 1)[1].strip()
                elif line.upper().startswith("ANTI-PATTERN:"):
                    anti_pattern = line.split(":", 1)[1].strip()

            if condition and strategy:
                # Validate completeness - reject truncated output
                cond_ok = self._validate_complete(condition, "condition")
                strat_ok = self._validate_complete(strategy, "strategy")
                anti_ok = not anti_pattern or self._validate_complete(anti_pattern, "anti_pattern")
                
                if not cond_ok:
                    if self.verbose:
                        print(f"  [SINGLE-FAIL] condition truncated: {condition[:50]}...")
                    return None
                
                if not strat_ok:
                    if self.verbose:
                        print(f"  [SINGLE-FAIL] strategy truncated: {strategy[:50]}...")
                    return None
                
                if anti_pattern and not anti_ok:
                    if self.verbose:
                        print(f"  [SINGLE-FAIL] anti_pattern truncated: {anti_pattern[:50]}...")
                    anti_pattern = ""  # Accept without anti_pattern rather than reject
                
                if anti_pattern in ("", "NONE", "none"):
                    anti_pattern = ""
                
                if self.verbose:
                    print(f"  [SINGLE-OK] validated")
                return (condition, strategy, anti_pattern, short_name)
        except Exception:
            pass
        return None

    def is_generalizable(self, group: PatternGroup) -> bool:
        for c in group.corrections:
            for pattern in self.project_specific_re:
                if pattern.search(c.raw_text):
                    if self.verbose:
                        print(f"  [REJECT] Contains project-specific identifiers: {c.raw_text[:80]}...")
                    return False
        return True


    def _determine_scope(self, group: PatternGroup) -> str:
        for c in group.corrections:
            for pattern in self.project_specific_re:
                if pattern.search(c.raw_text):
                    return "per-project"
        lang_keywords = {"python", "typescript", "rust", "go", "java", "kotlin", "swift"}
        if group.representative_words & lang_keywords:
            return "per-language"
        return "universal"

    @staticmethod
    def _token_overlap(a: Set[str], b: Set[str]) -> float:
        if not a or not b:
            return 0.0
        return len(a & b) / len(a | b)


# =============================================================================
# Stage 4: Output
# =============================================================================

class SkillWriter:
    def __init__(self, output_dir: Path, dry_run: bool = False, verbose: bool = False):
        self.output_dir = output_dir
        self.dry_run = dry_run
        self.verbose = verbose

    def write_skills(self, groups: List[PatternGroup]) -> List[str]:
        written = []
        
        # Clean up old truncated files (< 60 chars = definitely truncated)
        if not self.dry_run:
            for old_file in self.output_dir.glob("when-*.md"):
                if len(old_file.stem) < 60:
                    old_file.unlink()
                    if self.verbose:
                        print(f"  [CLEANUP] Removed truncated: {old_file.name}")
        
        for group in groups:
            skill = self._group_to_skill(group)
            content = self._render_skill_md(skill)

            if self.dry_run:
                line_count = content.count("\n") + 1
                print(f"  [DRY-RUN] Would write: {skill.name}.md ({line_count} lines)")
                if self.verbose:
                    print(f"    Condition: {skill.condition}")
                    print(f"    Strategy: {skill.strategy}")
            else:
                self.output_dir.mkdir(parents=True, exist_ok=True)
                fp = self.output_dir / f"{skill.name}.md"
                with open(fp, "w", encoding="utf-8") as f:
                    f.write(content)
                written.append(str(fp))
                if self.verbose:
                    print(f"  [WRITE] {skill.name}.md")
        return written

    def _group_to_skill(self, group: PatternGroup) -> SkillOutput:
        # Prefer LLM-generated short name; fall back to strategy-based slug
        if group.short_name and self._is_valid_short_name(group.short_name):
            name = group.short_name
        else:
            name = self._slugify_strategy(group.strategy or group.condition or group.memory_type)
        now = datetime.now().isoformat()
        return SkillOutput(
            name=name,
            memory_type=group.memory_type,
            condition=group.condition,
            strategy=group.strategy,
            anti_pattern=group.anti_pattern,
            scope=group.scope,
            confidence=group.confidence,
            frequency=group.frequency,
            project_count=group.project_count,
            harness_count=group.harness_count,
            created_at=now,
            updated_at=now,
        )

    def _render_skill_md(self, skill: SkillOutput) -> str:
        """Render a learned skill in ECC-compatible format.

        Matches ECC structure: frontmatter → When to Use → Operating Principles → Anti-patterns → Provenance
        """
        desc = self._build_description(skill)
        # Quote description if it contains YAML-special characters (colons, quotes)
        if ':' in desc or '"' in desc:
            desc = f'"{desc}"'
        lines = [
            "---",
            f"name: {skill.name}",
            f"description: {desc}",
            "origin: conversation-pipeline",
            f"tags: [learned, {skill.memory_type}, {skill.scope}]",
            "version: 1.0.0",
            f"priority: {'critical' if skill.confidence > 0.8 else 'high' if skill.confidence > 0.5 else 'medium'}",
            "---",
            "",
            f"# {self._title_case(skill.name)}",
            "",
            "## When to Use",
            "",
            f"{skill.condition.rstrip('.')}.",
            "",
            "## Operating Principles",
            "",
        ]
        # Split strategy into numbered principles (semicolon-separated)
        principles = [s.strip() for s in skill.strategy.split(";") if s.strip()]
        for i, p in enumerate(principles, 1):
            lines.append(f"{i}. {p.capitalize().rstrip('.')}.")
        lines.append("")
        if skill.anti_pattern:
            lines.append("## Anti-patterns")
            lines.append("")
            anti_items = [s.strip() for s in skill.anti_pattern.split(";") if s.strip()]
            for item in anti_items:
                lines.append(f"- {item.capitalize().rstrip('.')}.")
            lines.append("")
        lines.append("## Provenance")
        lines.append("")
        lines.append(f"- **Confidence:** {skill.confidence:.2f}")
        lines.append(f"- **Unique sessions:** {skill.frequency}")
        lines.append(f"- **Projects:** {skill.project_count}")
        lines.append(f"- **Harnesses:** {skill.harness_count}")
        lines.append(f"- **First observed:** {skill.created_at[:10] if skill.created_at else 'unknown'}")
        lines.append("")
        return "\n".join(lines)

    @staticmethod
    def _build_description(skill: SkillOutput) -> str:
        """Generate a one-line description matching ECC convention."""
        mtype_map = {"anti_pattern": "Avoid", "heuristic": "Apply"}
        verb = mtype_map.get(skill.memory_type, "Follow")
        core = skill.strategy.split(";")[0].strip().capitalize().rstrip(".") if skill.strategy else skill.name
        return f"{verb} {core.lower()}. Learned from {skill.frequency} sessions across {skill.project_count} projects."

    @staticmethod
    def _title_case(kebab: str) -> str:
        """Convert kebab-case to Title Case."""
        return " ".join(w.capitalize() for w in kebab.split("-"))

    @staticmethod
    def _is_valid_short_name(name: str) -> bool:
        """Check that a LLM-generated short name is truly short and imperative."""
        if not name:
            return False
        # Reject if it still looks like a sentence fragment (starts with "when-a-" etc.)
        bad_prefixes = ("when-a-", "when-the-", "when-an-", "if-a-", "if-the-")
        if any(name.startswith(p) for p in bad_prefixes):
            return False
        words = name.split("-")
        # Must be 2-6 words
        if not (2 <= len(words) <= 6):
            return False
        # Must start with a verb (imperative form)
        imperative_verbs = {
            "verify", "validate", "check", "test", "avoid", "prefer", "use",
            "ensure", "require", "enforce", "follow", "apply", "always", "never",
            "confirm", "inspect", "review", "run", "write", "read", "parse",
            "handle", "catch", "log", "emit", "track", "assert", "compare",
        }
        if words[0] not in imperative_verbs:
            return False
        return True

    @staticmethod
    def _slugify_strategy(text: str) -> str:
        """Create 3-5 word imperative filename from strategy text.
        
        Extracts verb + key nouns from the strategy (not condition), discarding
        stop words and domain-specific details. Produces names like:
          'verify-output-completeness', 'test-before-commit', 'avoid-broad-searches'
        """
        stop_words = {
            "a", "an", "the", "is", "are", "was", "were", "be", "been",
            "have", "has", "do", "does", "will", "would", "could", "should",
            "may", "might", "must", "can", "to", "of", "in", "for", "on",
            "with", "at", "by", "from", "as", "that", "this", "or", "and",
            "but", "not", "very", "just", "also", "all", "any", "each",
            "its", "it", "into", "only", "such", "then", "than", "when",
            "full", "set", "exists", "using", "use", "via", "per",
        }
        t = text.lower().strip()
        # Strip leading "When" / "Avoid" / "Apply" that came from a condition
        t = re.sub(r"^(when|avoid|apply|follow|ensure)\s+", "", t)
        # Tokenize to words only
        words = re.findall(r"\b[a-z]+\b", t)
        # Keep content words
        content = [w for w in words if w not in stop_words and len(w) > 2]
        # Take first 4 content words, cap at 64 chars
        slug = "-".join(content[:4])[:64]
        slug = slug.rstrip("-")
        return slug or "learned-skill"

    @staticmethod
    def _slugify(text: str) -> str:
        """Legacy fallback — prefer _slugify_strategy for new code."""
        return SkillWriter._slugify_strategy(text)

# =============================================================================
# Feedback & Decay
# =============================================================================

class FeedbackTracker:
    def __init__(self, usage_file: Path = USAGE_FILE, verbose: bool = False):
        self.usage_file = usage_file
        self.verbose = verbose
        self.records: Dict[str, UsageRecord] = {}
        self._load()

    def _load(self):
        if self.usage_file.exists():
            try:
                with open(self.usage_file, "r") as f:
                    data = json.load(f)
                for name, rec in data.items():
                    self.records[name] = UsageRecord(
                        loads=rec.get("loads", 0),
                        uses=rec.get("uses", 0),
                        ignores=rec.get("ignores", 0),
                        last_loaded=rec.get("last_loaded"),
                        last_used=rec.get("last_used"),
                        feedback_score=rec.get("feedback_score", 0.0),
                    )
            except (json.JSONDecodeError, IOError):
                self.records = {}

    def save(self):
        self.usage_file.parent.mkdir(parents=True, exist_ok=True)
        data = {}
        for name, rec in self.records.items():
            data[name] = {
                "loads": rec.loads,
                "uses": rec.uses,
                "ignores": rec.ignores,
                "last_loaded": rec.last_loaded,
                "last_used": rec.last_used,
                "feedback_score": rec.feedback_score,
            }
        with open(self.usage_file, "w") as f:
            json.dump(data, f, indent=2)

    def record_load(self, skill_name: str):
        if skill_name not in self.records:
            self.records[skill_name] = UsageRecord()
        self.records[skill_name].loads += 1
        self.records[skill_name].last_loaded = datetime.now().isoformat()

    def record_use(self, skill_name: str):
        if skill_name not in self.records:
            self.records[skill_name] = UsageRecord()
        self.records[skill_name].uses += 1
        self.records[skill_name].last_used = datetime.now().isoformat()

    def record_ignore(self, skill_name: str):
        if skill_name not in self.records:
            self.records[skill_name] = UsageRecord()
        self.records[skill_name].ignores += 1

    def compute_feedback(self, skill_name: str) -> float:
        rec = self.records.get(skill_name, UsageRecord())
        total = rec.loads
        if total < FEEDBACK_MIN_SAMPLES:
            return 0.5
        return (rec.uses - rec.ignores) / total

    def compute_decay(self, skill_name: str) -> float:
        rec = self.records.get(skill_name, UsageRecord())
        if not rec.last_loaded:
            return 1.0
        try:
            last = datetime.fromisoformat(rec.last_loaded)
        except (ValueError, TypeError):
            return 1.0
        days_since = (datetime.now() - last).days
        if days_since <= 0:
            return 1.0
        return math.exp(-0.693 * days_since / DECAY_HALF_LIFE_DAYS)

    def should_prune(self, skill_name: str) -> bool:
        feedback = self.compute_feedback(skill_name)
        decay = self.compute_decay(skill_name)
        return (feedback * decay) < PRUNE_THRESHOLD

    def prune_skills(self, output_dir: Path, dry_run: bool = False) -> List[str]:
        archived = []
        for skill_file in output_dir.glob("*.md"):
            if skill_file.name.startswith(".") or skill_file.name == "SKILL.md":
                continue
            skill_name = skill_file.stem
            if self.should_prune(skill_name):
                if self.verbose:
                    feedback = self.compute_feedback(skill_name)
                    decay = self.compute_decay(skill_name)
                    print(f"  [PRUNE] {skill_name} (feedback={feedback:.2f}, decay={decay:.2f})")
                if not dry_run:
                    archive_dir = output_dir / "archived"
                    archive_dir.mkdir(exist_ok=True)
                    dest = archive_dir / skill_file.name
                    skill_file.rename(dest)
                archived.append(skill_name)
        return archived

    def stats(self) -> Dict:
        result = {}
        for name, rec in self.records.items():
            result[name] = {
                "loads": rec.loads,
                "uses": rec.uses,
                "ignores": rec.ignores,
                "feedback_score": self.compute_feedback(name),
                "decay_factor": self.compute_decay(name),
                "last_loaded": rec.last_loaded,
                "last_used": rec.last_used,
                "should_prune": self.should_prune(name),
            }
        return result


# =============================================================================
# Pipeline Orchestrator
# =============================================================================

class Pipeline:
    def __init__(self, output_dir: Path = DEFAULT_OUTPUT_DIR, dry_run: bool = False,
                 verbose: bool = False, use_llm: bool = False, llm_model: str = "qwen3:30b",
                 min_occurrences: int = MIN_OCCURRENCES, incremental: bool = False):
        self.output_dir = output_dir
        self.dry_run = dry_run
        self.verbose = verbose
        self.use_llm = use_llm
        self.llm_model = llm_model
        self.min_occurrences = min_occurrences
        self.incremental = incremental
        self.ingestion = Ingestion(verbose=verbose)
        self.learning = Learning(verbose=verbose, min_occurrences=min_occurrences)
        self.consolidation = Consolidation(verbose=verbose, use_llm=use_llm, llm_model=llm_model)
        self.writer = SkillWriter(output_dir, dry_run=dry_run, verbose=verbose)
        self.feedback = FeedbackTracker(verbose=verbose)

    @staticmethod
    def _dedup_within_sessions(corrections: List[RawCorrection]) -> List[RawCorrection]:
        """Remove near-duplicate corrections within the same session.
        
        Two corrections are duplicates if they share the same session_id and
        their texts are identical after normalization (lowercase, stripped).
        This prevents a single repeated correction from inflating group counts.
        """
        seen: Dict[Tuple[str, str], RawCorrection] = {}
        for c in corrections:
            key = (c.session_id, c.raw_text.lower().strip())
            # Keep the first occurrence (earliest timestamp)
            if key not in seen:
                seen[key] = c
        return list(seen.values())

    def run(self, harness: str = "all") -> Dict:
        # Stage 1: Ingestion
        if self.verbose:
            print("\n=== Stage 1: Ingestion ===")
        all_corrections = []
        existing: List[RawCorrection] = []
        
        if self.incremental:
            last_extracted = self.get_last_extracted(harness)
            if last_extracted > 0:
                print(f"  [INCREMENTAL] Last extraction: {datetime.fromtimestamp(last_extracted)}")
            input_sources = self.find_new_files(harness, last_extracted)
            if not input_sources:
                print("No new conversation history since last extraction.")
                return {"corrections": 0, "groups": 0, "skills_written": 0, "archived": 0}
            # Load existing corrections for incremental clustering
            existing = self.load_existing_corrections(harness)
            if existing and self.verbose:
                print(f"  Loaded {len(existing)} existing corrections for re-clustering")
            all_corrections.extend(existing)
        else:
            input_sources = self._find_input_sources(harness)
            if not input_sources:
                print("No conversation history found for selected harness(es).")
                return {"corrections": 0, "groups": 0, "skills_written": 0, "archived": 0}

        for h_name, h_path in input_sources:
            if self.verbose:
                print(f"  Loading: {h_name} from {h_path}")
            conversations = self.ingestion.load_conversations(h_path)
            corrections = self.ingestion.extract_corrections(conversations, harness=h_name)
            all_corrections.extend(corrections)
            if self.verbose:
                print(f"  Found {len(corrections)} new corrections from {h_name}")
        
        new_count = len(all_corrections) - (len(existing) if self.incremental else 0)
        print(f"Stage 1: {new_count} new corrections extracted (total: {len(all_corrections)})")

        # Stage 1.5: Session-level deduplication
        if self.verbose:
            print("\n=== Stage 1.5: Deduplication ===")
        all_corrections = self._dedup_within_sessions(all_corrections)
        if self.verbose:
            print(f"  After dedup: {len(all_corrections)} unique corrections")

        # Stage 2: Learning
        if self.verbose:
            print("\n=== Stage 2: Learning ===")
        groups = self.learning.group_corrections(all_corrections)
        if self.verbose:
            print(f"  Grouped into {len(groups)} pattern groups")
        passing = self.learning.apply_thresholds(groups)
        print(f"Stage 2: {len(passing)}/{len(groups)} groups pass thresholds (freq≥{self.min_occurrences}, conf≥{MIN_CONFIDENCE})")

        # Stage 3: Consolidation (LLM-only abstraction)
        if self.verbose:
            print("\n=== Stage 3: Consolidation ===")
        deduped = self.consolidation.deduplicate(passing)
        if self.verbose:
            print(f"  After dedup: {len(deduped)} groups")

        # Abstract every group via LLM distillation (no keyword templates)
        if deduped:
            max_workers = 8
            print(f"\n  Abstracting {len(deduped)} groups via LLM distillation (parallel, max {max_workers} workers)...")
            start_time = time.time()
            completed = 0
            lock = __import__('threading').Lock()

            def _abstract_one(group: PatternGroup) -> PatternGroup:
                return self.consolidation.abstract_group(group)

            # Parallelize LLM calls — urllib HTTP requests are thread-safe
            with ThreadPoolExecutor(max_workers=max_workers) as executor:
                future_to_group = {executor.submit(_abstract_one, g): g for g in deduped}
                for future in as_completed(future_to_group):
                    group = future.result()
                    with lock:
                        completed += 1
                        elapsed = time.time() - start_time
                        avg = elapsed / completed if completed else 0
                        remaining = (len(deduped) - completed) * avg / max_workers
                        eta_m = int(remaining // 60)
                        eta_s = int(remaining % 60)
                        status = f"[{completed}/{len(deduped)}] {avg:.1f}s avg"
                        if group.condition:
                            status += f" | {group.condition[:40]}..."
                        if completed % 5 == 0 or completed == len(deduped):
                            print(f"  {status} (ETA: {eta_m}m {eta_s}s)")
                        elif self.verbose:
                            print(f"  {status}")
                    # Replace the original group in the list with the abstracted one
                    for i, g in enumerate(deduped):
                        if g.id == group.id:
                            deduped[i] = group
                            break

        skills_to_write = []
        rejected = 0
        reject_reasons = defaultdict(int)
        for group in deduped:
            if not self.consolidation.is_generalizable(group):
                reject_reasons["not_generalizable"] += 1
                rejected += 1
                continue
            if group.scope == "per-project":
                if self.verbose:
                    print(f"  [SKIP] per-project scope: {group.condition[:60]}...")
                reject_reasons["per_project"] += 1
                rejected += 1
                continue
            # Quality gate: reject empty abstractions
            if not group.condition:
                reject_reasons["no_condition"] += 1
                rejected += 1
                continue
            if not group.strategy:
                reject_reasons["no_strategy"] += 1
                rejected += 1
                continue
            # Condition must be specific enough (>30 chars)
            if len(group.condition) < 30:
                reject_reasons["vague_condition"] += 1
                rejected += 1
                continue
            # Condition must not be truncated mid-word (stricter validation)
            if not self.consolidation._validate_complete(group.condition, "condition"):
                if self.verbose:
                    print(f"  [REJECT] {group.id}: condition truncated/incomplete: {group.condition[:60]}...")
                reject_reasons["truncated_condition"] += 1
                rejected += 1
                continue
            if not self.consolidation._validate_complete(group.strategy, "strategy"):
                if self.verbose:
                    print(f"  [REJECT] {group.id}: strategy truncated/incomplete: {group.strategy[:60]}...")
                reject_reasons["truncated_strategy"] += 1
                rejected += 1
                continue
            if group.anti_pattern and not self.consolidation._validate_complete(group.anti_pattern, "anti_pattern"):
                if self.verbose:
                    print(f"  [REJECT] {group.id}: anti_pattern truncated: {group.anti_pattern[:60]}...")
                group.anti_pattern = ""  # Accept without anti_pattern rather than reject
            # Cross-project filter removed: domain-specific skills are valuable even
            # if learned from one project. Confidence scoring (project_bonus in
            # compute_confidence) already penalizes single-project skills naturally.
            skills_to_write.append(group)
        print(f"Stage 3: {len(skills_to_write)} skills after dedup+generalize ({rejected} rejected)")
        if self.verbose and reject_reasons:
            print(f"  Rejection reasons: {dict(reject_reasons)}")
        if self.use_llm:
            print(f"  LLM distillation active ({'cloud' if 'cloud' in (self.consolidation.llm_model or '') else 'local'})")
        else:
            print(f"  [WARN] --llm not enabled; all skills will be rejected (LLM is required in v3)")

        # Stage 4: Output
        if self.verbose:
            print("\n=== Stage 4: Output ===")
        written = self.writer.write_skills(skills_to_write)
        print(f"Stage 4: {len(written)} SKILL.md files written")

        # Update usage tracking
        for skill_file in self.output_dir.glob("*.md"):
            if skill_file.name.startswith(".") or skill_file.name == "SKILL.md":
                continue
            self.feedback.record_load(skill_file.stem)
        self.feedback.save()

        # Save corrections cache and timestamp for incremental extraction
        if self.incremental and not self.dry_run:
            self.save_corrections_cache(all_corrections, harness)
            self.set_last_extracted(harness)

        return {
            "corrections": len(all_corrections),
            "groups": len(groups),
            "passing": len(passing),
            "deduped": len(deduped),
            "skills_written": len(written),
            "rejected": rejected,
        }

    def _find_input_sources(self, harness: str) -> List[Tuple[str, Path]]:
        sources = []
        if harness in ("claude", "all"):
            for p in CLAUDE_HISTORY_PATHS:
                if p.exists():
                    sources.append(("claude", p))
                    break
        if harness in ("codex", "all"):
            for p in CODEX_HISTORY_PATHS:
                if p.exists():
                    sources.append(("codex", p))
                    break
        if harness in ("openclaw", "all"):
            for p in OPENCLAW_HISTORY_PATHS:
                if p.exists():
                    sources.append(("openclaw", p))
                    break
        if harness in ("pi", "all"):
            for p in PI_HISTORY_PATHS:
                if p.exists():
                    sources.append(("pi", p))
                    break
        if self.verbose:
            if not sources:
                print("  No input sources found. Searched:")
                print(f"    Claude:  {CLAUDE_HISTORY_PATHS}")
                print(f"    Codex:   {CODEX_HISTORY_PATHS}")
                print(f"    OpenClaw:{OPENCLAW_HISTORY_PATHS}")
                print(f"    Pi:      {PI_HISTORY_PATHS}")
            else:
                for name, path in sources:
                    print(f"  Found: {name} → {path}")
        return sources

    def find_new_files(self, harness: str, last_extracted: float) -> List[Tuple[str, Path]]:
        """Filter input sources to only files modified since last_extracted timestamp."""
        all_sources = self._find_input_sources(harness)
        new_sources = []
        for name, path in all_sources:
            try:
                mtime = path.stat().st_mtime
                if mtime > last_extracted:
                    new_sources.append((name, path))
                elif self.verbose:
                    print(f"  [SKIP] {path} — older than last extraction ({datetime.fromtimestamp(last_extracted)})")
            except OSError:
                continue
        return new_sources

    def load_existing_corrections(self, harness: str) -> List[RawCorrection]:
        """Load previously extracted corrections from cache file for incremental clustering."""
        cache_file = self.output_dir / f"{harness}_corrections_cache.json"
        if not cache_file.exists():
            return []
        try:
            with open(cache_file, "r") as f:
                data = json.load(f)
            corrections = []
            for item in data:
                ts = item.get("timestamp")
                if isinstance(ts, str):
                    try:
                        ts = datetime.fromisoformat(ts)
                    except ValueError:
                        ts = None
                corrections.append(RawCorrection(
                    memory_type=item["memory_type"],
                    raw_text=item["raw_text"],
                    timestamp=ts,
                    harness=item["harness"],
                    project=item.get("project", ""),
                    session_id=item.get("session_id", ""),
                ))
            return corrections
        except (json.JSONDecodeError, KeyError) as e:
            if self.verbose:
                print(f"  [WARN] Failed to load correction cache: {e}")
            return []

    def save_corrections_cache(self, corrections: List[RawCorrection], harness: str):
        """Save corrections to a cache file for incremental extraction."""
        cache_file = self.output_dir / f"{harness}_corrections_cache.json"
        data = []
        for c in corrections:
            data.append({
                "memory_type": c.memory_type,
                "raw_text": c.raw_text,
                "timestamp": c.timestamp.isoformat() if c.timestamp else None,
                "harness": c.harness,
                "project": c.project,
                "session_id": c.session_id,
            })
        with open(cache_file, "w") as f:
            json.dump(data, f, indent=2)

    def get_last_extracted(self, harness: str) -> float:
        """Get the timestamp of last successful extraction for a harness."""
        state_file = self.output_dir / f".{harness}_last_extracted"
        if state_file.exists():
            try:
                with open(state_file, "r") as f:
                    return float(f.read().strip())
            except (ValueError, OSError):
                pass
        return 0.0

    def set_last_extracted(self, harness: str):
        """Record the current timestamp as last successful extraction."""
        state_file = self.output_dir / f".{harness}_last_extracted"
        with open(state_file, "w") as f:
            f.write(str(time.time()))


# =============================================================================
# CLI
# =============================================================================

def main():
    import argparse

    parser = argparse.ArgumentParser(
        description="Extract generalizable skills from conversation history (4-stage ALMA-inspired pipeline)",
    )
    parser.add_argument("--input", type=Path, default=None)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--harness", choices=["claude", "codex", "openclaw", "pi", "all"], default="all")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--llm", action="store_true",
                        help="Use local Ollama model for distillation (falls back to keyword-based if unavailable)")
    parser.add_argument("--llm-model", default="qwen3:30b",
                        help="Ollama model for LLM distillation (default: qwen3:30b)")
    parser.add_argument("--min-occurrences", type=int, default=MIN_OCCURRENCES,
                        help=f"Minimum unique sessions to form a skill (default: {MIN_OCCURRENCES})")
    parser.add_argument("--stats", action="store_true",
                        help="Show usage/decay statistics for existing learned skills")
    parser.add_argument("--prune", action="store_true",
                        help="Archive decayed/low-quality skills")
    parser.add_argument("--incremental", action="store_true",
                        help="Only process new conversation files since last extraction")

    args = parser.parse_args()
    
    # Auto-install dependencies and auto-enable LLM if Ollama is available
    _ensure_deps(verbose=args.verbose)
    
    if not args.llm:
        # Check if Ollama is available
        import shutil
        if shutil.which("ollama"):
            args.llm = True
            print("  [INFO] Ollama detected; auto-enabling --llm (LLM distillation required)")
        else:
            print("  [WARN] Ollama not found; pipeline will produce 0 skills (LLM distillation required)")
            print("         Install Ollama or run with --llm if using a different LLM backend")

    if args.stats:
        feedback = FeedbackTracker(verbose=args.verbose)
        stats = feedback.stats()
        if not stats:
            print("No usage data found.")
            return 0
        print("\nLearned Skills Usage Statistics")
        print("=" * 60)
        for name, s in sorted(stats.items()):
            status = "PRUNE" if s["should_prune"] else "OK"
            print(f"  {name:40s} feedback={s['feedback_score']:.2f}  decay={s['decay_factor']:.2f}  {status}")
        return 0

    if args.prune:
        feedback = FeedbackTracker(verbose=args.verbose)
        archived = feedback.prune_skills(args.output, dry_run=args.dry_run)
        if not args.dry_run:
            feedback.save()
        print(f"Archived {len(archived)} decayed skills")
        return 0

    print("\n╔══════════════════════════════════════════════════════════╗")
    print("║   Skills Extractor — ALMA-Inspired Pipeline          ║")
    print("╚══════════════════════════════════════════════════════════╝")
    print(f"  Harness: {args.harness}")
    print(f"  Output: {args.output}")
    min_occ = args.min_occurrences
    print(f"  Min occurrences: {min_occ} | Min confidence: {MIN_CONFIDENCE}")

    pipeline = Pipeline(output_dir=args.output, dry_run=args.dry_run, verbose=args.verbose,
                        use_llm=args.llm, llm_model=args.llm_model, min_occurrences=min_occ,
                        incremental=args.incremental)
    results = pipeline.run(harness=args.harness)

    print("\n" + "=" * 60)
    print("Pipeline Summary")
    print("-" * 60)
    for k, v in results.items():
        print(f"  {k}: {v}")
    print("=" * 60)

    if args.dry_run:
        print("\n[DRY RUN] No files written.")

    return 0


if __name__ == "__main__":
    main()