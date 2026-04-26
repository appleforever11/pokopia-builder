import Foundation

enum BuildGeneratorProvider: String, CaseIterable, Identifiable {
    case local = "Free Local"
    case openAI = "OpenAI"

    var id: String { rawValue }
}

final class LocalBuildIdeaClient {
    private let model: String
    private let endpoint: URL
    private let session: URLSession

    init(model: String, endpoint: URL = URL(string: "http://localhost:11434/api/generate")!, session: URLSession = .shared) {
        self.model = model
        self.endpoint = endpoint
        self.session = session
    }

    func generateIdea(prompt: String, catalog: [PokopiaBlock]) async -> AIBuildIdea {
        do {
            return try await generateWithOllama(prompt: prompt, catalog: catalog)
        } catch {
            return heuristicIdea(prompt: prompt, catalog: catalog)
        }
    }

    private func generateWithOllama(prompt: String, catalog: [PokopiaBlock]) async throws -> AIBuildIdea {
        let names = catalog.prefix(160).map { "\($0.name) [\($0.category)]" }.joined(separator: "\n")
        let promptBody = """
        Generate a Pokemon Pokopia build plan from the user prompt.
        Use only exact item names from this catalog.
        Return compact JSON only:
        {"name":"short name","mood":"Cozy Cottage|Pokemon Center|Industrial|Ancient Ruins|Seaside|Neon Lab|Luxury|Wild Habitat","footprint":"12 x 12","notes":["3 short notes"],"materials":[{"name":"exact catalog item name","count":4,"x":0,"z":0,"rotationDegrees":0}]}
        Pick 8 to 16 materials. Use x and z integers from -6 to 6.

        User prompt: \(prompt)

        Catalog:
        \(names)
        """

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(OllamaRequest(
            model: model.isEmpty ? "llama3.2" : model,
            prompt: promptBody,
            stream: false,
            format: "json",
            options: ["temperature": 0.45]
        ))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw BuildGenerationError.invalidResponse
        }

