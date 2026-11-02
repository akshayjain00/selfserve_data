#!/usr/bin/env node
// THROWAWAY feasibility probe — not the MCP server.
//
// Statsig documents a pulse-results endpoint for GATES but not for EXPERIMENTS.
// This finds out whether an experiment equivalent exists on this account, and
// what its response actually looks like, before we build a server around it.
//
// Deleted once we know the answer.

import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const BASE = 'https://statsigapi.net/console/v1';
const EXPERIMENT = process.argv[2] ?? 'ptl_service_comprhension';

// --- load .env without pulling in a dependency ------------------------------
function loadEnv() {
  let raw;
  try {
    raw = readFileSync(join(HERE, '.env'), 'utf8');
  } catch {
    die('No statsig-mcp/.env found. Copy .env.example to .env and add your Console API key.');
  }
  const env = {};
  for (const line of raw.split('\n')) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)$/);
    if (m) env[m[1]] = m[2].trim().replace(/^["']|["']$/g, '');
  }
  return env;
}

function die(msg) {
  console.error(`\n  ${msg}\n`);
  process.exit(1);
}

// Never print the key itself — only enough to confirm which key is loaded.
function fingerprint(key) {
  return `${key.slice(0, 8)}…${key.slice(-4)} (${key.length} chars)`;
}

const env = loadEnv();
const KEY = env.STATSIG_CONSOLE_API_KEY;
if (!KEY) die('STATSIG_CONSOLE_API_KEY is empty in statsig-mcp/.env');
if (/^(client-|secret-)/.test(KEY)) {
  die(`That looks like an SDK key, not a Console API key (starts with "${KEY.split('-')[0]}-").\n  Console API keys are created under Project Settings → API Keys → Console API.`);
}

async function probe(label, path) {
  const url = `${BASE}${path}`;
  let res, body;
  try {
    res = await fetch(url, { headers: { 'STATSIG-API-KEY': KEY, 'Accept': 'application/json' } });
  } catch (e) {
    return { label, path, status: 'NETWORK', note: e.message };
  }
  const text = await res.text();
  try { body = JSON.parse(text); } catch { body = text.slice(0, 200); }

  let shape = '';
  if (body && typeof body === 'object') {
    const data = body.data ?? body;
    if (Array.isArray(data)) {
      shape = `array[${data.length}]` + (data[0] ? ` of {${Object.keys(data[0]).slice(0, 8).join(', ')}}` : '');
    } else if (data && typeof data === 'object') {
      shape = `{${Object.keys(data).slice(0, 14).join(', ')}}`;
    }
  } else {
    shape = String(body).slice(0, 120);
  }
  return { label, path, status: res.status, shape, body };
}

const CANDIDATES = [
  ['metadata      ', `/experiments/${EXPERIMENT}`],
  ['pulse         ', `/experiments/${EXPERIMENT}/pulse`],
  ['pulse_results ', `/experiments/${EXPERIMENT}/pulse_results`],
  ['results       ', `/experiments/${EXPERIMENT}/results`],
  ['scorecard     ', `/experiments/${EXPERIMENT}/scorecard`],
  ['metrics       ', `/experiments/${EXPERIMENT}/metrics`],
  ['list all      ', `/experiments?limit=1`],
];

console.log(`\n  key        ${fingerprint(KEY)}`);
console.log(`  experiment ${EXPERIMENT}`);
console.log(`  base       ${BASE}\n`);
console.log('  ' + '-'.repeat(76));

const results = [];
for (const [label, path] of CANDIDATES) {
  const r = await probe(label, path);
  results.push(r);
  const icon = r.status === 200 ? 'OK  ' : r.status === 404 ? 'MISS' : 'ERR ';
  console.log(`  ${icon} ${String(r.status).padEnd(8)} ${label} ${r.shape ?? r.note ?? ''}`.slice(0, 200));
}
console.log('  ' + '-'.repeat(76));

// Dump the full body of any results-ish endpoint that worked, so we can design
// the MCP tool's output against the real schema rather than a guess.
const win = results.find(r => r.status === 200 && r.label.trim() !== 'metadata' && r.label.trim() !== 'list all');
if (win) {
  console.log(`\n  FULL BODY of ${win.path}:\n`);
  console.log(JSON.stringify(win.body, null, 2).slice(0, 6000));
} else {
  const meta = results.find(r => r.label.trim() === 'metadata');
  if (meta?.status === 200) {
    console.log('\n  No results endpoint responded 200, but the key works (metadata OK).');
    console.log('  Experiment metadata:\n');
    console.log(JSON.stringify(meta.body, null, 2).slice(0, 3000));
  } else {
    console.log(`\n  Key did not authenticate. metadata returned ${meta?.status}.`);
    console.log('  Confirm the key is type "Console API" and has read access to this project.');
  }
}
console.log('');
