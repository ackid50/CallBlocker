import Foundation

struct Rule: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var pattern: String
    var label: String
    var enabled: Bool = true
}
