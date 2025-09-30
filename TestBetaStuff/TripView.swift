import Foundation
import SwiftUI

public struct TripView: View {
  let vo: TripModel
  public init(vo: TripModel) {
    self.vo = vo
  }
  
  public var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(vo.country)
        .font(.title2)
        .fontWeight(.semibold)
        .padding(.bottom, 4)
      
      ForEach(vo.cities, id: \.self) { city in
        Text("• \(city)")
          .font(.body)
          .foregroundColor(.secondary)
      }
    }
    .padding()
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    )
  }
}
