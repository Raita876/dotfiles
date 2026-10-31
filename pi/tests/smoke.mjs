import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const [piRoot, pioliumRoot] = process.argv.slice(2);
assert.ok(piRoot && pioliumRoot, "Usage: node pi/tests/smoke.mjs <Pi package root> <patched Piolium package root>");
const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const load = (path) => import(pathToFileURL(join(resolve(piRoot), "dist/core", path)).href);
const { loadSkillsFromDir } = await load("skills.js");
const { loadPromptTemplates, expandPromptTemplate } = await load("prompt-templates.js");
const { loadExtensions } = await load("extensions/loader.js");
const temporary = mkdtempSync(join(tmpdir(), "pi-review-smoke-"));

try {
  const { skills, diagnostics } = loadSkillsFromDir({ dir: join(root, "skills"), source: "user" });
  assert.deepEqual(diagnostics, []);
  assert.equal(skills.length, 1);
  assert.equal(skills[0].name, "pr-review");
  const skill = readFileSync(join(root, "skills/pr-review/SKILL.md"), "utf8");
  for (const name of ["scope", "report", "code", "tests", "errors", "comments", "types", "simplify"]) {
    assert.ok(skill.includes(`references/${name}.md`));
    assert.ok(readFileSync(join(root, `skills/pr-review/references/${name}.md`), "utf8").trim());
  }
  assert.ok(skill.includes('agent: "reviewer"'));

  const prompts = loadPromptTemplates({
    cwd: temporary,
    agentDir: temporary,
    promptPaths: [join(root, "prompts")],
    includeDefaults: false,
  });
  assert.deepEqual(prompts.diagnostics, []);
  assert.deepEqual(prompts.templates.map((item) => item.name), ["review-pr"]);
  for (const args of ["", "tests errors --base main sequential", "all simplify --pr 123 parallel"]) {
    const expanded = expandPromptTemplate(`/review-pr${args ? ` ${args}` : ""}`, prompts.templates);
    assert.ok(expanded.includes("~/.pi/agent/skills/pr-review/SKILL.md"));
    assert.ok(!expanded.includes("$ARGUMENTS"));
    assert.ok(expanded.includes(`<review-options>\n${args}\n</review-options>`));
  }

  process.env.PIOLIUM_VERTEX = "0";
  const packageRoot = resolve(pioliumRoot);
  const manifest = JSON.parse(readFileSync(join(packageRoot, "package.json"), "utf8"));
  assert.equal(manifest.version, "0.0.15");
  const runner = readFileSync(join(packageRoot, "extensions/piolium/agent-runner.ts"), "utf8");
  const policy = readFileSync(join(root, "piolium-policy.md"), "utf8");
  const injected = runner.match(/const composedSystemPrompt = ("(?:[^"\\]|\\.)*")\s*\+\s*"\\n\\n"\s*\+/);
  assert.ok(injected, "Missing policy prefix in agent-runner");
  assert.equal(JSON.parse(injected[1]), policy);
  const result = await loadExtensions([join(packageRoot, "extensions/piolium/index.ts")], temporary);
  assert.deepEqual(result.errors, []);
  assert.equal(result.extensions.length, 1);
  const commands = result.extensions[0].commands;
  for (const command of ["piolium-help", "piolium-lite", "piolium-balanced", "piolium-deep", "piolium-diff"]) {
    assert.ok(commands.has(command), `Missing command: ${command}`);
  }
  assert.ok(!commands.has("review-pr"));
  console.log(`OK: skill, 8 references, 3 prompt expansions, policy injection, ${commands.size} Piolium commands`);
  console.log("No audit commands or model requests were executed.");
} finally {
  rmSync(temporary, { recursive: true, force: true });
}
