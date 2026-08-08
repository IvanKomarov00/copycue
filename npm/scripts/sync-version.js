#!/usr/bin/env node

"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const projectRoot = path.resolve(__dirname, "..", "..");
const packageData = JSON.parse(fs.readFileSync(path.join(projectRoot, "package.json"), "utf8"));
const plistPath = path.join(projectRoot, "Resources", "Info.plist");

const result = spawnSync(
  "/usr/bin/plutil",
  ["-replace", "CFBundleShortVersionString", "-string", packageData.version, plistPath],
  { stdio: "inherit" }
);

if (result.error) {
  throw result.error;
}
if (result.status !== 0) {
  process.exit(result.status ?? 1);
}

console.log(`Synchronized CopyCue app version to ${packageData.version}`);
