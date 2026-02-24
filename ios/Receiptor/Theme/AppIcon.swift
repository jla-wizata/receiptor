import SwiftUI

// MARK: - App Icon variants

enum AppIconVariant {
    case color  // full brand colors — for light backgrounds
    case white  // all-white — for colored/dark backgrounds
    case dark   // dark teal fill — for white backgrounds
}

// MARK: - Composited app icon view

struct AppIcon: View {
    var size: CGFloat = 60
    var variant: AppIconVariant = .color

    private var receiptFill: Color {
        switch variant {
        case .color: return .appPrimary
        case .white: return .white
        case .dark:  return Color(white: 0.15)
        }
    }

    private var lineFill: Color {
        switch variant {
        case .color: return Color.white.opacity(0.65)
        case .white: return Color.white.opacity(0.40)
        case .dark:  return Color.white.opacity(0.50)
        }
    }

    private var markerFill: Color {
        switch variant {
        case .color: return .appAccent
        case .white: return Color.white.opacity(0.85)
        case .dark:  return Color(white: 0.55)
        }
    }

    private var checkColor: Color {
        switch variant {
        case .color: return .appPrimary
        case .white: return Color(white: 0.30)
        case .dark:  return Color(white: 0.85)
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Receipt body
            ReceiptShape()
                .fill(receiptFill)
                .frame(width: size * 0.62, height: size * 0.76)
                .offset(x: size * 0.06, y: size * 0.04)

            // Three text-like lines on the receipt
            VStack(spacing: size * 0.065) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: size * 0.02)
                        .fill(lineFill)
                        .frame(width: size * 0.38, height: size * 0.045)
                }
            }
            .offset(x: size * 0.18, y: size * 0.23)

            // Amber date-marker badge — bottom-right
            Circle()
                .fill(markerFill)
                .frame(width: size * 0.32, height: size * 0.32)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.13, weight: .bold))
                        .foregroundColor(checkColor)
                )
                .offset(x: size * 0.55, y: size * 0.58)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Receipt silhouette shape (zigzag bottom)

struct ReceiptShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r    = rect.width * 0.09    // corner radius
        let zigH = rect.height * 0.11  // tooth height
        let n    = 5                    // number of teeth
        let segW = rect.width / CGFloat(n)

        // Top-left → top-right (rounded corners)
        path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + r),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )

        // Right edge down to zigzag start
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - zigH))

        // Zigzag across the bottom (right → left)
        for i in 0..<n {
            let xPeak = rect.maxX - CGFloat(i) * segW - segW * 0.5
            let xNext = rect.maxX - CGFloat(i + 1) * segW
            path.addLine(to: CGPoint(x: xPeak, y: rect.maxY))
            path.addLine(to: CGPoint(x: xNext, y: rect.maxY - zigH))
        }

        // Left edge up to top-left (rounded corner)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + r, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )

        path.closeSubpath()
        return path
    }
}
