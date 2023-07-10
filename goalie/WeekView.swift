import SwiftUI
import SystemColors

struct WeekView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    // TODO
                } label: {
                    Image(systemName: "arrow.left.circle")
                        .font(.body)
                        .foregroundColor(Color.label)
                        .padding(10)
                }
                .buttonStyle(.plain)
                Spacer()
                VStack(spacing: 1) {
                    Text("Week 1")
                        .font(.headline)
                    Text("July 9-15, 2023")
                        .font(.subheadline)
                }
                Spacer()
                Button {
                    // TODO
                } label: {
                    Image(systemName: "arrow.right.circle")
                        .font(.body)
                        .foregroundColor(Color.label)
                        .padding(10)
                }
                .buttonStyle(.plain)
                .disabled(false) // TODO: disable for future weeks
            }

            Spacer().frame(height: 8)

            VStack(spacing: 6) {
                ForEach(1 ..< 6) { _ in
                    HStack(spacing: 0) {
                        Image(systemName: "circle.dashed") // "circle.fill" "circle.bottomhalf.fill"
                            .font(.caption)
                            .foregroundColor(Color.label)
                        Text("7/9")
                            .monospacedDigit()
                            .padding(.horizontal, 4)
                        Spacer()
                        Text("02:02")
                            .monospacedDigit()
                        Text("/")
                            .foregroundColor(Color.tertiaryLabel)
                            .monospacedDigit()
                            .padding(.horizontal, 2)
                        Text("03:00")
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
        WeekView()
            .frame(width: 200)
    }
}
