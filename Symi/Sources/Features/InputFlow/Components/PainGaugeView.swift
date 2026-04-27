import SwiftUI

struct PainGaugeView: View {
    @Binding var value: Int

    let range: ClosedRange<Int>
    let theme: InputFlowStepTheme

    init(
        value: Binding<Int>,
        range: ClosedRange<Int> = 0 ... 10,
        theme: InputFlowStepTheme = .pain
    ) {
        _value = value
        self.range = range
        self.theme = theme
    }

    var body: some View {
        InputFlowCard(theme: theme, isHighlighted: true) {
            VStack(spacing: 18) {
                ZStack(alignment: .center) {
                    PainGaugeArc()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    InputFlowStepTheme.medication.accent,
                                    SymiColors.noteAmber.color,
                                    InputFlowStepTheme.pain.accent
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 13, lineCap: .round)
                        )
                        .frame(width: 212, height: 142)
                        .accessibilityHidden(true)

                    VStack(spacing: 4) {
                        Text("\(normalizedValue)")
                            .font(.system(size: 58, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.symiPetrol)
                            .minimumScaleFactor(0.75)

                        Text("/10")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text(intensityLabel)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(theme.accent)
                            .padding(.top, 8)
                            .minimumScaleFactor(0.85)
                    }
                    .padding(.top, 20)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { Double(normalizedValue) },
                            set: { value = Int($0.rounded()) }
                        ),
                        in: Double(range.lowerBound) ... Double(range.upperBound),
                        step: 1
                    )
                    .tint(theme.accent)
                    .accessibilityLabel("Kopfschmerzstärke")
                    .accessibilityValue("\(normalizedValue) von 10, \(intensityLabel.lowercased())")
                    .accessibilityIdentifier("entry-intensity-slider")

                    HStack {
                        Text("\(range.lowerBound)")
                        Spacer()
                        Text("\(range.upperBound)")
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("entry-intensity-card")
    }

    private var normalizedValue: Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private var intensityLabel: String {
        switch normalizedValue {
        case ...0:
            "Kein"
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
}

private struct PainGaugeArc: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width / 2, rect.height) - 8
        let center = CGPoint(x: rect.midX, y: rect.maxY - 8)
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(200),
            endAngle: .degrees(340),
            clockwise: false
        )
        return path
    }
}
