import SwiftUI

struct BrutalistGrid<Content: View>: View {
    var columns: Int = 2
    var spacing: CGFloat = 16
    var accentColor: Color = Color(DesignTokens.brutalistPrimary)
    var showHeader: Bool = true
    var headerTitle: String = "DATA GRID"
    var showGridLines: Bool = true
    var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Technical header
            if showHeader {
                HStack {
                    Text(headerTitle)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(accentColor)

                    Spacer()

                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(accentColor.opacity(Double(i + 1) / 4))
                                .frame(width: 4, height: 4)
                        }
                        Text("REALITY")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(accentColor.opacity(0.7))
                    }
                }
                .padding(.horizontal, DesignTokens.grid * 2)
                .padding(.top, DesignTokens.grid * 2)
                .padding(.bottom, DesignTokens.grid)

                // Technical line
                Rectangle()
                    .fill(accentColor.opacity(0.3))
                    .frame(height: 1)
                    .overlay(
                        HStack {
                            ForEach(0..<6, id: \.self) { i in
                                Rectangle()
                                    .fill(accentColor.opacity(0.8))
                                    .frame(width: 2, height: 3)
                            }
                            Spacer()
                        }
                        .padding(.leading, DesignTokens.grid * 2)
                    )
            }

            // Grid content
            Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
                ForEach(0..<Int(ceil(Double(itemCount) / Double(columns))), id: \.self) { row in
                    GridRow {
                        ForEach(0..<columns, id: \.self) { column in
                            let index = row * columns + column
                            if index < itemCount {
                                gridItemAt(index)
                                    .gridCellUnsizedAxes([.horizontal, .vertical])
                            } else {
                                Color.clear
                                    .gridCellUnsizedAxes([.horizontal, .vertical])
                            }
                        }
                    }
                }
            }
            .padding(DesignTokens.grid * 2)
            .overlay(
                ZStack {
                    if showGridLines {
                        // Vertical lines
                        HStack(spacing: 0) {
                            ForEach(0..<columns-1, id: \.self) { i in
                                Spacer()
                                Rectangle()
                                    .fill(accentColor.opacity(0.15))
                                    .frame(width: 1)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, DesignTokens.grid * 2)

                        // Horizontal lines
                        VStack(spacing: 0) {
                            ForEach(0..<Int(ceil(Double(itemCount) / Double(columns)))-1, id: \.self) { i in
                                Spacer()
                                Rectangle()
                                    .fill(accentColor.opacity(0.15))
                                    .frame(height: 1)
                            }
                            Spacer()
                        }
                        .padding(.vertical, DesignTokens.grid * 2)
                    }
                }
            )

            // Technical footer
            HStack {
                Text("◇ STATUS: \(Int.random(in: 10001...99999))")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(accentColor.opacity(0.7))

                Spacer()

                Text("\(itemCount) ITEMS")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(accentColor.opacity(0.7))
            }
            .padding(.horizontal, DesignTokens.grid * 2)
            .padding(.bottom, DesignTokens.grid * 2)
        }
        .background(Color(DesignTokens.brutalistBlack).opacity(0.9))
        .overlay(
            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCornersAlt, style: .continuous)
                .strokeBorder(accentColor.opacity(0.3), lineWidth: 1)
        )
        .clipShape(UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCornersAlt, style: .continuous))
    }

    // Get view at specific index, handling arrays of children
    @ViewBuilder
    private func gridItemAt(_ index: Int) -> some View {
        ZStack {
            ViewExtractor(content: content())
                .extractView(at: index)
        }
    }

    private var itemCount: Int {
        ViewExtractor(content: content()).count
    }
}

// Helper struct to extract views from a view builder
struct ViewExtractor<Content: View>: View {
    let content: Content

    var body: some View {
        content
    }

    func extractView(at index: Int) -> AnyView {
        let mirror = Mirror(reflecting: content)

        // Handle TupleView for multiple child views
        if let tupleContent = mirror.descendant("content") {
            let tupleMirror = Mirror(reflecting: tupleContent)
            let children = tupleMirror.children

            if index < children.count {
                let child = Array(children)[index]
                if let view = child.value as? any View {
                    return AnyView(view)
                }
            }
        }

        // Handle single child or fallback
        return AnyView(EmptyView())
    }

    var count: Int {
        let mirror = Mirror(reflecting: content)

        // Handle TupleView for multiple child views
        if let tupleContent = mirror.descendant("content") {
            let tupleMirror = Mirror(reflecting: tupleContent)
            return tupleMirror.children.count
        }

        // Just one view
        return 1
    }
}

// BrutalistText is defined in BrutalistText.swift

// View extension for conditional modifiers is already defined in ColorExtensions.swift

#Preview {
    ZStack {
        Color(DesignTokens.bg900).ignoresSafeArea()

        VStack {
            BrutalistGrid(accentColor: .pink) {
                ForEach(0..<5, id: \.self) { i in
                    Image(systemName: ["eye.fill", "network", "grid", "waveform.path", "circle.hexagongrid.fill"][i])
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(20)
                        .background(Color.black)
                }
            }

            BrutalistGrid(columns: 1, accentColor: .orange, headerTitle: "BRUTALIST DATA") {
                VStack {
                    BrutalistText("INTENT", style: .title)
                        .frame(maxWidth: .infinity)
                    BrutalistText("WITH CLEAR INTENT", style: .caption)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 120)
                .background(Color.black)
            }
        }
        .padding()
    }
}
