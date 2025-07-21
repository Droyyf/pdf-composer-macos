import Foundation

/// A simple wrapper to make strings Identifiable
struct IdentifiableString: Identifiable {
    let value: String
    var id: String { value }
}
