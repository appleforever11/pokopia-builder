#!/usr/bin/env node
const fs = require("fs");
const https = require("https");
const path = require("path");

const repo = path.resolve(__dirname, "../..");
const assetsRoot = "/Applications/Pokopedia.app/Wrapper/Pokopedia.app/assets/assets";
const outputDir = path.join(repo, "Sources/PokopiaBuilder/Resources");
const outputPath = path.join(outputDir, "pokopia-catalog.json");

main().catch((error) => {
  console.warn(`Warning: ${error.message}`);
  writeCatalog({ recipes: [], recipeMaterials: [] });
});

async function main() {
  const recipeHtml = await fetchText("https://pokopiadex.com/recipes");
  const { recipes, materials } = extractPokopiaDexRecipes(recipeHtml);
  writeCatalog({ recipes, recipeMaterials: materials });
}

function fetchText(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (response) => {
      let data = "";
      response.on("data", (chunk) => data += chunk);
      response.on("end", () => {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          resolve(data);
        } else {
          reject(new Error(`${url} returned HTTP ${response.statusCode}`));
        }
      });
    }).on("error", reject);
  });
}

function decodeEmbeddedPayload(html) {
  return html
    .replace(/&quot;/g, "\"")
    .replace(/&amp;/g, "&")
    .replace(/\\"/g, "\"")
    .replace(/\\n/g, "\n");
}

function extractJSONArrayAfter(source, marker) {
  const markerIndex = source.indexOf(marker);
  if (markerIndex === -1) return [];
  const start = source.indexOf("[", markerIndex);
  if (start === -1) return [];

  let depth = 0;
  let inString = false;
  let escaping = false;

  for (let index = start; index < source.length; index++) {
    const char = source[index];
    if (inString) {
      if (escaping) escaping = false;
      else if (char === "\\") escaping = true;
      else if (char === "\"") inString = false;
      continue;
    }
    if (char === "\"") inString = true;
    else if (char === "[") depth++;
    else if (char === "]") {
      depth--;
      if (depth === 0) {
        return JSON.parse(source.slice(start, index + 1));
      }
    }
  }
  return [];
}

function extractPokopiaDexRecipes(html) {
  const decoded = decodeEmbeddedPayload(html);
  return {
    recipes: extractJSONArrayAfter(decoded, "\"recipes\":["),
    materials: extractJSONArrayAfter(decoded, "\"materials\":[")
  };
}

