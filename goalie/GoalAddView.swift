import SwiftUI

struct GoalAddView: View {
    @State var selectedStep: Double // This is actually an Int

    private var save: ((TimeInterval?) -> Void)?
    @Environment(\.dismiss) private var dismiss

    init(initialGoal: TimeInterval?, save: ((TimeInterval?) -> Void)? = nil) {
        _selectedStep = State(initialValue: Self.step(from: initialGoal))
        self.save = save
    }

    private static let timeIntervalStep: Double = 60 * 5
    private static let maxTimeInterval: Double = 60 * 60 * 12
    private static let numberOfSteps: Double = maxTimeInterval / timeIntervalStep
    private static func step(from timeInterval: TimeInterval?) -> Double {
        if let timeInterval {
            return (timeInterval / timeIntervalStep).rounded(.up)
        } else {
            return 0
        }
    }

    private static func timeInterval(from step: Double) -> TimeInterval? {
        let roundedStep = step.rounded(.up)
        if roundedStep == 0 {
            return nil
        } else {
            return roundedStep * timeIntervalStep
        }
    }

    var stepTitle: String {
        Self.title(from: selectedStep)
    }

    private static func title(from step: Double) -> String {
        let convertedInterval = Self.timeInterval(from: step)
        if let convertedInterval {
            let duration = Duration.seconds(convertedInterval)
            return duration.formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 2, fractionalSecondsLength: 0, roundFractionalSeconds: .up)))
        } else {
            return "No goal"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text(stepTitle)
                    .font(.title)
                Spacer().frame(height: 6)
                Slider(value: $selectedStep, in: 0 ... Self.numberOfSteps) {} minimumValueLabel: {
                    Text("Off")
                } maximumValueLabel: {
                    Text(Self.title(from: Self.numberOfSteps))
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
                        save?(Self.timeInterval(from: selectedStep))
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
        GoalAddView(initialGoal: 60*60*10)
            .frame(width: 300, height: 200, alignment: .center)
    }
}
