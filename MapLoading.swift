import Foundation

enum MapLoadError: Error, Equatable, CustomStringConvertible {
    case fileNotFound(String)
    case decodingFailed(String)
    case invalid([MapIssue])

    var description: String {
        switch self {
        case .fileNotFound(let name):
            return "Map file '\(name)' was not found in the app bundle."
        case .decodingFailed(let detail):
            return "Map file could not be read: \(detail)"
        case .invalid(let issues):
            let errors = issues.filter { $0.severity == .error }.map(\.message)
            return "Map file has \(errors.count) error(s): " + errors.joined(separator: " ")
        }
    }
}

extension CampusMap {
    /// The demo map shipped inside the app (`Resources/demo_map.json`).
    static let demoResourceName = "demo_map"

    /// Decodes and validates a map. Throws if the data has any validation errors,
    /// so the app never routes on a map it knows is inconsistent.
    static func load(from data: Data) throws -> CampusMap {
        let map: CampusMap
        do {
            map = try JSONDecoder().decode(CampusMap.self, from: data)
        } catch let error as DecodingError {
            throw MapLoadError.decodingFailed(Self.describe(error))
        }

        let issues = MapValidator.validate(map)
        if issues.contains(where: { $0.severity == .error }) {
            throw MapLoadError.invalid(issues)
        }
        return map
    }

    static func load(resource name: String = demoResourceName, in bundle: Bundle) throws -> CampusMap {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw MapLoadError.fileNotFound("\(name).json")
        }
        return try load(from: Data(contentsOf: url))
    }

    /// Turns Swift's verbose DecodingError into a short message that points at the
    /// broken JSON key, which is the part you need when editing the map by hand.
    private static func describe(_ error: DecodingError) -> String {
        func path(_ context: DecodingError.Context) -> String {
            let keys = context.codingPath.map { $0.intValue.map(String.init) ?? $0.stringValue }
            return keys.isEmpty ? "(top level)" : keys.joined(separator: ".")
        }
        switch error {
        case .keyNotFound(let key, let context):
            return "missing key '\(key.stringValue)' at \(path(context))"
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .dataCorrupted(let context):
            return "\(context.debugDescription) at \(path(context))"
        @unknown default:
            return String(describing: error)
        }
    }
}
