import Foundation
import SwiftUI

class BackgroundEffectViewModel: ObservableObject {
    @Published var blur: Float = 2.0
    @Published var noise: Float = 0.2
    @Published var grain: Float = 0.2
    @Published var textureMix: Float = 0.5
    @Published var colorTint: Color = Color.white.opacity(0.0)
    @Published var vignette: Float = 0.2
}
