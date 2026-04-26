# Pokopia Data Sources

This project uses a generated local catalog at `Sources/PokopiaBuilder/Resources/pokopia-catalog.json`.

## Current Sources

- Pokopedia local app bundle: `/Applications/Pokopedia.app/Wrapper/Pokopedia.app/assets/assets`
  - Local assets for items, item UI, crafting UI, shop UI, habitats, sprites, abilities, categories, CDs, locations, and specialties.
- Game8 blocks page: https://game8.co/games/Pokemon-Pokopia/archives/586478
  - Block names and descriptions.
- Game8 materials page: https://game8.co/games/Pokemon-Pokopia/archives/583145
  - Material list and usage context.
- PokopiaDex recipes page: https://pokopiadex.com/recipes
  - 714 craftable recipe records embedded in public page data.
- PokopiaDex block recipes page: https://pokopiadex.com/recipes/blocks
  - 126 block recipe listing.
- Pokopia Tracker materials guide: https://pokopia.dev/guides/materials
  - Raw and processed material gathering notes.
- Pokopia Wiki items page: https://www.pokopiawiki.com/items
  - Public item database with categories, acquisition text, and descriptions.
- Pokopia Wiki Habitat Dex guide: https://www.pokopiawiki.com/it/guides/habitats-dex-list
  - Habitat Dex overview and selected requirements/spawns.

## Generated Catalog Counts

- 948 item/material records
- 714 craftable recipes
- 43 recipe materials
- 213 habitats
- 313 sprites
- 31 specialties
- 11 abilities
- 10 CDs
- 6 locations
- 5 categories

Run `scripts/pokopia/build-pokopia-catalog.js` to refresh the generated catalog.
