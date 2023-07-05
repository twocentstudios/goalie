import SwiftUI

struct GoalAddView: View {
    @State var selectedInterval: TimeInterval

    var save: ((TimeInterval) -> Void)?
    @Environment(\.dismiss) private var dismiss

    var intervalTitle: String {
        if selectedInterval == 0 {
            return "No goal"
        } else {
            let duration = Duration.seconds(selectedInterval)
            return duration.formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 0, roundFractionalSeconds: .towardZero)))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text(intervalTitle)
                    .font(.title)
                Spacer().frame(height: 6)
                Slider(value: $selectedInterval, in: 0 ... 60 * 60 * 12, step: 10 * 60) {} minimumValueLabel: {
                    Text("Off")
                } maximumValueLabel: {
                    Text("12:00:00")
                }

                Spacer().frame(height: 16)
                Text("Setting a daily goal will update it for today onward (past goals will not be affected).")
                    .lineLimit(nil)
                    .font(.caption)
                    .foregroundColor(Color(.tertiaryLabelColor))
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .frame(minHeight: 200, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save?(selectedInterval)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Set Goal")
        }
    }
}

struct GoalAddView_Previews: PreviewProvider {
    static var previews: some View {
        GoalAddView(selectedInterval: 0)
            .frame(width: 300, height: 200, alignment: .center)
    }
}
