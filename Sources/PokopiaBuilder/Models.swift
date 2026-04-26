import Foundation
import SwiftUI

enum BlockKind: String, CaseIterable, Identifiable {
    case all = "All"
    case wall = "Walls"
    case floor = "Flooring"
    case terrain = "Terrain"
    case rock = "Rock"
    case ore = "Ore"
    case pattern = "Prints"
    case structure = "Structures"
    case utility = "Utility"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .all: "square.grid.2x2"
        case .wall: "rectangle.split.3x1"
        case .floor: "square.grid.3x3"
        case .terrain: "leaf"
        case .rock: "mountain.2"
        case .ore: "diamond"
        case .pattern: "swatchpalette"
        case .structure: "building.2"
        case .utility: "lightbulb"
        }
    }
}

enum BuildMood: String, CaseIterable, Identifiable {
    case cozyCottage = "Cozy Cottage"
    case pokemonCenter = "Pokemon Center"
    case industrial = "Industrial"
    case ruins = "Ancient Ruins"
    case seaside = "Seaside"
    case neonLab = "Neon Lab"
    case luxury = "Luxury"
    case wildHabitat = "Wild Habitat"

    var id: String { rawValue }
}

struct PokopiaBlock: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let kind: BlockKind
    let imagePath: String?
    var category: String = "Items"
    var recipeIngredients: [String] = []
    var unlockSources: [String] = []
    var dataSources: [String] = []

    var tint: Color {
        switch kind {
        case .all: .gray
        case .wall: .teal
        case .floor: .green
        case .terrain: .mint
        case .rock: .gray
        case .ore: .yellow
        case .pattern: .pink
        case .structure: .orange
        case .utility: .cyan
        }
    }
}

struct PlacedBlock: Identifiable, Hashable {
    let id = UUID()
    var block: PokopiaBlock
    var count: Int
    var position: SIMD3<Float> = .zero
    var rotation: Float = 0
    var footprint: SIMD2<Float> = SIMD2<Float>(1, 1)
}

struct BuildIdea {
    var name: String
    var mood: BuildMood
    var footprint: String
    var blocks: [PlacedBlock]
    var notes: [String]
}

@MainActor
final class PlannerStore: ObservableObject {
    @Published var searchText = ""
    @Published var selectedKind: BlockKind = .all
    @Published var selectedBlock: PokopiaBlock?
    @Published var buildBlocks: [PlacedBlock] = []
    @Published var generatedIdea: BuildIdea?
    @Published var mood: BuildMood = .cozyCottage
    @Published private(set) var blocks: [PokopiaBlock]
    @Published var promptText = "Design a compact Pokemon Center plaza with a path, healing counter, lights, and cozy outdoor seating."
    @Published var openAIAPIKey: String
    @Published var model = "llama3.2"
    @Published var openAIModel = "gpt-5"
    @Published var generatorProvider: BuildGeneratorProvider = .local
    @Published var isGeneratingAI = false
    @Published var statusMessage: String?

    init() {
        blocks = PokopiaData.loadCatalog()
        openAIAPIKey = UserDefaults.standard.string(forKey: "OpenAIAPIKey") ?? ""
    }

