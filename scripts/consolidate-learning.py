#!/usr/bin/env python3
"""
BMO-Style Learning Consolidation
Converts captured learning events into skills at session end.
Based on: https://github.com/joelhans/bmo-agent
"""

import json
import os
import re
from pathlib import Path
from collections import defaultdict
from datetime import datetime

LEARNINGS_DIR = Path.home() / ".claude" / "skills" / "learned" / "events"
SKILLS_DIR = Path.home() / ".claude" / "skills" / "learned"

def load_events():
    """Load all pending learning events."""
    events = []
    if not LEARNINGS_DIR.exists():
        return events
    
    for f in LEARNINGS_DIR.glob("*.json"):
        try:
            with open(f) as fp:
                data = json.load(fp)
                if data.get("status") == "pending":
                    events.append(data)
        except Exception:
            continue

def cluster_events(events):
    """
    Cluster similar events together.
    Uses sentence-transformer semantic similarity when available,
    falling back to Jaccard word overlap.
    """
    if not events:
        return {}
    
    # Try semantic clustering with sentence-transformers
    # Safety: probe import in a subprocess first to avoid SIGABRT from abseil-cpp/pyarrow
    # version conflicts (uncatchable in Python).
    if len(events) >= 5:
        import subprocess, sys
        probe = subprocess.run(
            [sys.executable, "-c", "from sentence_transformers import SentenceTransformer"],
            capture_output=True, timeout=10
        )
        if probe.returncode == 0:
            try:
                from sentence_transformers import SentenceTransformer
                import numpy as np
                
                texts = [e.get("message", "") for e in events]
                encoder = SentenceTransformer('all-MiniLM-L6-v2')
                embeddings = encoder.encode(texts, show_progress_bar=False)
                
                # Normalize
                norms = np.linalg.norm(embeddings, axis=1, keepdims=True)
                norms[norms == 0] = 1
                embeddings = embeddings / norms
                
                clusters = []
                used = set()
                for i in range(len(events)):
                    if i in used:
                        continue
                    cluster = [events[i]]
                    used.add(i)
                    for j in range(i + 1, len(events)):
                        if j in used:
                            continue
                        sim = float(np.dot(embeddings[i], embeddings[j]))
                        if sim >= 0.72:
                            cluster.append(events[j])
                            used.add(j)
                    # Cluster key: type + first 3 words of first event
                    first_msg = events[i].get("message", "")
                    words = re.findall(r"\b\w+\b", first_msg.lower())
                    key_words = [w for w in words[:3] if len(w) > 3]
                    cluster_key = f"{events[i].get('type', 'unknown')}_{'-'.join(key_words) or 'general'}"
                    clusters.append((cluster_key, cluster))
                
                return dict(clusters)
            except ImportError:
                pass  # Fall through to keyword-based clustering
            except Exception:
                pass  # Fall through on any error
    
    # Fallback: improved keyword-based clustering with Jaccard similarity
    stop_words = {
        "the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
        "have", "has", "had", "do", "does", "did", "will", "would", "could",
        "should", "may", "might", "must", "shall", "can", "need", "dare",
        "ought", "used", "to", "of", "in", "for", "on", "with", "at", "by",
        "from", "as", "into", "through", "during", "before", "after", "above",
        "below", "between", "under", "again", "further", "then", "once", "that",
        "this", "these", "those", "i", "you", "he", "she", "it", "we", "they",
        "what", "which", "who", "whom", "whose", "where", "when", "why", "how",
        "all", "each", "every", "both", "few", "more", "most", "other", "some",
        "such", "no", "nor", "not", "only", "own", "same", "so", "than", "too",
        "very", "just", "also", "now", "here", "there", "if", "but", "or", "and",
    }
    
    def get_keywords(msg):
        words = re.findall(r"\b\w+\b", msg.lower())
        return set(w for w in words if len(w) > 3 and w not in stop_words)
    
    clusters = []
    used = set()
    for i in range(len(events)):
        if i in used:
            continue
        cluster = [events[i]]
        used.add(i)
        kw_i = get_keywords(events[i].get("message", ""))
        
        for j in range(i + 1, len(events)):
            if j in used:
                continue
            kw_j = get_keywords(events[j].get("message", ""))
            union = kw_i | kw_j
            inter = kw_i & kw_j
            sim = len(inter) / len(union) if union else 0
            if sim >= 0.5:
                cluster.append(events[j])
                used.add(j)
                kw_i |= kw_j  # Merge keywords for transitive clustering
        
        first_msg = events[i].get("message", "")
        words = re.findall(r"\b\w+\b", first_msg.lower())
        key_words = [w for w in words[:3] if len(w) > 3]
        cluster_key = f"{events[i].get('type', 'unknown')}_{'-'.join(key_words) or 'general'}"
        clusters.append((cluster_key, cluster))
    
    return dict(clusters)

