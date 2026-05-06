#!/usr/bin/env node
const fs = require("fs");
const path = require("path");
const childProcess = require("child_process");

const repo = path.resolve(__dirname, "../..");
const catalogPath = path.join(repo, "Sources/PokopiaBuilder/Resources/pokopia-catalog.json");
const outputDir = process.argv[2] || path.join(process.env.HOME || "/tmp", "Documents/Pokopia Models");
const limitArg = process.argv.find((arg) => arg.startsWith("--limit="));
const limit = limitArg ? Number(limitArg.split("=")[1]) : Infinity;
const catalog = JSON.parse(fs.readFileSync(catalogPath, "utf8"));
const items = catalog.items || [];

function slug(value) {
  return String(value)
    .toLowerCase()
    .replace(/\(block\)/g, "")
    .replace(/\.png$/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

function shapeFor(item) {
  const name = `${item.name} ${item.category || ""} ${item.kind || ""}`.toLowerCase();
  if (name.includes("wall") || name.includes("pillar")) return "wall";
  if (name.includes("floor") || name.includes("road") || name.includes("tile") || name.includes("soil") || name.includes("grass") || name.includes("carpet") || name.includes("mat")) return "floor";
  if (name.includes("crystal") || name.includes("glowing stone") || name.includes("gem")) return "crystal";
  if (name.includes("lamp") || name.includes("light") || name.includes("lantern")) return "lamp";
  if (name.includes("sign") || name.includes("poster") || name.includes("board")) return "sign";
  if (name.includes("fence") || name.includes("rail")) return "fence";
  if (name.includes("stair") || name.includes("slope") || name.includes("roof")) return "stairs";
  return "cube";
}

function colorFor(item) {
  const name = `${item.name} ${item.category || ""} ${item.kind || ""}`.toLowerCase();
  if (name.includes("grass") || name.includes("leaf") || name.includes("moss")) return "6AAD45";
  if (name.includes("sand") || name.includes("beach") || name.includes("soil")) return "C8AB74";
  if (name.includes("snow") || name.includes("ice") || name.includes("white") || name.includes("marble")) return "C8D6D6";
  if (name.includes("red") || name.includes("brick") || name.includes("clay")) return "9A4D38";
  if (name.includes("brown") || name.includes("wood") || name.includes("log")) return "8C5933";
  if (name.includes("yellow") || name.includes("gold")) return "C89539";
  if (name.includes("water") || name.includes("crystal") || name.includes("blue") || name.includes("cyber") || name.includes("neon")) return "57B8D1";
  if (name.includes("black") || name.includes("iron") || name.includes("asphalt")) return "404447";
  if (name.includes("pink")) return "E58AB2";
  if (name.includes("green")) return "66AA55";
  return "8E9088";
}

const candidates = items.filter((item) => {
  const name = `${item.name} ${item.category || ""} ${item.kind || ""}`.toLowerCase();
  return item.category === "Blocks" ||
    item.category === "Build Parts" ||
    /wall|floor|road|tile|soil|grass|sand|stone|rock|ore|brick|clay|ice|marble|plating|print|fence|sign|roof|stair|crystal/.test(name);
});

fs.mkdirSync(outputDir, { recursive: true });
let made = 0;
for (const item of candidates) {
  if (made >= limit) break;
  const modelSlug = slug(item.name);
  const outPath = path.join(outputDir, `${modelSlug}.scn`);
  if (fs.existsSync(outPath)) continue;
  childProcess.execFileSync(
    path.join(repo, "scripts/pokopia/make-procedural-model.swift"),
    [modelSlug, shapeFor(item), colorFor(item), outputDir],
    { stdio: "inherit" }
  );
  made += 1;
}

console.log(`Generated ${made} procedural models in ${outputDir}`);
