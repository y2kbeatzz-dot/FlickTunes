import SwiftUI

enum FlickStyle {
    static let violet = Color(red: 0.58, green: 0.28, blue: 0.98)
    static let pink = Color(red: 1.0, green: 0.28, blue: 0.59)
    static let background = LinearGradient(colors: [Color(red: 0.14, green: 0.07, blue: 0.24), Color(red: 0.05, green: 0.04, blue: 0.11)], startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct StatusCard: View {
    let symbol: String
    let headline: String
    let subheadline: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.title2).foregroundStyle(FlickStyle.pink)
            VStack(alignment: .leading, spacing: 5) {
                Text(headline).font(.headline).foregroundStyle(.white)
                Text(subheadline).font(.subheadline).foregroundStyle(.white.opacity(0.7))
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
    }
}
