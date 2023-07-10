import SwiftUI
import SystemColors

struct WeekViewData {
    struct Day: Equatable, Identifiable {
        var id: String { dayTitle }
        let goalRatioSymbolName: String
        let dayTitle: String
        let duration: String
        let goal: String
    }
    let title: String
    let subtitle: String
    let previousWeekDisabled: Bool
    let nextWeekDisabled: Bool
    let days: [Day]
}

struct WeekScreen: View {
    var body: some View {
        WeekView(viewData: .mock)
    }
}

struct WeekView: View {
    let viewData: WeekViewData
    var previousWeekTapped: (() -> Void)?
    var nextWeekTapped: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    previousWeekTapped?()
                } label: {
                    Image(systemName: "arrow.left.circle")
                        .font(.body)
                        .foregroundColor(Color.label)
                        .padding(10)
                }
                .buttonStyle(.plain)
                .disabled(viewData.previousWeekDisabled)
                Spacer()
                VStack(spacing: 1) {
                    Text(viewData.title)
                        .font(.headline)
                    Text(viewData.subtitle)
                        .font(.subheadline)
                }
                Spacer()
                Button {
                    nextWeekTapped?()
                } label: {
                    Image(systemName: "arrow.right.circle")
                        .font(.body)
                        .foregroundColor(Color.label)
                        .padding(10)
                }
                .buttonStyle(.plain)
                .disabled(viewData.nextWeekDisabled)
            }

            Spacer().frame(height: 8)

            VStack(spacing: 6) {
                ForEach(viewData.days) { day in
                    HStack(spacing: 0) {
                        Image(systemName: day.goalRatioSymbolName) // "circle.fill" "circle.bottomhalf.fill"
                            .font(.caption)
                            .foregroundColor(Color.label)
                        Text(day.dayTitle)
                            .monospacedDigit()
                            .padding(.horizontal, 4)
                        Spacer()
                        Text(day.duration)
                            .monospacedDigit()
                        Text("/")
                            .foregroundColor(Color.tertiaryLabel)
                            .monospacedDigit()
                            .padding(.horizontal, 2)
                        Text(day.goal)
                            .foregroundColor(Color.tertiaryLabel)
                            .monospacedDigit()
                    }
                }
            }
        }
    }
}

struct WeekView_Previews: PreviewProvider {
    static var previews: some View {
        WeekView(viewData: .mock)
            .frame(width: 200)
    }
}

extension WeekViewData {
    static let mock: Self = .init(
        title: "Week 1",
        subtitle: "July 9-15, 2023",
        previousWeekDisabled: false,
        nextWeekDisabled: true,
        days: [
            .init(goalRatioSymbolName: "circle", dayTitle: "7/9", duration: "00:00", goal: "02:00"),
            .init(goalRatioSymbolName: "circle.fill", dayTitle: "7/10", duration: "03:31", goal: "02:00"),
            .init(goalRatioSymbolName: "circle.bottomhalf.fill", dayTitle: "7/11", duration: "02:00", goal: "03:00"),
            .init(goalRatioSymbolName: "circle.dotted", dayTitle: "7/12", duration: "--:--", goal: "03:00"),
            .init(goalRatioSymbolName: "circle.dotted", dayTitle: "7/13", duration: "--:--", goal: "03:00"),
            .init(goalRatioSymbolName: "circle.dotted", dayTitle: "7/14", duration: "--:--", goal: "03:00"),
            .init(goalRatioSymbolName: "circle.dotted", dayTitle: "7/15", duration: "--:--", goal: "03:00"),
        ]
    )
}
