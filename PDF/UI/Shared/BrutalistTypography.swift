import SwiftUI

// MARK: - Heading Component
struct BrutalistHeading: View {
    var text: String
    var size: CGFloat = 48
    var color: Color = .black
    var tracking: CGFloat = 1.2
    var alignment: TextAlignment = .leading
    var addStroke: Bool = true
    var strokeWidth: CGFloat = 1.2
    var addNoise: Bool = true

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: size, weight: .black, design: .monospaced))
            .tracking(tracking)
            .multilineTextAlignment(alignment)
            .foregroundColor(color)
            .if(addStroke) { view in
                view.textStroke(color: color.opacity(0.3), width: strokeWidth)
            }
            .if(addNoise) { view in
                view.overlay(
                    Color.clear
                        .brutalistTexture(
                            style: BrutalistTexture.TextureStyle.grain,
                            intensity: 0.3,
                            color: color.opacity(0.6)
                        )
                        .blendMode(.overlay)
                )
            }
    }
}

// MARK: - Technical Text
struct BrutalistTechnicalText: View {
    var text: String
    var color: Color = .gray
    var size: CGFloat = 12
    var addDecorators: Bool = true
    var align: TextAlignment = .leading

    var body: some View {
        HStack(spacing: 6) {
            if addDecorators && align == .leading {
                Line()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .frame(width: 15, height: 1)
                    .foregroundColor(color)
            }

            Text(text.uppercased())
                .font(.system(size: size, weight: .medium, design: .monospaced))
                .foregroundColor(color)
                .multilineTextAlignment(align)

            if addDecorators && align == .trailing {
                Line()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .frame(width: 15, height: 1)
                    .foregroundColor(color)
            }
        }
    }
}

// MARK: - Caption
struct BrutalistCaption: View {
    var text: String
    var prefix: String = ""
    var color: Color = .gray
    var size: CGFloat = 10

    var body: some View {
        HStack(spacing: 4) {
            if !prefix.isEmpty {
                Text(prefix)
                    .font(.system(size: size, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }

            Text(text.uppercased())
                .font(.system(size: size, weight: .regular, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

// MARK: - Block Text
struct BrutalistBlockText: View {
    var title: String
    var subtitle: String = ""
    var description: String = ""
    var textColor: Color = .black
    var showTechnicalElements: Bool = true
    var alignment: TextAlignment = .leading

    var body: some View {
        VStack(alignment: alignment == .leading ? .leading : .trailing, spacing: 8) {
            if showTechnicalElements {
                BrutalistTechnicalText(
                    text: "DATA_BLOCK",
                    color: textColor.opacity(0.5),
                    size: 10,
                    align: alignment
                )
            }

            Text(title)
                .font(.system(size: 20, weight: .black, design: .default))
                .foregroundColor(textColor)
                .textStroke(color: textColor.opacity(0.3), width: 0.6)
                .multilineTextAlignment(alignment)

            if !subtitle.isEmpty {
                Text(subtitle.uppercased())
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(textColor.opacity(0.8))
                    .multilineTextAlignment(alignment)
            }

            if !description.isEmpty {
                Text(description)
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundColor(textColor.opacity(0.7))
                    .multilineTextAlignment(alignment)
                    .padding(.top, 4)
            }

            if showTechnicalElements {
                HStack {
                    if alignment == .trailing {
                        Spacer()
                    }

                    Line()
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
                        .frame(width: 40, height: 1)
                        .foregroundColor(textColor.opacity(0.4))
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }
}

// Helper shape for drawing dashed lines
struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 32) {
            BrutalistHeading(text: "FIGHT THE SYSTEM")
                .padding(.bottom, 10)

            HStack {
                VStack(alignment: .leading, spacing: 10) {
                    BrutalistTechnicalText(
                        text: "TECHNICAL DATA",
                        color: .gray,
                        addDecorators: true
                    )

                    BrutalistTechnicalText(
                        text: "NO DECORATORS",
                        color: .gray,
                        addDecorators: false
                    )
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 10) {
                    BrutalistTechnicalText(
                        text: "RIGHT ALIGNED",
                        color: .gray,
                        addDecorators: true,
                        align: .trailing
                    )

                    BrutalistCaption(
                        text: "DOCUMENT NAME",
                        prefix: "//",
                        color: .gray
                    )
                }
            }
            .padding(.bottom, 10)

            HStack(spacing: 20) {
                BrutalistBlockText(
                    title: "Primary Header",
                    subtitle: "SUPPORTING TEXT",
                    description: "This is a short description text that explains the content in more detail.",
                    textColor: .black
                )
                .frame(width: CGFloat(200))
                .padding(12)
                .background(Color.white)

                BrutalistBlockText(
                    title: "Right Aligned",
                    subtitle: "TECHNICAL DATA",
                    description: "Text aligned to the right with minimal decorations.",
                    textColor: .white,
                    showTechnicalElements: true,
                    alignment: .trailing
                )
                .frame(width: CGFloat(200))
                .padding(12)
                .background(Color.black)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.2))
    }
}
