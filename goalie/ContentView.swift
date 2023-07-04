import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("00:00:00")
                .font(.largeTitle)
            Spacer().frame(height: 2)
            HStack(spacing: 4) {
                Text("03:00:00")
                    .font(.title3)
                    .foregroundColor(Color(.secondaryLabelColor))

                Button {
                    // TODO: edit goal
                } label: {
                    HStack(spacing: 2) {
                        Text("Goal")
                        Image(systemName: "square.and.pencil")
                    }
                    .foregroundColor(Color(.tertiaryLabelColor))
                }
                .buttonStyle(.plain)
            }
            Spacer().frame(height: 16)
            Button {
                // TODO: start
            } label: {
                Text("Start")
                    .font(.title2)
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(colors: [Color.blue, Color.blue.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                    }
            }
            .buttonStyle(.plain)

            Spacer().frame(height: 10)

            Button {
                // TODO: edit goal
            } label: {
                HStack(spacing: 2) {
                    Text("**3** sessions today")
                        .font(.subheadline)
                        .foregroundColor(Color(.secondaryLabelColor))
                    Image(systemName: "square.and.pencil")
                }
                .foregroundColor(Color(.tertiaryLabelColor))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(maxWidth: 300)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