    var filteredBlocks: [PokopiaBlock] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return blocks.filter { block in
            let matchesKind = selectedKind == .all || block.kind == selectedKind
            let matchesQuery = query.isEmpty
                || block.name.lowercased().contains(query)
                || block.description.lowercased().contains(query)
            return matchesKind && matchesQuery
        }
    }

    var totalBlocks: Int {
        buildBlocks.reduce(0) { $0 + $1.count }
    }

    func add(_ block: PokopiaBlock, count: Int = 8, position: SIMD3<Float>? = nil) {
        if let index = buildBlocks.firstIndex(where: { $0.block.id == block.id }) {
            buildBlocks[index].count += count
            if let position {
                buildBlocks[index].position = Self.snapped(position)
            }
        } else {
            buildBlocks.append(PlacedBlock(
                block: block,
                count: count,
                position: Self.snapped(position ?? nextAutoPosition()),
                rotation: block.prefersUprightSceneModel ? 0 : Float.random(in: -0.28...0.28),
                footprint: block.kind.defaultFootprint
            ))
        }
        selectedBlock = block
    }

    func addItem(with id: PokopiaBlock.ID, at position: SIMD3<Float>) {
        guard let block = blocks.first(where: { $0.id == id }) else { return }
        add(block, count: 1, position: position)
    }

    func remove(_ placed: PlacedBlock) {
        buildBlocks.removeAll { $0.id == placed.id }
    }

    func update(_ placed: PlacedBlock, count: Int) {
        guard let index = buildBlocks.firstIndex(where: { $0.id == placed.id }) else { return }
        buildBlocks[index].count = max(1, min(999, count))
    }

    func move(_ placed: PlacedBlock, to position: SIMD3<Float>) {
        guard let index = buildBlocks.firstIndex(where: { $0.id == placed.id }) else { return }
        buildBlocks[index].position = Self.snapped(position)
    }

    func clearBuild() {
        buildBlocks.removeAll()
        generatedIdea = nil
    }

    func randomize() {
        let pools = mood.preferredKinds
        let matching = blocks.filter { pools.contains($0.kind) }
        let base = matching.isEmpty ? blocks : matching
        let picked = Array(base.shuffled().prefix(Int.random(in: 7...12)))
        let plan = picked.enumerated().map { index, block in
            PlacedBlock(
                block: block,
                count: Int.random(in: block.kind.quantityRange),
                position: Self.position(for: index, total: picked.count),
                rotation: block.prefersUprightSceneModel ? 0 : Float.random(in: -0.45...0.45),
                footprint: block.kind.defaultFootprint
            )
        }

        buildBlocks = plan
        generatedIdea = BuildIdea(
            name: mood.generatedName,
            mood: mood,
            footprint: ["8 x 8", "10 x 12", "12 x 16", "18 x 18", "freeform habitat"].randomElement() ?? "10 x 12",
            blocks: plan,
            notes: mood.notes
        )
    }

    func exportSummary() -> String {
        let title = generatedIdea?.name ?? "Custom Pokopia Build"
        let rows = buildBlocks
            .sorted { $0.block.name < $1.block.name }
            .map { "- \($0.block.name): \($0.count)" }
            .joined(separator: "\n")

        return """
        \(title)
        Mood: \(generatedIdea?.mood.rawValue ?? mood.rawValue)
        Footprint: \(generatedIdea?.footprint ?? "Custom")
        Total blocks: \(totalBlocks)

        Materials:
        \(rows)
        """
    }

    func saveAPIKey() {
        UserDefaults.standard.set(openAIAPIKey, forKey: "OpenAIAPIKey")
    }

    func generateFromPrompt() async {
        isGeneratingAI = true
        statusMessage = generatorProvider == .local ? "Generating locally..." : "Asking OpenAI for a build plan..."
        defer { isGeneratingAI = false }

        do {
            let catalog = relevantCatalog(for: promptText)
            let idea: AIBuildIdea

            switch generatorProvider {
            case .local:
                let client = LocalBuildIdeaClient(model: model)
                idea = await client.generateIdea(prompt: promptText, catalog: catalog)
            case .openAI:
                let key = openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty else {
                    statusMessage = "Add an OpenAI API key, or switch to Free Local."
                    return
                }
                saveAPIKey()
                let client = OpenAIBuildIdeaClient(apiKey: key, model: openAIModel)
                idea = try await client.generateIdea(prompt: promptText, catalog: catalog)
            }

            apply(aiIdea: idea)
            statusMessage = "Generated \(idea.name)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func apply(aiIdea: AIBuildIdea) {
        let mapped = aiIdea.materials.enumerated().compactMap { index, material -> PlacedBlock? in
            guard let block = bestMatch(for: material.name) else { return nil }
            let arranged = Self.arrangedPosition(for: block, index: index)
            let position = SIMD3<Float>(material.x ?? arranged.x, 0, material.z ?? arranged.z)
            return PlacedBlock(
                block: block,
                count: max(1, min(999, material.count)),
                position: Self.snapped(position),
                rotation: Self.arrangedRotation(for: block, fallbackDegrees: material.rotationDegrees),
                footprint: block.kind.defaultFootprint
            )
        }

        guard !mapped.isEmpty else {
            statusMessage = "ChatGPT returned a plan, but none of its item names matched the local catalog."
            return
        }

        buildBlocks = mapped
        generatedIdea = BuildIdea(
            name: aiIdea.name,
            mood: BuildMood(rawValue: aiIdea.mood) ?? mood,
            footprint: aiIdea.footprint,
            blocks: mapped,
            notes: aiIdea.notes
        )
    }

    private func bestMatch(for name: String) -> PokopiaBlock? {
        let target = Self.normalized(name)
        if let exact = blocks.first(where: { Self.normalized($0.name) == target }) {
            return exact
        }
        return blocks.max { lhs, rhs in
            Self.matchScore(Self.normalized(lhs.name), target) < Self.matchScore(Self.normalized(rhs.name), target)
        }
    }

    private func relevantCatalog(for prompt: String) -> [PokopiaBlock] {
        let words = Set(prompt.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
        let themeWords: Set<String> = {
            var values = words
            if words.contains("cyberpunk") || words.contains("cyber") || words.contains("neon") {
                values.formUnion(["cyber", "neon", "hexagonal", "iron", "light", "computer", "monitor", "desk", "pokemetal"])
            }
            if words.contains("beach") || words.contains("seaside") || words.contains("resort") {
                values.formUnion(["beach", "sand", "resort", "shell", "water", "parasol", "ocean"])
            }
            if words.contains("center") || words.contains("healing") {
                values.formUnion(["pokemon", "center", "poke", "ball", "counter", "light"])
            }
            return values
        }()

        let ranked = blocks
            .map { block -> (PokopiaBlock, Int) in
                let haystack = "\(block.name) \(block.category) \(block.description) \(block.recipeIngredients.joined(separator: " "))".lowercased()
                let score = themeWords.reduce(0) { partial, word in
                    partial + (haystack.contains(word) ? 2 : 0) + (block.name.lowercased().contains(word) ? 3 : 0)
                }
                let usefulBonus = ["Blocks", "Furniture", "Utilities", "Outdoor", "Food", "Materials"].contains(block.category) ? 1 : 0
                return (block, score + usefulBonus)
            }
            .sorted {
                if $0.1 == $1.1 { return $0.0.name < $1.0.name }
                return $0.1 > $1.1
            }
            .map(\.0)

        return Array(ranked.prefix(180))
    }

    private func nextAutoPosition() -> SIMD3<Float> {
        Self.position(for: buildBlocks.count, total: max(buildBlocks.count + 1, 8))
    }

    private static func position(for index: Int, total: Int) -> SIMD3<Float> {
        let columns = max(3, Int(ceil(sqrt(Double(total)))))
        let row = index / columns
        let column = index % columns
        let x = Float(column - columns / 2) * 1.0
        let z = Float(row - columns / 2) * 1.0
        return SIMD3<Float>(x, 0, z)
    }

    private static func arrangedPosition(for block: PokopiaBlock, index: Int) -> SIMD3<Float> {
        let name = block.name.lowercased()
        let category = block.category.lowercased()

        if block.kind == .floor || block.kind == .terrain || block.kind == .pattern || name.contains("road") || name.contains("floor") {
            let floorSlots: [SIMD3<Float>] = [
                SIMD3<Float>(-2, 0, 0), SIMD3<Float>(-1, 0, 0), SIMD3<Float>(0, 0, 0), SIMD3<Float>(1, 0, 0), SIMD3<Float>(2, 0, 0),
                SIMD3<Float>(-2, 0, 1), SIMD3<Float>(-1, 0, 1), SIMD3<Float>(0, 0, 1), SIMD3<Float>(1, 0, 1), SIMD3<Float>(2, 0, 1)
            ]
            return floorSlots[index % floorSlots.count]
        }

        if block.kind == .wall || name.contains("wall") || name.contains("partition") {
            let wallSlots: [SIMD3<Float>] = [
                SIMD3<Float>(-3, 0, -2), SIMD3<Float>(-2, 0, -2), SIMD3<Float>(-1, 0, -2), SIMD3<Float>(0, 0, -2), SIMD3<Float>(1, 0, -2), SIMD3<Float>(2, 0, -2), SIMD3<Float>(3, 0, -2),
                SIMD3<Float>(-3, 0, -1), SIMD3<Float>(3, 0, -1), SIMD3<Float>(-3, 0, 0), SIMD3<Float>(3, 0, 0)
            ]
            return wallSlots[index % wallSlots.count]
        }

        if category == "utilities" || name.contains("light") || name.contains("lamp") || name.contains("streetlight") {
            let lightSlots = [SIMD3<Float>(-3, 0, 2), SIMD3<Float>(3, 0, 2), SIMD3<Float>(-3, 0, -2), SIMD3<Float>(3, 0, -2)]
            return lightSlots[index % lightSlots.count]
        }

        if category == "furniture" || name.contains("table") || name.contains("chair") || name.contains("counter") || name.contains("sofa") || name.contains("bed") {
            let furnitureSlots = [SIMD3<Float>(-1, 0, 2), SIMD3<Float>(0, 0, 2), SIMD3<Float>(1, 0, 2), SIMD3<Float>(-2, 0, 1), SIMD3<Float>(2, 0, 1)]
            return furnitureSlots[index % furnitureSlots.count]
        }

        if category == "materials" || category == "raw materials" || category == "processed materials" {
            let materialSlots = [SIMD3<Float>(-2, 0, 3), SIMD3<Float>(-1, 0, 3), SIMD3<Float>(0, 0, 3), SIMD3<Float>(1, 0, 3), SIMD3<Float>(2, 0, 3)]
            return materialSlots[index % materialSlots.count]
        }

        let decorSlots = [SIMD3<Float>(-2, 0, -1), SIMD3<Float>(2, 0, -1), SIMD3<Float>(-1, 0, 1), SIMD3<Float>(1, 0, 1), SIMD3<Float>(0, 0, -1)]
        return decorSlots[index % decorSlots.count]
    }

    private static func arrangedRotation(for block: PokopiaBlock, fallbackDegrees: Float?) -> Float {
        let name = block.name.lowercased()
        if block.prefersUprightSceneModel { return 0 }
        if block.kind == .wall || name.contains("wall") || name.contains("partition") {
            return name.contains("left") || name.contains("right") ? .pi / 2 : 0
        }
        return (fallbackDegrees ?? 0) * .pi / 180
    }

    private static func snapped(_ position: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3<Float>(
            max(-8, min(8, round(position.x))),
            0,
            max(-8, min(8, round(position.z)))
        )
    }

    private static func normalized(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "", options: .regularExpression)
    }

    private static func matchScore(_ lhs: String, _ rhs: String) -> Int {
        if lhs == rhs { return 10_000 }
        if lhs.contains(rhs) || rhs.contains(lhs) { return 5_000 + min(lhs.count, rhs.count) }
        let lhsTokens = Set(lhs.split(separator: " "))
        let rhsTokens = Set(rhs.split(separator: " "))
        return lhsTokens.intersection(rhsTokens).count
    }
}

