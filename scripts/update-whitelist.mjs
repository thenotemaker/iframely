#!/usr/bin/env node
// Refreshes whitelist-bundled/iframely-domains.json from iframely.com (the list the server downloads by default).
// Used by the monthly workflow (.github/workflows/update-whitelist.yml) and by hand: `node scripts/update-whitelist.mjs`.
// Writes nothing when the download is not a plausible list, and prints a one-line summary either way.
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const SOURCE = process.env.WHITELIST_SOURCE || 'https://iframely.com/qa/domains.json';
const TARGET = fileURLToPath(new URL('../whitelist-bundled/iframely-domains.json', import.meta.url));
const MIN_DOMAINS = 1000; // the list has ~1900; far fewer means a truncated or error response

const count = (text) => Object.keys(JSON.parse(text).domains || {}).length;

const res = await fetch(SOURCE, { headers: { 'user-agent': 'thenotemaker-iframely-whitelist-update' } });
if (!res.ok) throw new Error(`${SOURCE} answered ${res.status}`);
const next = await res.text();

let domains;
try {
    domains = count(next);
} catch (e) {
    throw new Error(`${SOURCE} did not return JSON: ${e.message}`);
}
if (domains < MIN_DOMAINS) throw new Error(`only ${domains} domains in the download, refusing to write it`);

let before = '';
let beforeCount = 0;
try {
    before = readFileSync(TARGET, 'utf8');
    beforeCount = count(before);
} catch {
    /* first run */
}

if (before === next) {
    console.log(`whitelist unchanged (${domains} domains)`);
} else {
    writeFileSync(TARGET, next);
    console.log(`whitelist updated: ${beforeCount} -> ${domains} domains`);
}
