#!/usr/bin/env node

"use strict";

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const projectRoot = path.resolve(__dirname, "..");
const sourcePath = path.join(projectRoot, "Resources", "AppIcon.png");
const outputPath = path.join(projectRoot, "Resources", "AppIcon.icns");

// Modern ICNS resource codes, including Retina representations.
const representations = [
  { type: "icp4", size: 16 },
  { type: "ic11", size: 32 },
  { type: "icp5", size: 32 },
  { type: "ic12", size: 64 },
  { type: "icp6", size: 64 },
  { type: "ic07", size: 128 },
  { type: "ic13", size: 256 },
  { type: "ic08", size: 256 },
  { type: "ic14", size: 512 },
  { type: "ic09", size: 512 },
  { type: "ic10", size: 1024 }
];

function run(command, args) {
  const result = spawnSync(command, args, { encoding: "utf8" });
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    throw new Error(result.stderr.trim() || `${path.basename(command)} failed`);
  }
}

function validateMaster(png) {
  const signature = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  if (png.length < 24 || !png.subarray(0, 8).equals(signature)) {
    throw new Error("Resources/AppIcon.png must be a PNG image");
  }

  const width = png.readUInt32BE(16);
  const height = png.readUInt32BE(20);
  if (width !== 1024 || height !== 1024) {
    throw new Error(`Resources/AppIcon.png must be 1024x1024, found ${width}x${height}`);
  }
}

function makeResource(type, png) {
  const resource = Buffer.allocUnsafe(8 + png.length);
  resource.write(type, 0, 4, "ascii");
  resource.writeUInt32BE(resource.length, 4);
  png.copy(resource, 8);
  return resource;
}

const master = fs.readFileSync(sourcePath);
validateMaster(master);

const temporaryDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "copycue-icon-"));

try {
  const imagesBySize = new Map();
  for (const size of new Set(representations.map(({ size }) => size))) {
    const imagePath = path.join(temporaryDirectory, `${size}.png`);
    run("/usr/bin/sips", ["-z", String(size), String(size), sourcePath, "--out", imagePath]);
    imagesBySize.set(size, fs.readFileSync(imagePath));
  }

  const resources = representations.map(({ type, size }) =>
    makeResource(type, imagesBySize.get(size))
  );
  const totalLength = 8 + resources.reduce((sum, resource) => sum + resource.length, 0);
  const header = Buffer.allocUnsafe(8);
  header.write("icns", 0, 4, "ascii");
  header.writeUInt32BE(totalLength, 4);

  fs.writeFileSync(outputPath, Buffer.concat([header, ...resources], totalLength));
  console.log(`Created ${outputPath}`);
} finally {
  fs.rmSync(temporaryDirectory, { recursive: true, force: true });
}
