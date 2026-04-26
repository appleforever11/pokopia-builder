import Foundation

enum PokopiaData {
    static let sourceURL = URL(string: "https://game8.co/games/Pokemon-Pokopia/archives/586478")!
    private static let localAppAssets = URL(fileURLWithPath: "/Applications/Pokopedia.app/Wrapper/Pokopedia.app/assets/assets")

    static let blocks: [PokopiaBlock] = rawBlocks
        .split(separator: "\n")
        .enumerated()
        .compactMap { index, row in
            let columns = row.split(separator: "\t", maxSplits: 1).map(String.init)
            guard columns.count == 2 else { return nil }
            let name = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let description = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
            return PokopiaBlock(
                id: "\(index)-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))",
                name: name,
                description: description,
                kind: classify(name: name, description: description),
                imagePath: nil
            )
        }

    static func loadCatalog() -> [PokopiaBlock] {
        if let generated = loadGeneratedCatalog(), !generated.isEmpty {
            return generated
        }

        var seenNames = Set(blocks.map { normalized($0.name) })
        var catalog = blocks

        for item in localAssetItems() where !seenNames.contains(normalized(item.name)) {
            catalog.append(item)
            seenNames.insert(normalized(item.name))
        }

        return catalog.sorted { lhs, rhs in
            if lhs.kind.rawValue == rhs.kind.rawValue {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            return lhs.kind.rawValue < rhs.kind.rawValue
        }
    }

    private static func loadGeneratedCatalog() -> [PokopiaBlock]? {
        guard let url = Bundle.module.url(forResource: "pokopia-catalog", withExtension: "json") else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let catalog = try JSONDecoder().decode(GeneratedCatalog.self, from: data)
            return catalog.items.map { item in
                PokopiaBlock(
                    id: item.id,
                    name: item.name,
                    description: item.description,
                    kind: BlockKind(rawValue: item.kind) ?? classify(name: item.name, description: item.description),
                    imagePath: item.imagePath,
                    category: item.category,
                    recipeIngredients: item.recipe?.ingredients.map(\.name) ?? [],
                    unlockSources: item.recipe?.unlockSources ?? [],
                    dataSources: item.sources
                )
            }
        } catch {
            return nil
        }
    }

    private static func localAssetItems() -> [PokopiaBlock] {
        assetRoots().flatMap { root -> [PokopiaBlock] in
            let itemRoot = root.appendingPathComponent("items", isDirectory: true)
            guard let enumerator = FileManager.default.enumerator(
                at: itemRoot,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                return []
            }

            return enumerator.compactMap { value in
                guard let url = value as? URL, url.pathExtension.lowercased() == "png" else { return nil }
                let relative = relativePath(for: url, under: root)
                let slug = url.deletingPathExtension().lastPathComponent
                let name = displayName(from: slug)
                let group = url.deletingLastPathComponent().lastPathComponent
                let description = descriptionForAsset(named: name, group: group)

                return PokopiaBlock(
                    id: "pokopedia-\(relative.replacingOccurrences(of: "/", with: "-"))",
                    name: name,
                    description: description,
                    kind: classify(name: name, description: "\(description) \(group) \(slug)"),
                    imagePath: url.path
                )
            }
        }
    }

    private static func assetRoots() -> [URL] {
        var roots: [URL] = []
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("PokopediaAssets", isDirectory: true),
           FileManager.default.fileExists(atPath: bundled.path) {
            roots.append(bundled)
        }
        if FileManager.default.fileExists(atPath: localAppAssets.path) {
            roots.append(localAppAssets)
        }
        return roots
    }