function writeCatalog({ recipes, recipeMaterials }) {
const sourceNotes = [
  {
    name: "Pokopedia local app bundle",
    url: "file:///Applications/Pokopedia.app/Wrapper/Pokopedia.app/assets/assets",
    detail: "Local installed app assets: items, item UI, crafting UI, shop UI, habitats, sprites, abilities, categories, CDs, locations, and specialties."
  },
  {
    name: "Game8 blocks page",
    url: "https://game8.co/games/Pokemon-Pokopia/archives/586478",
    detail: "Block names and descriptions used as text fallback/enrichment."
  },
  {
    name: "PokopiaDex block recipes",
    url: "https://pokopiadex.com/recipes/blocks",
    detail: "Public block recipe listing used for recipe source targeting."
  },
  {
    name: "Pokopia Wiki items",
    url: "https://www.pokopiawiki.com/items",
    detail: "Public item database with categories, descriptions, and acquisition text."
  },
  {
    name: "Pokopia Tracker material guide",
    url: "https://pokopia.dev/guides/materials",
    detail: "Public guide for raw and processed material gathering strategy."
  },
  {
    name: "Pokopia Wiki habitat guide",
    url: "https://www.pokopiawiki.com/it/guides/habitats-dex-list",
    detail: "Public guide for Habitat Dex names, requirements, and attracted Pokemon."
  }
];

const materialGuide = [
  ["Stone", "Raw Materials", "Common ground pickup and boulder drop."],
  ["Leaf", "Raw Materials", "Chop bushes or rely on Grow-specialty drops."],
  ["Small Log", "Raw Materials", "Chop small trees."],
  ["Sturdy Stick", "Raw Materials", "Chop medium trees."],
  ["Vine Rope", "Raw Materials", "Cut hanging vines."],
  ["Squishy Clay", "Raw Materials", "Dig near water and riverbanks."],
  ["Glowing Mushroom", "Raw Materials", "Dark caves and shaded regions."],
  ["Honey", "Raw Materials", "Vespiquen exchange and flower habitats."],
  ["Twine", "Processed Materials", "Crafted from Vine Rope; sometimes dropped by Litter Pokemon."],
  ["Limestone", "Raw Materials", "Light-colored rocks."],
  ["Copper Ore", "Raw Materials", "Orange-tinted deposits."],
  ["Iron Ore", "Raw Materials", "Dark deposits, especially in Rocky Ridges."],
  ["Gold Ore", "Raw Materials", "Rarer deep or high-tier deposits."],
  ["Glowing Stone", "Raw Materials", "Glowing formations in caves."],
  ["Smooth Rock", "Raw Materials", "Near rivers and coastlines."],
  ["Wheat", "Raw Materials", "Grown from seeds."],
  ["Volcanic Ash", "Raw Materials", "Lava-heavy regions."],
  ["Wastepaper", "Raw Materials", "Trash piles and urban areas."],
  ["Lumber", "Processed Materials", "Chop logs with a Chop-specialty Pokemon."],
  ["Brick", "Processed Materials", "Burn Squishy Clay."],
  ["Paper", "Processed Materials", "Recycle Wastepaper."],
  ["Concrete", "Processed Materials", "Crush Limestone."],
  ["Iron Bar", "Processed Materials", "Smelt Iron Ore."],
  ["Copper Bar", "Processed Materials", "Smelt Copper Ore."],
  ["Gold Bar", "Processed Materials", "Smelt Gold Ore."],
  ["Glass", "Processed Materials", "Smelt Volcanic Ash."],
  ["Paint", "Processed Materials", "Crush berries."]
];

const habitatGuide = [
  ["Tall Grass", "4x Tall Grass", "Bulbasaur, Charmander, Squirtle"],
  ["Tree-Shaded Tall Grass", "1x Large Tree + 4x Tall Grass", "Scyther, Pinsir, Heracross"],
  ["Hydrated Tall Grass", "4x Tall Grass + 2x Water", "Cramorant, Squirtle"],
  ["Picnic Set", "Any seat + Any table + 1x Picnic Basket", "Pichu"],
  ["Factory Storage", "Streetlight + Control Unit + Metal Drum + Cords", "Magnemite, Koffing"],
  ["Cafe Space", "2x Seats + Potted Plant + Counter + Mug", "Audino"],
  ["Pikachu Space", "1x Pikachu Sofa + 1x Pikachu Doll", "Pikachu"],
  ["Mossy Hot Spring", "4x Moss + 2x Hot-spring Water", "Torkoal"],
  ["Researcher's Desk", "Any Table + Computer + Science Kit", "Intelligent Pokemon"],
  ["Dojo Training", "2x Hanging Scrolls + 2x Strength Rocks", "Poliwrath"],
  ["Plush Central", "Arcanine, Pikachu, Dragonite, Eevee Dolls", "Drifblim"],
  ["Lovely Ribbon Cake", "Any Seat + Any Table + 1x Ribbon Cake", "Sylveon"]
];

function walk(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return walk(full);
    return full;
  });
}

function titleize(slug) {
  const special = { cd: "CD", pc: "PC", tv: "TV", ss: "S.S.", mt: "Mt.", ui: "UI", poke: "Poke" };
  return slug
    .replace(/\.[^.]+$/, "")
    .split("-")
    .map((part) => special[part.toLowerCase()] || part.slice(0, 1).toUpperCase() + part.slice(1))
    .join(" ");
}

function normalized(value) {
  return value.toLowerCase().replace(/\(block\)/g, "").replace(/[^a-z0-9]+/g, "");
}

function inferCategory(relative) {
  const text = relative.toLowerCase();
  if (text.includes("/item_ui/")) {
    if (text.includes("wall") || text.includes("pillar")) return "Blocks";
    if (text.includes("floor") || text.includes("tiling") || text.includes("road") || text.includes("carpeting")) return "Blocks";
    return "Build Parts";
  }
  if (text.includes("/crafting_ui/")) return "Materials";
  if (text.includes("/shop_ui/")) return "Shop";
  if (text.includes("berry") || text.includes("bread") || text.includes("soup") || text.includes("pizza") || text.includes("salad") || text.includes("cake")) return "Food";
  if (text.includes("bed") || text.includes("chair") || text.includes("table") || text.includes("sofa") || text.includes("desk")) return "Furniture";
  if (text.includes("lamp") || text.includes("light") || text.includes("machine") || text.includes("computer")) return "Utilities";
  if (text.includes("fossil") || text.includes("ore") || text.includes("ingot") || text.includes("pokemetal") || text.includes("stone") || text.includes("leaf") || text.includes("twine")) return "Materials";
  return "Items";
}

function kindFor(category, name) {
  const text = `${category} ${name}`.toLowerCase();
  if (text.includes("wall") || text.includes("pillar")) return "Walls";
  if (text.includes("floor") || text.includes("road") || text.includes("tiling") || text.includes("carpeting") || text.includes("mat")) return "Flooring";
  if (text.includes("ore") || text.includes("ingot") || text.includes("pokemetal") || text.includes("deposit")) return "Ore";
  if (text.includes("print")) return "Prints";
  if (text.includes("grass") || text.includes("soil") || text.includes("sand") || text.includes("moss")) return "Terrain";
  if (text.includes("rock") || text.includes("stone") || text.includes("fossil")) return "Rock";
  if (category === "Utilities") return "Utility";
  return "Structures";
}

