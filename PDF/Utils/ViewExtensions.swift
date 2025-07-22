import SwiftUI

// MARK: - Conditional View Extension
extension View {
    /// Conditionally applies a transformation to the view
    /// - Parameters:
    ///   - condition: The condition to evaluate
    ///   - transform: The transformation to apply if the condition is true
    /// - Returns: The transformed view if condition is true, otherwise the original view
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Conditionally applies one of two transformations to the view
    /// - Parameters:
    ///   - condition: The condition to evaluate
    ///   - ifTransform: The transformation to apply if the condition is true
    ///   - elseTransform: The transformation to apply if the condition is false
    /// - Returns: The transformed view based on the condition
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        if ifTransform: (Self) -> TrueContent,
        else elseTransform: (Self) -> FalseContent
    ) -> some View {
        if condition {
            ifTransform(self)
        } else {
            elseTransform(self)
        }
    }
}

// MARK: - Identifiable String Helper
struct IdentifiableString: Identifiable {
    let id = UUID()
    let value: String
}

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