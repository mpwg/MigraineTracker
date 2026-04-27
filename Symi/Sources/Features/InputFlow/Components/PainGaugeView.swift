import SwiftUI

struct PainGaugeView: View {
    @Binding var value: Int

    let range: ClosedRange<Int>
    let theme: InputFlowStepTheme
    let accent: Color?
    let isCard: Bool

    init(
        value: Binding<Int>,
        range: ClosedRange<Int> = 1 ... 10,
        theme: InputFlowStepTheme = .pain,
        accent: Color? = nil,
        isCard: Bool = true
    ) {
        _value = value
        self.range = range
        self.theme = theme
        self.accent = accent
        self.isCard = isCard
    }

    var body: some View {
        PainGaugeCard(value: $value, range: range, theme: theme, accent: accent, isCard: isCard)
    }
}

private struct PainGaugeCard: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var value: Int

    let range: ClosedRange<Int>
    let theme: InputFlowStepTheme
    let accent: Color?
    let isCard: Bool

    var body: some View {
        Group {
            if isCard {
                InputFlowCard(theme: theme, isHighlighted: true) {
                    gaugeContent
                }
            } else {
                gaugeContent
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("entry-intensity-card")
        .animation(.snappy, value: normalizedValue)
    }

    private var gaugeContent: some View {
        VStack(spacing: SymiSpacing.md) {
            ZStack(alignment: .center) {
                PainGaugeArc()
                    .stroke(
                        SymiColors.subtleSeparator(for: colorScheme),
                        style: StrokeStyle(lineWidth: SymiStroke.painGaugeArc, lineCap: .round)
                    )
                    .frame(width: SymiSize.painGaugeWidth, height: SymiSize.painGaugeHeight)
                    .accessibilityHidden(true)

                PainGaugeArc()
                    .stroke(
                        LinearGradient(
                            colors: [
                                SymiColors.sage.color,
                                SymiColors.sage.mixed(with: SymiColors.coral, amount: 0.5).color,
                                SymiColors.coral.color
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: SymiStroke.painGaugeArc, lineCap: .round)
                    )
                    .frame(width: SymiSize.painGaugeWidth, height: SymiSize.painGaugeHeight)
                    .accessibilityHidden(true)

                VStack(spacing: SymiSpacing.zero) {
                    Text("\(normalizedValue)")
                        .font(SymiTypography.painGaugeMetric)
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.symiPetrol)
                        .minimumScaleFactor(SymiTypography.gaugeScaleFactor)

                    Text("/10")
                        .font(SymiTypography.painGaugeUnit)
                        .foregroundStyle(AppTheme.symiTextSecondary)

                    Text(intensityLabel)
                        .font(SymiTypography.painGaugeLabel)
                        .foregroundStyle(accentColor)
                        .padding(.top, SymiSpacing.micro)
                        .minimumScaleFactor(SymiTypography.buttonScaleFactor)
                }
                .padding(.top, SymiSpacing.xxl)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: SymiSpacing.compact) {
                PainGaugeSlider(
                    value: $value,
                    range: range,
                    theme: theme,
                    accent: accentColor
                )
                .accessibilityLabel("Kopfschmerzstärke")
                .accessibilityValue("\(normalizedValue) von 10, \(intensityLabel.lowercased())")
                .accessibilityIdentifier("entry-intensity-slider")

                HStack {
                    Text("\(range.lowerBound)")
                    Spacer()
                    Text("\(range.upperBound)")
                }
                .font(SymiTypography.caption.monospacedDigit())
                .foregroundStyle(AppTheme.symiTextSecondary)
            }
        }
    }

    private var normalizedValue: Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private var intensityLabel: String {
        switch normalizedValue {
        case 1 ... 3:
            "Leicht"
        case 4 ... 6:
            "Mittel"
        case 7 ... 8:
            "Stark"
        default:
            "Sehr stark"
        }
    }

    private var accentColor: Color {
        accent ?? theme.accent(for: colorScheme)
    }
}

private struct PainGaugeSlider: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @Binding var value: Int

    let range: ClosedRange<Int>
    let theme: InputFlowStepTheme
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let progress = normalizedProgress
            let filledWidth = proxy.size.width * progress
            let thumbX = proxy.size.width * progress

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(SymiColors.subtleSeparator(for: colorScheme))
                    .frame(height: SymiSize.painSliderTrackHeight)

                Capsule()
                    .fill(accent)
                    .frame(width: filledWidth, height: SymiSize.painSliderTrackHeight)

                Circle()
                    .fill(AppTheme.symiOnAccent)
                    .frame(width: SymiSize.painSliderThumbSize, height: SymiSize.painSliderThumbSize)
                    .shadow(
                        color: AppTheme.symiPetrol.opacity(SymiOpacity.sliderThumbShadow),
                        radius: SymiShadow.sliderThumbRadius,
                        y: SymiShadow.sliderThumbYOffset
                    )
                    .offset(x: thumbOffset(for: thumbX, width: proxy.size.width))
            }
            .frame(height: SymiSize.painSliderTouchHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: SymiSpacing.zero)
                    .onChanged { gesture in
                        updateValue(for: gesture.location.x, width: proxy.size.width)
                    }
            )
            .animation(reduceMotion ? nil : .snappy, value: value)
        }
        .frame(height: SymiSize.painSliderTouchHeight)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = min(value + 1, range.upperBound)
            case .decrement:
                value = max(value - 1, range.lowerBound)
            @unknown default:
                break
            }
        }
    }

    private var normalizedProgress: CGFloat {
        let span = max(range.upperBound - range.lowerBound, 1)
        let clampedValue = min(max(value, range.lowerBound), range.upperBound)
        return CGFloat(clampedValue - range.lowerBound) / CGFloat(span)
    }

    private func thumbOffset(for xPosition: CGFloat, width: CGFloat) -> CGFloat {
        let halfThumb = SymiSize.painSliderThumbSize / 2
        return min(max(xPosition - halfThumb, 0), max(width - SymiSize.painSliderThumbSize, 0))
    }

    private func updateValue(for xPosition: CGFloat, width: CGFloat) {
        guard width > 0 else {
            return
        }

        let clampedX = min(max(xPosition, 0), width)
        let progress = clampedX / width
        let span = range.upperBound - range.lowerBound
        value = range.lowerBound + Int((CGFloat(span) * progress).rounded())
    }
}

private struct PainGaugeArc: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width / 2, rect.height) - SymiSpacing.sm
        let center = CGPoint(x: rect.midX, y: rect.maxY - SymiSpacing.xxxl)
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(205),
            endAngle: .degrees(335),
            clockwise: false
        )
        return path
    }
}