        let envelope = try JSONDecoder().decode(OllamaResponse.self, from: data)
        guard let jsonData = envelope.response.cleanedJSON.data(using: .utf8) else {
            throw BuildGenerationError.invalidJSON
        }
        return try JSONDecoder().decode(AIBuildIdea.self, from: jsonData)
    }

    private func heuristicIdea(prompt: String, catalog: [PokopiaBlock]) -> AIBuildIdea {
        let lower = prompt.lowercased()
        let mood = inferredMood(from: lower)
        let keywords = inferredKeywords(from: lower, mood: mood)
        let ranked = rankedCatalog(catalog, keywords: keywords)
        let selected = balancedSelection(from: ranked, prompt: lower, mood: mood)
        let materials = selected.enumerated().map { index, block in
            AIMaterial(
                name: block.name,
                count: quantity(for: block, prompt: lower),
                x: Float((index % 5) - 2),
                z: Float((index / 5) - 1),
                rotationDegrees: block.prefersUprightSceneModel ? 0 : Float([0, 90, 180, 270][index % 4])
            )
        }

        return AIBuildIdea(
            name: generatedName(for: lower, mood: mood),
            mood: mood.rawValue,
            footprint: lower.contains("small") || lower.contains("compact") ? "8 x 8" : "12 x 12",
            notes: notes(for: lower, mood: mood),
            materials: materials.isEmpty ? fallbackMaterials(from: catalog) : Array(materials)
        )
    }

    private func inferredMood(from prompt: String) -> BuildMood {
        if prompt.contains("cyber") || prompt.contains("neon") || prompt.contains("lab") { return .neonLab }
        if prompt.contains("center") || prompt.contains("clinic") || prompt.contains("healing") { return .pokemonCenter }
        if prompt.contains("industrial") || prompt.contains("factory") || prompt.contains("steel") { return .industrial }
        if prompt.contains("ruin") || prompt.contains("ancient") || prompt.contains("mysterious") { return .ruins }
        if prompt.contains("beach") || prompt.contains("sea") || prompt.contains("resort") { return .seaside }
        if prompt.contains("luxury") || prompt.contains("palace") || prompt.contains("grand") { return .luxury }
        if prompt.contains("wild") || prompt.contains("forest") || prompt.contains("habitat") { return .wildHabitat }
        return .cozyCottage
    }

    private func inferredKeywords(from prompt: String, mood: BuildMood) -> [String] {
        var words = Set(prompt.split { !$0.isLetter && !$0.isNumber }.map { String($0).lowercased() })
        switch mood {
        case .neonLab:
            words.formUnion(["cyber", "neon", "hexagonal", "light", "computer", "monitor", "iron", "pokemetal", "lab", "desk"])
        case .pokemonCenter:
            words.formUnion(["pokemon", "center", "poke", "ball", "light", "counter", "healing", "shop"])
        case .industrial:
            words.formUnion(["iron", "pipe", "scaffold", "factory", "concrete", "warning", "generator"])
        case .ruins:
            words.formUnion(["aged", "stone", "moss", "glowing", "mysterious", "ancient"])
        case .seaside:
            words.formUnion(["beach", "sand", "shell", "resort", "water", "parasol", "ocean"])
        case .luxury:
            words.formUnion(["gold", "luxury", "antique", "marble", "crystal", "cushy"])
        case .wildHabitat:
            words.formUnion(["grass", "flower", "tree", "moss", "soil", "wild"])
        case .cozyCottage:
            words.formUnion(["wooden", "plain", "log", "flower", "lamp", "chair", "table"])
        }
        words.formUnion(["flooring", "road", "wall", "lamp", "table", "chair", "counter"])
        return Array(words)
    }

    private func balancedSelection(from ranked: [PokopiaBlock], prompt: String, mood: BuildMood) -> [PokopiaBlock] {
        var result: [PokopiaBlock] = []
        var used = Set<PokopiaBlock.ID>()

        func take(_ predicate: (PokopiaBlock) -> Bool, count: Int) {
            for block in ranked where result.count < 16 && predicate(block) && !used.contains(block.id) {
                result.append(block)
                used.insert(block.id)
                if result.filter(predicate).count >= count { break }
            }
        }

        take({ $0.kind == .floor || $0.kind == .terrain || $0.kind == .pattern || $0.name.lowercased().contains("road") }, count: 3)
        take({ $0.kind == .wall || $0.name.lowercased().contains("wall") || $0.name.lowercased().contains("partition") }, count: 2)
        take({ $0.category == "Furniture" || $0.name.lowercased().contains("counter") || $0.name.lowercased().contains("table") || $0.name.lowercased().contains("chair") }, count: 4)
        take({ $0.category == "Utilities" || $0.name.lowercased().contains("light") || $0.name.lowercased().contains("lamp") || $0.name.lowercased().contains("computer") }, count: 3)
        take({ $0.category == "Outdoor" || $0.category == "Food" || $0.category == "Items" }, count: 4)

        if result.count < 10 {
            for block in ranked where !used.contains(block.id) {
                result.append(block)
                used.insert(block.id)
                if result.count >= 14 { break }
            }
        }

        return result
    }

    private func rankedCatalog(_ catalog: [PokopiaBlock], keywords: [String]) -> [PokopiaBlock] {
        catalog
            .map { block -> (block: PokopiaBlock, score: Int) in
                let text = "\(block.name) \(block.category) \(block.description) \(block.recipeIngredients.joined(separator: " "))".lowercased()
                let score = keywords.reduce(0) { partial, keyword in
                    partial + (text.contains(keyword) ? 2 : 0) + (block.name.lowercased().contains(keyword) ? 3 : 0)
                }
                return (block, score)
            }
            .filter { $0.score > 0 }
            .sorted {
                if $0.score == $1.score { return $0.block.name < $1.block.name }
                return $0.score > $1.score
            }
            .map(\.block)
    }

    private func quantity(for block: PokopiaBlock, prompt: String) -> Int {
        switch block.kind {
        case .floor, .terrain, .pattern: return prompt.contains("large") ? 64 : 24
        case .wall: return prompt.contains("large") ? 48 : 18
        case .ore, .rock: return 8
        case .utility: return 3
        case .structure, .all: return 4
        }
    }

    private func generatedName(for prompt: String, mood: BuildMood) -> String {
        if prompt.contains("cyberpunk") { return "Cyberpunk Lair" }
        if prompt.contains("cafe") { return "Prompt Cafe Build" }
        if prompt.contains("lair") { return "\(mood.rawValue) Lair" }
        return "\(mood.rawValue) Prompt Build"
    }

    private func notes(for prompt: String, mood: BuildMood) -> [String] {
        [
            "Generated for: \(prompt.prefix(80))",
            "Place floor/path blocks first, then walls and focal items.",
            "Use repeated lighting and accent objects to make the theme readable.",
            mood == .neonLab ? "Keep neon, cyber, metal, and monitor items clustered like a high-tech room." : "Leave walking space between habitat items so the layout feels like an in-game build."
        ]
    }

    private func fallbackMaterials(from catalog: [PokopiaBlock]) -> [AIMaterial] {
        catalog.prefix(10).enumerated().map { index, block in
            AIMaterial(name: block.name, count: 4, x: Float(index % 5 - 2), z: Float(index / 5), rotationDegrees: 0)
        }
    }
}

private struct OllamaRequest: Encodable {
    var model: String
    var prompt: String
    var stream: Bool
    var format: String
    var options: [String: Double]
}

private struct OllamaResponse: Decodable {
    var response: String
}
