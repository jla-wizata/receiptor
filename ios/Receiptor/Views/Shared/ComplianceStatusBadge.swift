import SwiftUI

struct ComplianceStatusBadge: View {
    let status: String

    private var isCompliant: Bool { status == "compliant" }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isCompliant ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.title2)
            Text(isCompliant ? "COMPLIANT" : "AT RISK")
                .font(.headline)
                .fontWeight(.bold)
        }
        .foregroundColor(isCompliant ? .appSuccess : .appDanger)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCompliant ? Color.appSuccess.opacity(0.15) : Color.appDanger.opacity(0.15))
        )
    }
}
