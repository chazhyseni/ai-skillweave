#!/usr/bin/env node
/*
 * copilot-frontmatter-probe.js
 *
 * Direct probe of GitHub Copilot CLI's bundled frontmatter parser.
 * Walks ~/.copilot/skills/ recursively (following symlinks), asks the
 * addon's `promptsParseFrontmatter` function on every SKILL.md, and
 * prints the failures.
 *
 * Why this exists: the canonical source-of-truth for "does this SKILL.md
 * load in Copilot" is the bundled runtime addon, not the loader/CLI
 * wrapper. The addon is a native node addon (.node file) shipped inside
 * the @github/copilot npm package. Its location varies by install
 * method (nvm vs global vs npm prefix) and platform (Linux/macOS/Windows).
 *
 * Usage:
 *   node scripts/copilot-frontmatter-probe.js
 *   node scripts/copilot-frontmatter-probe.js --limit 50
 *   node scripts/copilot-frontmatter-probe.js --skill-path ~/.copilot/skills
 *
 * Exit code: 0 if every SKILL.md parses, 1 otherwise.
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

function findAddon() {
  // Common install locations, in priority order.
  const candidates = [];
  const tryPaths = (p) => {
    if (!p) return;
    try {
      const stat = fs.statSync(p);
      if (stat.isFile()) candidates.push(p);
    } catch {}
  };
  // npm root global
  try {
    const { execSync } = require('child_process');
    const root = execSync('npm root -g', { encoding: 'utf-8' }).trim();
    tryPaths(path.join(root, '@github', 'copilot', 'prebuilds',
      `${process.platform}-${process.arch}`, 'runtime.node'));
  } catch {}
  // Common nvm layout
  const home = os.homedir();
  const nvmNodeVersions = path.join(home, '.nvm', 'versions', 'node');
  if (fs.existsSync(nvmNodeVersions)) {
    for (const v of fs.readdirSync(nvmNodeVersions)) {
      tryPaths(path.join(nvmNodeVersions, v, 'lib', 'node_modules',
        '@github', 'copilot', 'prebuilds',
        `${process.platform}-${process.arch}`, 'runtime.node'));
    }
  }
  // Common global node_modules locations, derived from $HOME so this
  // works on macOS and Linux without hardcoded /Users/ or /home/ paths.
  for (const sub of [
    path.join('usr', 'local', 'lib', 'node_modules'),
    path.join('usr', 'lib', 'node_modules'),
    path.join(home, '.npm-global', 'lib', 'node_modules'),
    path.join(home, '.yarn', 'global', 'node_modules'),
  ]) {
    tryPaths(path.join(sub, '@github', 'copilot', 'prebuilds',
      `${process.platform}-${process.arch}`, 'runtime.node'));
  }
  return candidates[0];
}

function walkSkills(dir, out) {
  let entries;
  try { entries = fs.readdirSync(dir, { withFileTypes: true }); }
  catch (e) { return; }
  for (const e of entries) {
    const full = path.join(dir, e.name);
    if (e.isSymbolicLink()) {
      let real;
      try { real = fs.realpathSync(full); } catch { continue; }
      let stat;
      try { stat = fs.statSync(real); } catch { continue; }
      if (stat.isDirectory()) walkSkills(real, out);
      else if (e.name === 'SKILL.md') out.add(real);
    } else if (e.isDirectory()) {
      walkSkills(full, out);
    } else if (e.name === 'SKILL.md') {
      out.add(full);
    }
  }
}

function parseArgs() {
  const args = { skillPath: null, limit: 30 };
  for (let i = 2; i < process.argv.length; i++) {
    const a = process.argv[i];
    if (a === '--skill-path') args.skillPath = process.argv[++i];
    else if (a === '--limit') args.limit = parseInt(process.argv[++i], 10);
    else if (a === '--help' || a === '-h') {
      console.log('Usage: node scripts/copilot-frontmatter-probe.js [--skill-path DIR] [--limit N]');
      process.exit(0);
    }
  }
  return args;
}

function main() {
  const args = parseArgs();

  // Print environment so failures can be correlated across machines.
  console.log('=== Environment ===');
  console.log(`OS:            ${os.platform()} ${os.release()} (${os.arch()})`);
  console.log(`Node:          ${process.version}`);
  console.log(`Copilot CLI:   ${(function () {
    try { return require('@github/copilot/package.json').version; }
    catch { return 'not found via require'; }
  })()}`);

  const addonPath = findAddon();
  if (!addonPath) {
    console.error('Could not locate @github/copilot bundled addon.');
    console.error('Tried: npm root -g, ~/.nvm/versions/node/*/lib/node_modules, common global prefixes.');
    console.error('Install Copilot CLI: npm install -g @github/copilot');
    process.exit(2);
  }
  console.log(`Addon:         ${addonPath}`);
  console.log(`Addon size:    ${fs.statSync(addonPath).size} bytes`);
  let addon;
  try {
    addon = require(addonPath);
  } catch (e) {
    console.error(`Failed to load addon: ${e.message}`);
    process.exit(2);
  }
  if (typeof addon.promptsParseFrontmatter !== 'function') {
    console.error(`Addon loaded but promptsParseFrontmatter is not a function.`);
    console.error(`Available exports: ${Object.keys(addon).join(', ')}`);
    process.exit(2);
  }

  const skillDir = args.skillPath || path.join(os.homedir(), '.copilot', 'skills');
  console.log(`Skills dir:    ${skillDir}`);
  if (!fs.existsSync(skillDir)) {
    console.error(`Skills dir does not exist: ${skillDir}`);
    process.exit(2);
  }

  const files = new Set();
  walkSkills(skillDir, files);
  const all = [...files].sort();
  console.log(`Files probed:  ${all.length}`);

  let ok = 0;
  let failed = 0;
  const failures = [];
  for (const f of all) {
    let text;
    try { text = fs.readFileSync(f, 'utf-8'); } catch { continue; }
    let r;
    try { r = addon.promptsParseFrontmatter(text); }
    catch (e) { failed++; failures.push({ f, msg: `addon threw: ${e.message}`, head: text.slice(0, 120) }); continue; }
    if (r && r.ok) ok++;
    else { failed++; failures.push({ f, msg: (r && r.errorMessage) || 'unknown', head: text.slice(0, 120) }); }
  }

  console.log(`OK:            ${ok}`);
  console.log(`Failed:        ${failed}`);

  if (failures.length) {
    console.log(`\nFirst ${Math.min(args.limit, failures.length)} failures:`);
    for (const f of failures.slice(0, args.limit)) {
      console.log(`\n  ${f.f}`);
      console.log(`    msg:  ${f.msg}`);
      console.log(`    head: ${JSON.stringify(f.head)}`);
    }
  }
  process.exit(failed === 0 ? 0 : 1);
}

main();
