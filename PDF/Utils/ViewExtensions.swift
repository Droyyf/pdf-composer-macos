import SwiftUI

// MARK: - View Extensions
// Note: Conditional 'if' extensions are defined in ColorExtensions.swift
// Note: IdentifiableString is defined in IdentifiableString.swift

// MARK: - Animatable Offset
struct AnimatableOffsetModifier: AnimatableModifier {
    var offset: CGSize
    
    var animatableData: CGSize.AnimatableData {
        get { CGSize.AnimatableData(offset.width, offset.height) }
        set { offset = CGSize(width: newValue.first, height: newValue.second) }
    }
    
    func body(content: Content) -> some View {
        content.offset(offset)
    }
}

extension View {
    func animatableOffset(_ offset: CGSize) -> some View {
        self.modifier(AnimatableOffsetModifier(offset: offset))
    }
}