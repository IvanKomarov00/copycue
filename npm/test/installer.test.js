"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const test = require("node:test");

const projectRoot = path.resolve(__dirname, "..", "..");
const cliPath = path.join(projectRoot, "npm", "bin", "copycue.js");

function runCli(args, environment = {}) {
  return spawnSync(process.execPath, [cliPath, ...args], {
    cwd: projectRoot,
    encoding: "utf8",
    env: { ...process.env, ...environment }
  });
}

test("prints installer help", () => {
  const result = runCli(["--help"]);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /copycue install/);
  assert.match(result.stdout, /~\/Applications\/CopyCue\.app/);
});

test("prints the package version", () => {
  const result = runCli(["--version"]);
  const packageData = require(path.join(projectRoot, "package.json"));
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout.trim(), packageData.version);
});

test(
  "installs, safely updates, and uninstalls the bundled app",
  { skip: process.platform !== "darwin" || process.arch !== "arm64" },
  () => {
    const temporaryHome = fs.mkdtempSync(path.join(os.tmpdir(), "copycue-npm-test-"));
    const installDirectory = path.join(temporaryHome, "Applications");
    const installedApp = path.join(installDirectory, "CopyCue.app");
    const environment = { HOME: temporaryHome };

    try {
      const firstInstall = runCli(["install", "--no-open"], environment);
      assert.equal(firstInstall.status, 0, firstInstall.stderr);
      assert.equal(fs.existsSync(installedApp), true);

      const markerPath = path.join(installedApp, "Contents", "test-update-marker");
      fs.writeFileSync(markerPath, "old installation");

      const update = runCli(["install", "--no-open"], environment);
      assert.equal(update.status, 0, update.stderr);
      assert.equal(fs.existsSync(markerPath), false, "an update must replace instead of merge bundles");

      const signature = spawnSync(
        "/usr/bin/codesign",
        ["--verify", "--deep", "--strict", installedApp],
        { encoding: "utf8" }
      );
      assert.equal(signature.status, 0, signature.stderr);

      const removal = runCli(["uninstall"], environment);
      assert.equal(removal.status, 0, removal.stderr);
      assert.equal(fs.existsSync(installedApp), false);
    } finally {
      fs.rmSync(temporaryHome, { recursive: true, force: true });
    }
  }
);
