import SwiftUI

struct FrameConfigSelector: View {
    @Binding var selectedConfig: FrameConfig

    // Array of available frame configurations with their display names
    private let availableConfigs: [(config: FrameConfig, name: String)] = [
        (FrameConfig.ornateClassicFrame, "Classic"),
        (FrameConfig.ornateGoldFrame, "Gold Ornate"),
        (FrameConfig.ornateGoldFrameLeftPage, "Left Page"),
        (FrameConfig.ornateGoldFrameRightPage, "Right Page")
    ]

    var body: some View {
        Picker("Frame Style", selection: $selectedConfig) {
            ForEach(availableConfigs.indices, id: \.self) { index in
                Text(availableConfigs[index].name)
                    .tag(availableConfigs[index].config)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }
}

struct FrameConfigSelector_Previews: PreviewProvider {
    static var previews: some View {
        @State var selectedConfig: FrameConfig = .ornateGoldFrame

        return FrameConfigSelector(selectedConfig: $selectedConfig)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
