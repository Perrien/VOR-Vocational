import Foundation

/// Bundle boundary for authored flight-plan files. Decoding and validation are
/// intentionally separate: this catalog reads bytes, while
/// `FlightPlanResolver` checks the plan against a particular world.
nonisolated enum FlightPlanCatalog {
    enum CatalogError: Error, Equatable, LocalizedError {
        case resourceNotFound(String)
        case unreadableResource(String)
        case invalidPlan(String)

        var errorDescription: String? {
            switch self {
            case .resourceNotFound(let name):
                return "Bundled flight plan \(name).json is missing."
            case .unreadableResource(let name):
                return "Bundled flight plan \(name).json could not be read."
            case .invalidPlan(let name):
                return "Bundled flight plan \(name).json is malformed."
            }
        }
    }

    static func load(named name: String, from bundle: Bundle = .main) throws -> FlightPlan {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw CatalogError.resourceNotFound(name)
        }
        guard let data = try? Data(contentsOf: url) else {
            throw CatalogError.unreadableResource(name)
        }
        do {
            return try JSONDecoder().decode(FlightPlan.self, from: data)
        } catch {
            throw CatalogError.invalidPlan(name)
        }
    }
}
