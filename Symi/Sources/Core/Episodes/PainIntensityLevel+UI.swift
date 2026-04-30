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
        tintColor.opacity(SymiOpacity.painIntensitySelectedFill)
    }

    @MainActor var selectedBorderColor: Color {
        tintColor
    }

    @MainActor var selectedIconColor: Color {
        tintColor
    }

    @MainActor var unselectedIconColor: Color {
        tintColor.opacity(SymiOpacity.painIntensityUnselectedIcon)
    }

    @MainActor var unselectedBorderColor: Color {
        tintColor.opacity(SymiOpacity.painIntensityUnselectedStroke)
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
            tintColor.opacity(SymiOpacity.painIntensityLowFaceFill)
        case .medium:
            tintColor.opacity(SymiOpacity.painIntensityMediumFaceFill)
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
                .stroke(lineWidth: SymiStroke.painIntensityFace)

            HStack(spacing: SymiSpacing.painIntensityFaceEyeSpacing) {
                Circle()
                    .frame(width: SymiSize.painIntensityFaceEye, height: SymiSize.painIntensityFaceEye)
                Circle()
                    .frame(width: SymiSize.painIntensityFaceEye, height: SymiSize.painIntensityFaceEye)
            }
            .offset(y: SymiSpacing.painIntensityFaceEyeOffsetY)

            PainIntensityMouthShape(level: level)
                .stroke(style: StrokeStyle(lineWidth: SymiStroke.painIntensityFace, lineCap: .round))
                .frame(width: SymiSize.painIntensityFaceMouthWidth, height: SymiSize.painIntensityFaceMouthHeight)
                .offset(y: SymiSpacing.painIntensityFaceMouthOffsetY)
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
            let mouthWidth = SymiSize.painIntensityFaceOpenMouthWidth
            return Path(ellipseIn: CGRect(x: rect.midX - mouthWidth / 2, y: rect.minY, width: mouthWidth, height: rect.height))
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
