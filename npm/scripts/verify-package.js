#!/usr/bin/env node

"use strict";

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const projectRoot = path.resolve(__dirname, "..", "..");
const packageData = JSON.parse(fs.readFileSync(path.join(projectRoot, "package.json"), "utf8"));
const appPath = path.join(projectRoot, "dist", "CopyCue.app");
const executablePath = path.join(appPath, "Contents", "MacOS", "CopyCue");
const plistPath = path.join(appPath, "Contents", "Info.plist");
const iconPath = path.join(appPath, "Contents", "Resources", "AppIcon.icns");

function run(command, args) {
  const result = spawnSync(command, args, { encoding: "utf8" });
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    throw new Error(result.stderr.trim() || `${path.basename(command)} failed`);
  }
  return result.stdout.trim();
}

if (!fs.existsSync(executablePath) || !fs.existsSync(plistPath) || !fs.existsSync(iconPath)) {
  throw new Error("CopyCue.app is incomplete; run npm run build:app first");
}

const stagingDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "copycue-package-verify-"));
const stagedApp = path.join(stagingDirectory, "CopyCue.app");
const stagedExecutable = path.join(stagedApp, "Contents", "MacOS", "CopyCue");
const stagedPlist = path.join(stagedApp, "Contents", "Info.plist");
const stagedIcon = path.join(stagedApp, "Contents", "Resources", "AppIcon.icns");

try {
  run("/bin/cp", ["-R", "-X", appPath, stagedApp]);

  const appVersion = run(
    "/usr/bin/plutil",
    ["-extract", "CFBundleShortVersionString", "raw", "-o", "-", stagedPlist]
  );
  if (appVersion !== packageData.version) {
    throw new Error(`package version ${packageData.version} does not match app version ${appVersion}`);
  }

  const iconName = run(
    "/usr/bin/plutil",
    ["-extract", "CFBundleIconFile", "raw", "-o", "-", stagedPlist]
  );
  if (iconName !== "AppIcon" || !fs.existsSync(stagedIcon)) {
    throw new Error("CopyCue app icon is missing or is not declared in Info.plist");
  }

  const architecture = run("/usr/bin/file", [stagedExecutable]);
  if (!architecture.includes("arm64")) {
    throw new Error("CopyCue executable is missing the required arm64 architecture");
  }

  run("/usr/bin/codesign", ["--verify", "--deep", "--strict", stagedApp]);
  console.log(`Verified ${packageData.name}@${packageData.version} (${architecture})`);
} finally {
  fs.rmSync(stagingDirectory, { recursive: true, force: true });
}