extension PokopiaBlock {
    var prefersUprightSceneModel: Bool {
        let loweredCategory = category.lowercased()
        if loweredCategory == "blocks" || loweredCategory == "build parts" {
            return false
        }

        switch kind {
        case .floor, .terrain, .wall, .pattern:
            return false
        default:
            return true
        }
    }
}

private extension BlockKind {
    var quantityRange: ClosedRange<Int> {
        switch self {
        case .wall: 12...72
        case .floor: 16...96
        case .terrain: 20...128
        case .rock: 8...48
        case .ore: 4...18
        case .pattern: 8...48
        case .structure: 6...36
        case .utility: 2...12
        case .all: 4...32
        }
    }

    var defaultFootprint: SIMD2<Float> {
        switch self {
        case .wall: SIMD2<Float>(1.2, 0.24)
        case .floor, .terrain, .pattern: SIMD2<Float>(1.1, 1.1)
        case .rock, .ore: SIMD2<Float>(0.9, 0.9)
        case .structure: SIMD2<Float>(1.2, 1.2)
        case .utility: SIMD2<Float>(0.75, 0.75)
        case .all: SIMD2<Float>(1, 1)
        }
    }
}

private extension BuildMood {
    var preferredKinds: Set<BlockKind> {
        switch self {
        case .cozyCottage: [.wall, .floor, .terrain, .pattern]
        case .pokemonCenter: [.wall, .floor, .utility, .pattern]
        case .industrial: [.wall, .floor, .ore, .utility, .structure]
        case .ruins: [.rock, .wall, .floor, .terrain]
        case .seaside: [.terrain, .rock, .floor, .wall]
        case .neonLab: [.floor, .utility, .wall, .ore]
        case .luxury: [.wall, .floor, .pattern, .utility]
        case .wildHabitat: [.terrain, .rock, .floor, .structure]
        }
    }

