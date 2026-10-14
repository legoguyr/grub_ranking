import SwiftUI
import UIKit

/// One branded export composition, independent of screen appearance and Dynamic
/// Type. In-app screens wrap its rendered image in accessible, adaptive UI.
struct ShareCardView: View {
    let model: ShareCardModel
    let photo: UIImage?

    private var hasPhoto: Bool { photo != nil }
    private var height: CGFloat { hasPhoto ? 1_350 : 1_080 }

    var body: some View {
        ZStack {
            SGTheme.Brand.cream
            decoration
            VStack(spacing: 0) {
                Spacer().frame(height: hasPhoto ? 24 : 38)
                if let logo = OfficialBrandWordmark.image {
                    Image(uiImage: logo).resizable().scaledToFit()
                        .frame(width: 280, height: 170)
                }
                Spacer().frame(height: hasPhoto ? 10 : 18)
                Text(model.title)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(SGTheme.Brand.charcoal)
                    .multilineTextAlignment(.center)
                    .lineLimit(3).minimumScaleFactor(0.65)
                    .frame(width: 920, height: hasPhoto ? 104 : 120)
                Text(model.versionSubtitle ?? "")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(SGTheme.Brand.charcoal.opacity(0.65))
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(width: 900, height: 32)
                Spacer().frame(height: hasPhoto ? 18 : 18)
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                        .frame(width: 826, height: 826)
                        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                } else {
                    UniversalFoodOutline()
                        .stroke(SGTheme.Brand.red, style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                        .frame(width: 300, height: 300)
                        .frame(width: 826, height: 336)
                }
                Spacer().frame(height: hasPhoto ? 18 : 28)
                score.frame(height: hasPhoto ? 64 : 84)
                Spacer().frame(height: hasPhoto ? 10 : 16)
                achievement.frame(height: hasPhoto ? 44 : 54)
                Spacer(minLength: 0)
            }
        }
        .frame(width: 1_080, height: height)
        .clipped()
        .environment(\.colorScheme, .light)
        .environment(\.dynamicTypeSize, .medium)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([model.title, model.versionSubtitle, model.scoreText.map { "\($0) out of 10" }, model.achievement?.title]
            .compactMap { $0 }.joined(separator: ", "))
    }

    private var score: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(model.scoreText ?? "")
                .font(.system(size: hasPhoto ? 64 : 80, weight: .heavy, design: .rounded))
                .monospacedDigit()
            Text("/ 10").font(.system(size: 32, weight: .medium))
        }
        .foregroundStyle(SGTheme.Brand.red)
    }

    @ViewBuilder private var achievement: some View {
        if let badge = model.achievement {
            Label(badge.title, systemImage: badge.symbol)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(SGTheme.Brand.red)
                .padding(.horizontal, 28)
                .frame(height: hasPhoto ? 44 : 54)
                .background(SGTheme.Brand.red.opacity(0.075), in: Capsule())
        } else {
            Color.clear
        }
    }

    private var decoration: some View {
        GeometryReader { geometry in
            Circle().fill(SGTheme.Brand.red.opacity(0.035))
                .frame(width: 390, height: 390)
                .position(x: geometry.size.width + 22, y: -24)
            Circle().fill(SGTheme.Brand.red.opacity(0.035))
                .frame(width: 410, height: 410)
                .position(x: geometry.size.width + 18, y: geometry.size.height + 14)
        }
        .accessibilityHidden(true)
    }
}

/// Reuses the actual bundled official PNG. Only its transparent export margins
/// are cropped for layout; the supplied lettering/color/alpha remain untouched.
enum OfficialBrandWordmark {
    static let image: UIImage? = {
        guard let original = UIImage(named: "StayGrubbyWordmark"), let pixels = original.cgImage,
              let ink = pixels.cropping(to: CGRect(x: 67, y: 310, width: 1_121, height: 682))
        else { return nil }
        return UIImage(cgImage: ink)
    }()
}

/// The same neutral plate and fork for every dish category. Native paths rather
/// than fake food photography or cuisine-specific illustrations.
struct UniversalFoodOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let plate = CGRect(x: rect.width * 0.27, y: rect.height * 0.16,
                           width: rect.width * 0.68, height: rect.height * 0.68)
        path.addEllipse(in: plate)
        path.addEllipse(in: plate.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.08))
        let left = rect.width * 0.07
        let right = rect.width * 0.17
        let middle = (left + right) / 2
        let top = rect.height * 0.17
        let join = rect.height * 0.4
        path.move(to: CGPoint(x: left, y: top))
        path.addLine(to: CGPoint(x: left, y: join - rect.height * 0.05))
        path.addQuadCurve(to: CGPoint(x: middle, y: join), control: CGPoint(x: left, y: join))
        path.addQuadCurve(to: CGPoint(x: right, y: join - rect.height * 0.05), control: CGPoint(x: right, y: join))
        path.addLine(to: CGPoint(x: right, y: top))
        path.move(to: CGPoint(x: middle, y: top))
        path.addLine(to: CGPoint(x: middle, y: rect.height * 0.84))
        return path
    }
}