def create_skill(cluster_name, events):
    """Create a skill from a cluster of events."""
    if not events:
        return None
    
    messages = [e.get("message", "") for e in events]
    event_type = events[0].get("type", "pattern")
    projects = set(e.get("project", "unknown") for e in events)
    sessions = set(e.get("session", "unknown") for e in events)
    
    # Generate skill name from cluster (Codex limit: 64 chars)
    skill_name = cluster_name.replace("_", "-").replace(" ", "-")[:64]
    skill_name = skill_name.rstrip("-")
    
    # Build skill content based on type
    if event_type == "correction":
        # Extract the correction pattern
        condition = "When the user corrects your approach or output"
        strategy = messages[0][:300] if messages else "Apply the correction immediately and verify"
        anti_pattern = "Ignoring user corrections or repeating the same mistake"
        priority = "critical"
    elif event_type == "preference":
        condition = "When working on tasks involving user preferences"
        strategy = messages[0][:300] if messages else "Apply stated preferences consistently"
        anti_pattern = "N/A"
        priority = "high"
    else:  # pattern
        condition = "When encountering recurring patterns or best practices"
        strategy = messages[0][:300] if messages else "Follow established patterns"
        anti_pattern = "N/A"
        priority = "medium"
    
    # Quote description if it contains YAML-special characters
    desc = f"Learned from {len(events)} session event(s)"
    if ':' in desc or '"' in desc:
        desc = f'"{desc}"'
    evidence = "\n".join([f"- {m[:200]}" for m in messages[:5]])
    
    skill_content = f"""---
name: {skill_name}
description: {desc}
origin: bmo-learning-capture
tags: [learned, {event_type}, auto-generated]
priority: {priority}
---

# {skill_name.replace("-", " ").title()}

## When to Use

{condition}.

## Operating Principles

1. {strategy}.

"""
    if anti_pattern != "N/A":
        skill_content += f"""## Anti-patterns

- {anti_pattern}.

"""
    
    skill_content += f"""## Evidence

{evidence}

## Provenance

- **Events:** {len(events)}
- **Sessions:** {len(sessions)}
- **Projects:** {len(projects)}
- **First captured:** {events[0].get('timestamp', 'unknown')}
- **Last captured:** {events[-1].get('timestamp', 'unknown')}
"""
    
    return skill_name, skill_content

def sanitize_filename(name):
    """Create safe filename from skill name."""
    # Keep only alphanumeric, hyphens, underscores
    safe = re.sub(r'[^a-z0-9\-_]', '', name.lower())
    # Remove consecutive hyphens/underscores
    safe = re.sub(r'[-_]+', '-', safe)
    # Limit length (Codex skill name limit: 64 chars)
    return safe[:64] or "learned-skill"

def write_skill(skill_name, content):
    """Write skill to file."""
    skill_file = SKILLS_DIR / f"{sanitize_filename(skill_name)}.md"
    
    with open(skill_file, "w") as f:
        f.write(content)
    
    return skill_file

def mark_processed(events):
    """Mark events as processed."""
    for event in events:
        event_ts = event.get("timestamp")
        for f in LEARNINGS_DIR.glob("*.json"):
            try:
                with open(f) as fp:
                    data = json.load(fp)
                if data.get("timestamp") == event_ts:
                    data["status"] = "processed"
                    data["processed_at"] = datetime.now().isoformat()
                    with open(f, "w") as fp:
                        json.dump(data, fp, indent=2)
                    break
            except Exception:
                continue

def main():
    print("╔══════════════════════════════════════════════════════════╗")
    print("║   BMO-Style Learning Consolidation                      ║")
    print("╚══════════════════════════════════════════════════════════╝\n")
    
    events = load_events()
    print(f"Found {len(events)} pending learning events")
    
    if not events:
        print("No events to consolidate")
        return
    
    clusters = cluster_events(events)
    print(f"Clustered into {len(clusters)} groups\n")
    
    skills_created = 0
    for cluster_name, cluster_events in clusters.items():
        result = create_skill(cluster_name, cluster_events)
        if result:
            skill_name, content = result
            skill_file = write_skill(skill_name, content)
            print(f"✓ Created: {skill_file.name} (from {len(cluster_events)} events)")
            mark_processed(cluster_events)
            skills_created += 1
    
    print(f"\n[OK] Created {skills_created} skills from {len(events)} events")

if __name__ == "__main__":
    main()