    var generatedName: String {
        switch self {
        case .cozyCottage: "Ditto's Timber Hideaway"
        case .pokemonCenter: "Pocket Plaza Clinic"
        case .industrial: "Steel-Type Workshop"
        case .ruins: "Mysterious Slate Ruins"
        case .seaside: "Seashore Boardwalk"
        case .neonLab: "Rotom Research Lab"
        case .luxury: "Gholdengo Grand Suite"
        case .wildHabitat: "Leafage Habitat Trail"
        }
    }

    var notes: [String] {
        switch self {
        case .cozyCottage:
            ["Use warm wall blocks as the shell.", "Mix patterned prints as accent rugs.", "Keep terrain blocks around the edges for a soft garden border."]
        case .pokemonCenter:
            ["Stack matching Pokemon Center wall sections in trim, upper, middle, lower order.", "Use bright flooring to guide the entry.", "Reserve cube lights for healing stations and counters."]
        case .industrial:
            ["Pair iron walls with plating and deposits.", "Use warning walls to mark restricted corners.", "Break up metal surfaces with concrete or rough walls."]
        case .ruins:
            ["Combine aged-stone, carved rocks, and mossy soil.", "Leave gaps for an excavated look.", "Use glowing or mysterious stones as discovery points."]
        case .seaside:
            ["Blend sand, seashell soil, sandstone, and ocean-worn rocks.", "Use roads or marked roads as boardwalk paths.", "Keep brighter blocks near entrances."]
        case .neonLab:
            ["Use cyber or neon flooring as the main grid.", "Frame rooms with iron, crystal, or warning walls.", "Place cube lights in repeated intervals."]
        case .luxury:
            ["Use antique, gold, crystal, marble, and cushy wall pieces.", "Repeat one ornate block as a rhythm instead of using every fancy piece.", "Add dark marble or extravagant carpeting for contrast."]
        case .wildHabitat:
            ["Start with grass and soil blocks.", "Add cliffs and rocks as natural elevation.", "Use levees or foundations only where paths need structure."]
        }
    }
}
