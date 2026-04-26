import Foundation

struct AIBuildIdea: Decodable {
    var name: String
    var mood: String
    var footprint: String
    var notes: [String]
    var materials: [AIMaterial]
}

struct AIMaterial: Decodable {
    var name: String
    var count: Int
    var x: Float?
    var z: Float?
    var rotationDegrees: Float?
}

final class OpenAIBuildIdeaClient {
    private let apiKey: String
    private let model: String
    private let session: URLSession

    init(apiKey: String, model: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    func generateIdea(prompt: String, catalog: [PokopiaBlock]) async throws -> AIBuildIdea {
        let names = catalog
            .prefix(900)
            .map { "\($0.name) [\($0.kind.rawValue)]" }
            .joined(separator: "\n")

        let instructions = """
        You generate practical Pokemon Pokopia build ideas from the user's prompt.
        Use only item names from the provided local catalog.
        Return one compact JSON object with this exact shape:
        {
          "name": "short build name",
          "mood": "one of: Cozy Cottage, Pokemon Center, Industrial, Ancient Ruins, Seaside, Neon Lab, Luxury, Wild Habitat",
          "footprint": "short footprint like 12 x 12",
          "notes": ["3 to 5 concise placement notes"],
          "materials": [
            {"name": "exact catalog item name", "count": 12, "x": -2.0, "z": 1.5, "rotationDegrees": 0}
          ]
        }
        Pick 8 to 18 materials. Use x and z coordinates between -6 and 6 for a rough 3D layout.
        Do not include markdown fences or explanation outside JSON.
        """

        let body = ResponseRequest(
            model: model,
            instructions: instructions,
            input: """
            User prompt:
            \(prompt)

            Local catalog item names:
            \(names)
            """
        )

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BuildGenerationError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "OpenAI request failed."
            throw BuildGenerationError.api(message)
        }

        let decoded = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        let text = decoded.outputText ?? decoded.output.compactMap(\.text).joined()
        guard let jsonData = text.cleanedJSON.data(using: .utf8) else {
            throw BuildGenerationError.invalidJSON
        }
        return try JSONDecoder().decode(AIBuildIdea.self, from: jsonData)
    }
}

private struct ResponseRequest: Encodable {
    var model: String
    var instructions: String
    var input: String
}

private struct ResponseEnvelope: Decodable {
    var outputText: String?
    var output: [ResponseOutputItem]

    enum CodingKeys: String, CodingKey {
        case outputText = "output_text"
        case output
    }
}

private struct ResponseOutputItem: Decodable {
    var content: [ResponseContent]?

    var text: String? {
        content?.compactMap(\.text).joined()
    }
}

private struct ResponseContent: Decodable {
    var text: String?
}

enum BuildGenerationError: LocalizedError {
    case invalidResponse
    case invalidJSON
    case api(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "OpenAI returned an invalid response."
        case .invalidJSON:
            "ChatGPT did not return a build JSON object the app could read."
        case .api(let message):
            "OpenAI request failed: \(message)"
        }
    }
}

extension String {
    var cleanedJSON: String {
        var value = trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("```") {
            value = value
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = value.firstIndex(of: "{"), let end = value.lastIndex(of: "}") {
            return String(value[start...end])
        }
        return value
    }
}