    private static func classify(name: String, description: String) -> BlockKind {
        let text = "\(name) \(description)".lowercased()
        if text.contains("deposit") || text.contains("ore") || text.contains("gold") || text.contains("pokemetal") || text.contains("copper") {
            return .ore
        }
        if text.contains("print") || text.contains("pattern") {
            return .pattern
        }
        if text.contains("floor") || text.contains("carpeting") || text.contains("mat") || text.contains("tiling") || text.contains("road") || text.contains("plating") {
            return .floor
        }
        if text.contains("wall") || text.contains("pillar") {
            return .wall
        }
        if text.contains("soil") || text.contains("grass") || text.contains("sand") || text.contains("clay") || text.contains("ash") || text.contains("moss") || text.contains("gravel") || text.contains("ice") {
            return .terrain
        }
        if text.contains("rock") || text.contains("stone") || text.contains("sandstone") || text.contains("limestone") {
            return .rock
        }
        if text.contains("light") || text.contains("foundation") || text.contains("levee") {
            return .utility
        }
        return .structure
    }

    private static func normalized(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "(block)", with: "")
            .replacingOccurrences(of: "interior", with: "")
            .replacingOccurrences(of: "[^a-z0-9]+", with: "", options: .regularExpression)
    }

    private static func displayName(from slug: String) -> String {
        slug
            .split(separator: "-")
            .map { word in
                let lower = word.lowercased()
                let special = [
                    "cd": "CD",
                    "pc": "PC",
                    "tv": "TV",
                    "ss": "S.S.",
                    "mt": "Mt.",
                    "ui": "UI"
                ]
                if let mapped = special[lower] { return mapped }
                return lower.prefix(1).uppercased() + lower.dropFirst()
            }
            .joined(separator: " ")
    }

    private static func relativePath(for url: URL, under root: URL) -> String {
        let rootPath = root.standardizedFileURL.path + "/"
        return url.standardizedFileURL.path.replacingOccurrences(of: rootPath, with: "")
    }

    private static func descriptionForAsset(named name: String, group: String) -> String {
        switch group {
        case "item_ui":
            return "Pokopedia item/block asset."
        case "crafting_ui":
            return "Pokopedia crafting material asset."
        case "shop_ui":
            return "Pokopedia shop item asset."
        default:
            return "Pokopedia in-game item asset."
        }
    }

    private static let rawBlocks = """
Wooden wall (Block)	Line up a bunch of these to build a wall. They give off a faint but pleasant woodsy aroma.
Light wooden wall (Block)	Line up a bunch of these to build a wall. The wood grain pops more than a regular wooden wall's.
Painted wall (Block)	While the planks of this wall have been painted over, a closer inspection reveals they are a little dirty.
Plaster wall (Block)	Gather some shells, crush them up, and compact them to make the perfect wall of gritty plaster.
Cloth wall (Block)	Simple cloth walls. Try them out in interior spaces.
Guest-room wall	Made from the same material as cloth walls, this was used for the guest rooms of a luxury cruise ship.
Starry-sky wall (Block)	These stars shine even in the dark. Stack them up to create a night sky filled with stars.
Cushy wall	An exceptionally shiny wall that feels very high-class. Pairs wonderfully with luxury furniture items.
Modern wall (Block)	When cut into pieces and arranged, even rugged rocks can be transformed into a stylish wall.
Broken-tiling wall (Block)	A wall made out of shattered tiles. It shines like glass when the light hits it.
Cobblestone wall (Block)	A tightly packed mass of stones of various sizes. Perfect for stacking as well as making walls.
Brick wall (Block)	These really stand out when stacked up. Use them to make eye-catching buildings.
Stone brick wall (Block)	Stone bricks that exude calmness. They are perfect for making buildings, flower beds, and such.
Aged-stone wall (Block)	It is chipped in places and the colors have faded, revealing a glimpse of its long history.
Patterned aged-stone wall (Block)	It has some cracks running through it, but its triangular pattern remains as it was long ago.
Concrete Wall	Doesn't this sorta remind you of Conkeldurr's concrete pillars?
Rough Wall (Block)	A wall made of concrete. Gives a slightly more chic impression than plaster.
Striped Wall (Block)	A sharp, stylish wall. Made of sturdy copper, it is perfect for a warehouse.
Bronze Wall (Block)	A metal wall with a reddish-brown shine to it. It looks like a big piece of chocolate when stacked up.
Stylish Bronze Wall (Block)	A metal wall with ornate designs on it. Arrange some of these to create a rich and opulent space.
Iron Wall (Block)	A solid iron wall. It gives off a slight sheen when exposed to light.
Stylish Iron Wall (Block)	A fancy wall made of iron. It provides a nice accent when paired with a regular iron wall.
Gold Wall (Block)	Pure sparkling gold. It is as dazzling as Gholdengo.
Stylish gold wall (Block)	A golden wall with high-quality stones set in it. This one detail gives it an air of refined elegance.
Crystal Wall (Block)	A wall that sparkles in the light. It is made of crystal and quite hard.
Poke Ball Wall (Block)	The white Poke Ball pattern on this wall is always nice and shiny.
Warning Wall (Block)	Warns of danger with yellow and black stripes. Maybe you could use it to mark areas off-limits.
Stylish Wall (Upper)	Try arranging these into a wall. Line up the timbers to create a fancy pattern.
Stylish Wall (Middle)	Try arranging these into a wall. Line up the timbers to create a fancy pattern.
Stylish Wall (Lower)	Try arranging these into a wall. Line up the timbers to create a fancy pattern.
Antique Wall (Upper)	Install this wall to add an air of luxury to a room. Its subtle retro aesthetic evokes nostalgic feelings.
Antique Wall (Middle)	Install this wall to add an air of luxury to a room. Its subtle retro aesthetic evokes nostalgic feelings.
Antique Wall (Lower)	Install this wall to add an air of luxury to a room. Its subtle retro aesthetic evokes nostalgic feelings.
Light Antique Wall (Upper)	An extravagant wall covered in ornate engravings. It looks elegant, like a palace wall.
Light Antique Wall (Middle)	An extravagant wall covered in ornate engravings. It looks elegant, like a palace wall.
Light Antique Wall (Lower)	An extravagant wall covered in ornate engravings. It looks elegant, like a palace wall.
Wooden Pillar (Upper)	It is as sturdy as the trunk of a huge tree.
Wooden Pillar (Middle)	It is as sturdy as the trunk of a huge tree.
Wooden Pillar (Lower)	It is as sturdy as the trunk of a huge tree.
Stylish Brick Wall (Upper)	Arrange these to create a fancy wall. Try pairing them with other brick accent pieces.
Stylish Brick Wall (Middle)	Arrange these to create a fancy wall. Try pairing them with other brick accent pieces.
Stylish Brick Wall (Lower)	Arrange these to create a fancy wall. Try pairing them with other brick accent pieces.
Stone Pillar (Upper)	A heavy stone pillar with a design that would pair nicely with a fancy brick wall.
Stone Pillar (Middle)	A heavy stone pillar with a design that would pair nicely with a fancy brick wall.
Stone Pillar (Lower)	A heavy stone pillar with a design that would pair nicely with a fancy brick wall.
Pop Art Wall (Upper)	Stack the matching lower, middle, and upper sections to create a stylish wall fit for a shop.
Pop Art Wall (Middle)	Stack the matching lower, middle, and upper sections to create a stylish wall fit for a shop.
Pop Art Wall (Lower)	Stack the matching lower, middle, and upper sections to create a stylish wall fit for a shop.
Confectionery Wall (Upper)	A wall that almost looks like it is made out of candy or chocolate.
Confectionery Wall (Middle)	A wall that almost looks like it is made out of candy or chocolate.
Confectionery Wall (Lower)	A wall that almost looks like it is made out of candy or chocolate.
Pokemon Center Wall (Trim)	Stack the matching lower, middle, upper, and trim sections to create a Pokemon Center wall.
Pokemon Center Wall (Upper)	Stack the matching lower, middle, upper, and trim sections to create a Pokemon Center wall.
Pokemon Center Wall (Middle)	Stack the matching lower, middle, upper, and trim sections to create a Pokemon Center wall.
Pokemon Center Wall (Lower)	Stack the matching lower, middle, upper, and trim sections to create a Pokemon Center wall.
Wooden Flooring (Block)	Flooring composed of hard, tightly aligned wooden planks. It can support heavy Pokemon. Probably.
Diagonal Wooden Flooring (Block)	Place these down to use them as flooring. Their simple design goes with pretty much anything.
Crisscross Wooden Flooring (Block)	Place these side by side to form a stylish alternating pattern that is perfect for a cafe floor.
Hardwood Flooring (Block)	Flooring made from arranged pieces of sanded lumber.
Modern Carpeting (Block)	Soft, fluffy carpeting. It would look nice in a modern building.
Woven Carpeting (Block)	Carpeting that can be found in offices. Place them next to each other to form a checkerboard pattern.
Fluffy Flooring (Block)	Moderately soft cotton flooring. It probably would not hurt if you fell on it.
Soft Carpeting	Fluffy carpeting that feels as soft as a cloud. Place a bunch together for a really nice look.
Extravagant Carpeting	Walking on this high-class embroidered carpeting makes you feel like a star.
Tatami Mat	Tatami mat flooring often found in traditional homes. You can make this by weaving leaves together.
Felt Mat (Block)	Often used for carpeting. Felt can also be laid out as flooring or stacked up into decor.
Puffy-tree pillar (Block)	These may look like a big tree when stacked up, but they are actually cushions stuffed with leaves.
Grass flooring (Block)	This looks like real grass, but it is actually made of cushions.
Simple Flooring (Block)	Flooring made from polished hewn stone. It is glossy and hard to the touch.
Marble (Block)	Lay down some of this beautifully patterned marble and enjoy a taste of the rich life.
Stone Flooring (Block)	Place these to create an entryway. Most folks will not notice if it gets a little dirty.
Lined-stone flooring (Block)	Provides a lovely accent when paired with stone flooring.
Dark Marble Flooring	Stylish flooring with dark brown trim. It is perfect for museums and the like.
Light marble flooring (Block)	Stylish flooring with light gray trim. Perfect for offices and the like.
Aged-Stone Flooring	Stone flooring found in ancient ruins. There is something mysterious about its triangular pattern.
Simple Square Tiling (Block)	These smooth, water-repellant tiles would make a great bathroom wall.
Stylish tiling (Block)	Glossy ceramic tiles that could be used for walls or flooring.
Hexagonal Flooring (Block)	Lifeless flooring with a hexagonal pattern. Perfectly suited for high-tech places, such as laboratories.
Shop Flooring (Block)	Flooring that reminds you of shop floors. Try installing a counter and cash register.
Triangle-Design Flooring (Block)	Shiny flooring with a vibrant, triangular pattern. Make this using Pokemetal.
Iron-Plate Flooring (Block)	Iron-plate flooring that looks like it belongs in a factory. Steel-type Pokemon might enjoy this.
Iron Tiling (Block)	Install these on the floor to create a stylish industrial vibe, like the inside of a warehouse.
Neon Flooring (Block)	Line these up to make a brightly lit floor.
Cyber Flooring (Block)	The edges are constantly glowing. Arrange them side by side to create a futuristic atmosphere.
Arched tiling (Block)	Each one alone is just an ordinary brick. Placed together, they make a beautiful arching pattern.
Stone tiling (Block)	Even rough, ordinary stones can be polished and stacked to make shiny tiles.
Square tiling (Block)	Tiles often found in seaside towns. They have a distinctive, slightly rough texture.
Mosaic Tiling (Block)	Colorfully patterned tile flooring. Set up a few blocks to create a metropolitan atmosphere.
Brick Flooring (Block)	Vivid bricks that remind you of sunny days. Walking along these makes you feel quite cheerful.
Stylish Stone Flooring (Block)	It is just a bunch of stones piled up, and yet it somehow looks stylish.
Fish-scale tiling (Block)	Stone tiles in a beautiful fish-scale pattern.
Asphalt Road	Pave the way for Pokemon to have nice roads that are easy to walk on.
Marked Road (Horizontal)	Asphalt road with a white line on it. Arrange these in a row to make a crosswalk.
Marked Road (Vertical)	Asphalt road with a white line on it. Arrange these in a row to make a crosswalk.
Gray circle flooring	The prominent gray circle looks like the perfect spot to install a utility pole.
Hay pile (Block)	Bales of straw can be arranged to make walls or flooring, whichever you choose.
Iron plating (Block)	Sturdy plating that is even used to make ships. Change its color to your liking.
Cube Light (Block)	A cube that constantly emits bright light, even without electricity. It is made from shining rocks.
Foundation	A sturdy foundation made of firmly bonded stone and concrete.
Levee	Place these wherever you want to stop the flow of water. Sturdy enough to hold back rivers and oceans.
Scrap cube (Block)	A block of condensed cloth and scrap metal. It looks like it was made by a Pokemon skilled at crafting.
Polka-Dot Print (Block)	This pop-art polka-dot pattern looks cute whether you line up a bunch or use some as an accent.
Vertical-Stripe Print (Block)	Vertical stripes like those on Flaaffy's tail. This simple pattern fits a variety of places.
Horizontal-Stripe Print (Block)	Horizontal stripes like those on Elekid. This simple pattern fits a variety of places.
Gingham Print (Block)	A checkered pattern with a white base. A classic, simple design.
Tartan Print (Block)	A checkered pattern with several colors. The design is both methodical and adorable.
Argyle Print (Block)	A diamond-shaped checkered pattern. It has a warm, welcoming atmosphere.
Berry Print (Block)	Sweet berries, spicy berries, bitter berries. This pattern has berry flavors for everyone.
Poke Ball Print (Block)	A pattern with lots of different-color Poke Balls. It has a cute, pop-art feel.
Stylish Poke Ball Print (Block)	A pattern with a fancy Poke Ball design. It would look great in an upscale house.
Bubble Print (Block)	A pattern with lots of floating bubbles. It has a unique, ephemeral charm.
Houndstooth Print (Block)	If you stare at this pattern for a long time, you just might see flying bird Pokemon.
Vine Print (Block)	This twisting pattern is fully interconnected. It resembles Serperior's patterning.
Swirl Print (Block)	Straight lines that bend and contort into spirals.
Winter Print (Block)	A pattern with a snowflake motif. Perfect for colder seasons.
Zig-Zag Print (Block)	A cool pattern that zigzags like Pikachu's tail.
Leaf Print (Block)	This leaf pattern is easy on the eyes and makes you feel like you are in a forest.
Flower Print (Block)	A floral pattern with lots of cute flowers.
Star Print (Block)	A pattern with stars of all sizes. Use it for your floor or walls.
Curry Print (Block)	A pattern with a delicious-looking curry motif, packed full of savory vegetable flavor.
Field grass	Soft soil with grass growing on top. It is perfect for planting tree or flower seeds.
Seashore grass	Coastal soil with thin grass growing out of it. If you use Leafage on this, tall yellow grass will grow.
Alpine Grass	Dark-green grass often found in valleys.
Sky-High Grass	Lush, green grass that grows in white soil.
Ordinary soil	Regular old soil that is a bit soft. If you use Leafage on it, green tall grass will grow.
Seashell soil	Despite the seashells mixed into it, this soil is softer than sand and capable of supporting plant life.
Striped Soil	Soil made up of layers of sediment from volcanic eruptions that accumulated and hardened over time.
Pure-White Soil	White soil with a touch of colorful sand mixed in.
Clay	Soft enough for you to leave your footprints on it. It is made up of tiny grains of sand.
Ordinary Sand	Ordinary sand that can be found all over. There is some moisture in it, but it is hardened a little.
Beach Sand	Fine sand found on the beach. If you built a castle out of this, it probably would not collapse.
Skyland Sand	Silky sand found at the skylands. It is lighter in color than ordinary sand.
Bumpy Beach Sand	Sand with various stones and small seashells packed within. Stepping on it leaves footprints behind.
Volcanic Ash	Ash that fell from the sky after a volcanic eruption.
Sandstone	Amassed sand, left alone for countless years, has slowly hardened into stone.
Skyland Sandstone	Over the course of many years, the sand from the skylands has hardened into rock.
Cliff rock	A type of rock often found on mountain cliffs. Looks like you could break it with Rock Smash.
Spotted cliff rock	Small rocks from the distant past, often found in valleys, that have hardened over time into stratum.
Red cliff rock	Red rock that looks like it came from a steep mountainside cliff.
Red spotted cliff rock	Boulders often seen by the seaside. With the waves at their backs, they stand tall and powerful.
Black Cliff Rock	Black rock that looks like it came from a steep mountainside cliff.
Black Spotted Cliff Rock	It is rough and bumpy because it is packed with small rocks.
Skyland Cliff Rock	A type of rock that towers over all on mountain slopes. It can only be found at the skylands.
Skyland Spotted Cliff Rock	Lots of tiny stones are crammed in between skyland cliff rocks, giving them a rugged look.
White Rock	A pale, slightly hard rock that is tough to break.
Coarse Rock	A type of rock found here and there. It looks like it would be tough to process.
Light brown rock	A light-brown rock that you can find most anywhere.
Red Rock	A somewhat hard red rock often found near lava.
Yellow Rock	This stone is commonly found near volcanoes. Its smell makes your nose sting a little.
Black Rock	Rugged stone often found near volcanoes. It was originally molten-hot lava.
Lava Rock	When hot lava cools and hardens, it becomes black, rugged rock.
Cave Rock	Especially hard stone often found in caves.
Ocean Rock	Textured rock found by the seaside. It has been worn into this shape over time by ocean waves.
Reddish-Brown Cave Rock	This cave rock was originally black, but appears to have turned reddish as it oxidized over time.
Volcanic Rock	A rock with lots of tiny stone shards packed inside. Looks like it was formed by a volcanic eruption.
Carved White Rock	A rock with a curved shape carved into it. Fits snugly onto cave ceilings.
Carved Coarse Rock	A rock with a curved shape carved into it. Fits snugly onto cave ceilings.
Carved Light-Brown Rock	A rock with a curved shape carved into it. Fits snugly onto cave ceilings.
Carved Red Rock	A rock with a curved shape carved into it. Fits snugly onto cave ceilings.
Carved Yellow Rock	A rock with a curved shape carved into it. Fits snugly onto cave ceilings.
Copper Deposit (Ordinary Soil)	A rock with bluish-green copper embedded in it. Break it open to obtain copper ore.
Copper Deposit (Seashell Soil)	A rock with bluish-green copper embedded in it. Break it open to obtain copper ore.
Copper Deposit (Striped Soil)	A rock with bluish-green copper embedded in it. Break it open to obtain copper ore.
Copper Deposit (Pure-White Soil)	A rock with bluish-green copper embedded in it. Break it open to obtain copper ore.
Iron Deposit	A rock that looks like a chocolate cookie. Break it open to obtain iron ore.
Gold Deposit	A stone that shines with golden glints. Can be crushed and processed into gold.
Pokemetal Deposit	A glittering rock with Pokemetal embedded in it. Break it open to reveal Pokemetal fragments.
Mossy Soil	Moss loves growing in damp places. Venture deep into caves to find tons of it.
Gravel	Loose paving material made up of rocks of all sizes.
Limestone	This white stone is abundant in limestone caverns and can be processed into many things.
Glowing Stone	A mysterious stone that emits rainbow light. Put it somewhere dark to create a mystical atmosphere.
Mysterious Stone	A beautiful, transparent stone. It seems to possess a strange power.
Ice	Pristine, beautiful ice that is cold to the touch.
Cracked Sandstone	This sandstone looks ready to fall apart. Perhaps a well-placed Rock Smash might finish the job.
"""
}

private struct GeneratedCatalog: Decodable {
    var items: [GeneratedCatalogItem]
}

private struct GeneratedCatalogItem: Decodable {
    var id: String
    var name: String
    var category: String
    var description: String
    var kind: String
    var imagePath: String?
    var sources: [String]
    var recipe: GeneratedRecipe?
}

private struct GeneratedRecipe: Decodable {
    var ingredients: [GeneratedIngredient]
    var unlockSources: [String]
}

private struct GeneratedIngredient: Decodable {
    var name: String
}
