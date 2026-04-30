import SwiftUI

extension PainIntensityLevel {
    @MainActor var image: some View {
        PainIntensityImage(level: self)
    }

    @MainActor var colorValue: SymiColorValue {
        SymiColorValue(hex: metadata.colorHex)
    }

    @MainActor var tintColor: Color {
        colorValue.color
    }

    @MainActor var selectedBackgroundColor: Color {
        tintColor.opacity(0.15)
    }

    @MainActor var selectedBorderColor: Color {
        tintColor.opacity(0.35)
    }

    @MainActor var selectedIconColor: Color {
        tintColor
    }

    @MainActor var unselectedIconColor: Color {
        Color.gray.opacity(0.4)
    }

    @MainActor var calendarDotColor: Color {
        switch self {
        case .none:
            tintColor.opacity(SymiOpacity.calendarLowIntensityDot)
        case .low:
            tintColor.opacity(SymiOpacity.calendarLowIntensityDot)
        case .medium:
            tintColor.opacity(SymiOpacity.calendarMediumIntensityDot)
        case .high, .veryHigh:
            tintColor.opacity(SymiOpacity.calendarHighIntensityDot)
        }
    }

    @MainActor var faceBackgroundColor: Color {
        switch self {
        case .none:
            ColorToken.Surface.iconBackground
        case .low:
            tintColor.opacity(0.18)
        case .medium:
            tintColor.opacity(0.20)
        case .high, .veryHigh:
            tintColor.opacity(SymiOpacity.clearAccent)
        }
    }
}

struct PainIntensityImage: View {
    let level: PainIntensityLevel

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 1.8)

            HStack(spacing: 7) {
                Circle()
                    .frame(width: 3.2, height: 3.2)
                Circle()
                    .frame(width: 3.2, height: 3.2)
            }
            .offset(y: -4)

            PainIntensityMouthShape(level: level)
                .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .frame(width: 15, height: 8)
                .offset(y: 5)
        }
    }
}

private struct PainIntensityMouthShape: Shape {
    let level: PainIntensityLevel

    func path(in rect: CGRect) -> Path {
        switch level.faceExpression {
        case .calm:
            return curvedPath(in: rect, curve: 5)
        case .neutral:
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        case .strained:
            return curvedPath(in: rect, curve: -4)
        case .intense:
            return Path(ellipseIn: CGRect(x: rect.midX - 3, y: rect.minY, width: 6, height: rect.height))
        }
    }

    private func curvedPath(in rect: CGRect, curve: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.midY + curve)
        )
        return path
    }
}
