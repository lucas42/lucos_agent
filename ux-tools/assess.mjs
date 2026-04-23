#!/usr/bin/env node
/**
 * lucos UX assessment helper.
 *
 * Usage:
 *   node ~/sandboxes/lucos_agent/ux-tools/assess.mjs <base-url> [output-dir] [path1 path2 ...]
 *
 * Takes screenshots of pages at the given base URL and saves them to output-dir
 * (defaults to /tmp/ux-screenshots). Pass additional paths as extra arguments.
 *
 * Examples:
 *   node ~/sandboxes/lucos_agent/ux-tools/assess.mjs http://localhost:8036 /tmp/photos-ux
 *   node ~/sandboxes/lucos_agent/ux-tools/assess.mjs http://localhost:8036 /tmp/photos-ux / /photos /people
 *
 * For lucos_photos and other services with bearer-token auth on HTML routes,
 * set the Authorization header via the AUTH_TOKEN env var:
 *   AUTH_TOKEN=zSicQqvD8kQNI3ObFNzJTenrmwYUihNx node ~/sandboxes/lucos_agent/ux-tools/assess.mjs ...
 *   (find the token in the project's .env under CLIENT_KEYS)
 */

import { chromium } from 'playwright';
import { mkdir } from 'fs/promises';

const [,, baseUrl, outputDirArg, ...extraPaths] = process.argv;

if (!baseUrl) {
    console.error('Usage: assess.mjs <base-url> [output-dir] [path1 path2 ...]');
    process.exit(1);
}

const outputDir = outputDirArg || '/tmp/ux-screenshots';
const paths = extraPaths.length > 0 ? extraPaths : ['/'];
const authToken = process.env.AUTH_TOKEN;

await mkdir(outputDir, { recursive: true });

const browser = await chromium.launch();
const context = await browser.newContext({
    viewport: { width: 1280, height: 900 },
    extraHTTPHeaders: authToken ? { 'Authorization': `Bearer ${authToken}` } : {},
});

for (const pagePath of paths) {
    const url = baseUrl.replace(/\/$/, '') + pagePath;
    const page = await context.newPage();

    try {
        await page.goto(url, { waitUntil: 'networkidle', timeout: 15000 });
        const safeName = pagePath.replace(/\//g, '_').replace(/^_/, '') || 'root';
        const screenshotPath = `${outputDir}/${safeName}.png`;
        await page.screenshot({ path: screenshotPath, fullPage: true });
        console.log(`Screenshot: ${screenshotPath}`);
    } catch (err) {
        console.error(`Failed to load ${url}: ${err.message}`);
    } finally {
        await page.close();
    }
}

await browser.close();