const itemFiles = walk(path.join(assetsRoot, "items")).filter((file) => file.endsWith(".png"));
const items = itemFiles.map((file) => {
  const relative = path.relative(assetsRoot, file);
  const name = titleize(path.basename(file));
  const category = inferCategory(relative);
  return {
    id: `pokopedia-${relative.replaceAll(path.sep, "-")}`,
    name,
    category,
    kind: kindFor(category, name),
    description: `Pokopedia ${category.toLowerCase()} asset.`,
    imagePath: file,
    localAsset: relative,
    sources: ["Pokopedia local app bundle"]
  };
});

for (const recipe of recipes) {
  const key = normalized(recipe.name);
  let found = items.find((item) => normalized(item.name) === key);
  if (!found) {
    found = {
      id: `pokopiadex-${recipe.slug}`,
      name: recipe.name,
      category: recipe.menu_category || "Items",
      kind: kindFor(recipe.menu_category || "Items", recipe.name),
      description: `Craftable ${String(recipe.menu_category || "item").toLowerCase()}.`,
      imagePath: null,
      localAsset: null,
      sources: []
    };
    items.push(found);
  }

  found.category = recipe.menu_category || found.category;
  found.kind = kindFor(found.category, found.name);
  found.recipe = {
    resultQuantity: recipe.recipe?.result_quantity || 1,
    ingredients: (recipe.ingredientImages || []).map((ingredient) => ({
      name: ingredient.name,
      imageSrc: ingredient.imageSrc
    })),
    materialSlugs: recipe.materialSlugs || [],
    unlockSources: recipe.recipe?.sources || []
  };
  found.tags = recipe.tags || [];
  found.sources.push("PokopiaDex block recipes");
}

for (const [name, category, description] of materialGuide) {
  const key = normalized(name);
  const found = items.find((item) => normalized(item.name) === key);
  if (found) {
    found.category = category;
    found.description = description;
    found.sources.push("Pokopia Tracker material guide");
  } else {
    items.push({
      id: `guide-material-${key}`,
      name,
      category,
      kind: kindFor(category, name),
      description,
      imagePath: null,
      localAsset: null,
      sources: ["Pokopia Tracker material guide"]
    });
  }
}

const habitatFiles = walk(path.join(assetsRoot, "habitats")).filter((file) => file.endsWith(".png"));
const habitats = habitatFiles.map((file) => ({
  id: `habitat-${path.basename(file, ".png")}`,
  name: titleize(path.basename(file)),
  imagePath: file,
  localAsset: path.relative(assetsRoot, file),
  requirements: null,
  attracts: null,
  sources: ["Pokopedia local app bundle"]
}));

for (const [name, requirements, attracts] of habitatGuide) {
  const found = habitats.find((habitat) => normalized(habitat.name) === normalized(name));
  if (found) {
    found.requirements = requirements;
    found.attracts = attracts;
    found.sources.push("Pokopia Wiki habitat guide");
  }
}

const collections = {};
for (const folder of ["abilities", "categories", "cds", "locations", "specialties", "sprites"]) {
  collections[folder] = walk(path.join(assetsRoot, folder))
    .filter((file) => file.endsWith(".png"))
    .map((file) => ({
      name: titleize(path.basename(file)),
      imagePath: file,
      localAsset: path.relative(assetsRoot, file),
      sources: ["Pokopedia local app bundle"]
    }));
}

fs.mkdirSync(outputDir, { recursive: true });
fs.writeFileSync(outputPath, JSON.stringify({
  generatedAt: new Date().toISOString(),
  sources: sourceNotes,
  counts: {
    items: items.length,
    craftableRecipes: recipes.length,
    recipeMaterials: recipeMaterials.length,
    habitats: habitats.length,
    abilities: collections.abilities.length,
    categories: collections.categories.length,
    cds: collections.cds.length,
    locations: collections.locations.length,
    specialties: collections.specialties.length,
    sprites: collections.sprites.length
  },
  items,
  habitats,
  recipes: recipes.map((recipe) => ({
    id: recipe.id,
    slug: recipe.slug,
    name: recipe.name,
    category: recipe.menu_category,
    tags: recipe.tags || [],
    resultQuantity: recipe.recipe?.result_quantity || 1,
    ingredients: (recipe.ingredientImages || []).map((ingredient) => ingredient.name),
    materialSlugs: recipe.materialSlugs || [],
    unlockSources: recipe.recipe?.sources || [],
    imageSrc: recipe.imageSrc,
    source: "PokopiaDex block recipes"
  })),
  recipeMaterials,
  collections
}, null, 2));

console.log(outputPath);
console.log(JSON.stringify({ items: items.length, craftableRecipes: recipes.length, recipeMaterials: recipeMaterials.length, habitats: habitats.length, ...Object.fromEntries(Object.entries(collections).map(([k, v]) => [k, v.length])) }, null, 2));
}
