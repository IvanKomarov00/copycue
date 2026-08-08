#!/usr/bin/env node

"use strict";

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const APP_NAME = "CopyCue.app";
const PROCESS_NAME = "CopyCue";
const BUNDLE_IDENTIFIER = "com.copycue.app";
const PACKAGE_ROOT = path.resolve(__dirname, "..", "..");
const SOURCE_APP = path.join(PACKAGE_ROOT, "dist", APP_NAME);
const PACKAGE_JSON = path.join(PACKAGE_ROOT, "package.json");

function fail(message) {
  console.error(`CopyCue: ${message}`);
  process.exitCode = 1;
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    encoding: "utf8",
    stdio: options.capture ? "pipe" : "inherit"
  });

  if (result.error) {
    throw result.error;
  }

  if (result.status !== 0 && !options.allowFailure) {
    const detail = options.capture ? result.stderr.trim() : "";
    throw new Error(detail || `${path.basename(command)} exited with status ${result.status}`);
  }

  return result;
}

function parseArguments(argv) {
  const result = {
    command: "install",
    installDirectory: path.join(os.homedir(), "Applications"),
    shouldOpen: true
  };

  const args = [...argv];
  if (args[0] && !args[0].startsWith("-")) {
    result.command = args.shift();
  }

  while (args.length > 0) {
    const argument = args.shift();
    switch (argument) {
      case "--no-open":
        result.shouldOpen = false;
        break;
      case "--install-dir": {
        const value = args.shift();
        if (!value) {
          throw new Error("--install-dir requires a directory path");
        }
        result.installDirectory = path.resolve(value);
        break;
      }
      case "-h":
      case "--help":
        result.command = "help";
        break;
      case "-v":
      case "--version":
        result.command = "version";
        break;
      default:
        throw new Error(`unknown option: ${argument}`);
    }
  }

  return result;
}

function assertSupportedMac() {
  if (process.platform !== "darwin") {
    throw new Error("the CopyCue app can only be installed on macOS");
  }
  if (process.arch !== "arm64") {
    throw new Error("this MVP build requires an Apple Silicon Mac");
  }
}

function verifyBundle(appPath, verifySignature = true) {
  const executablePath = path.join(appPath, "Contents", "MacOS", PROCESS_NAME);
  const plistPath = path.join(appPath, "Contents", "Info.plist");

  if (!fs.existsSync(executablePath) || !fs.existsSync(plistPath)) {
    throw new Error("the npm package does not contain a complete CopyCue application");
  }

  const plist = run(
    "/usr/bin/plutil",
    ["-extract", "CFBundleIdentifier", "raw", "-o", "-", plistPath],
    { capture: true }
  );
  if (plist.stdout.trim() !== BUNDLE_IDENTIFIER) {
    throw new Error("the bundled application has an unexpected bundle identifier");
  }

  if (verifySignature) {
    run("/usr/bin/codesign", ["--verify", "--deep", "--strict", appPath], { capture: true });
  }
}

function stopRunningCopyCue() {
  run("/usr/bin/pkill", ["-x", PROCESS_NAME], { allowFailure: true, capture: true });
}

function install(options) {
  assertSupportedMac();
  verifyBundle(SOURCE_APP, false);

  const installDirectory = options.installDirectory;
  const destination = path.join(installDirectory, APP_NAME);
  const backup = path.join(installDirectory, ".CopyCue.app.previous");
  fs.mkdirSync(installDirectory, { recursive: true });

  const stagingDirectory = fs.mkdtempSync(path.join(installDirectory, ".copycue-install-"));
  const stagedApp = path.join(stagingDirectory, APP_NAME);
  let movedExistingApp = false;

  try {
    run("/bin/cp", ["-R", "-X", SOURCE_APP, stagedApp]);
    verifyBundle(stagedApp);

    if (fs.existsSync(destination)) {
      stopRunningCopyCue();
      fs.rmSync(backup, { recursive: true, force: true });
      fs.renameSync(destination, backup);
      movedExistingApp = true;
    }

    fs.renameSync(stagedApp, destination);
    fs.rmSync(backup, { recursive: true, force: true });
    movedExistingApp = false;
  } catch (error) {
    if (movedExistingApp && !fs.existsSync(destination) && fs.existsSync(backup)) {
      fs.renameSync(backup, destination);
    }
    throw error;
  } finally {
    fs.rmSync(stagingDirectory, { recursive: true, force: true });
  }

  console.log(`✓ CopyCue installed at ${destination}`);

  if (options.shouldOpen) {
    run("/usr/bin/open", [destination]);
    console.log("✓ CopyCue is running in your menu bar");
  } else {
    console.log(`  Open it later with: open ${JSON.stringify(destination)}`);
  }
}

function openInstalledApp(options) {
  assertSupportedMac();
  const destination = path.join(options.installDirectory, APP_NAME);
  if (!fs.existsSync(destination)) {
    throw new Error("CopyCue is not installed; run `copycue install` first");
  }
  run("/usr/bin/open", [destination]);
}

function uninstall(options) {
  assertSupportedMac();
  const destination = path.join(options.installDirectory, APP_NAME);
  if (!fs.existsSync(destination)) {
    console.log("CopyCue is not installed.");
    return;
  }

  stopRunningCopyCue();
  fs.rmSync(destination, { recursive: true });
  console.log(`✓ CopyCue removed from ${destination}`);
}

function printHelp() {
  console.log(`CopyCue macOS installer

Usage:
  copycue install [--no-open] [--install-dir <directory>]
  copycue open [--install-dir <directory>]
  copycue uninstall [--install-dir <directory>]
  copycue --version

The default installation location is ~/Applications/CopyCue.app.`);
}

function printVersion() {
  const packageData = JSON.parse(fs.readFileSync(PACKAGE_JSON, "utf8"));
  console.log(packageData.version);
}

function main() {
  try {
    const options = parseArguments(process.argv.slice(2));
    switch (options.command) {
      case "install":
        install(options);
        break;
      case "open":
        openInstalledApp(options);
        break;
      case "uninstall":
        uninstall(options);
        break;
      case "help":
        printHelp();
        break;
      case "version":
        printVersion();
        break;
      default:
        throw new Error(`unknown command: ${options.command}`);
    }
  } catch (error) {
    fail(error.message);
  }
}

main();
