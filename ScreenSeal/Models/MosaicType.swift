import CoreImage

enum MosaicType: String, CaseIterable, Identifiable {
    case pixelation = "Pixelation"
    case gaussianBlur = "Gaussian Blur"
    case crystallize = "Crystallize"

    var id: String { rawValue }

    func localizedTitle(in language: AppLanguage) -> String {
        switch (self, language) {
        case (.pixelation, .english):
            return "Pixelation"
        case (.pixelation, .japanese):
            return "ピクセル化"
        case (.gaussianBlur, .english):
            return "Gaussian Blur"
        case (.gaussianBlur, .japanese):
            return "ガウスぼかし"
        case (.crystallize, .english):
            return "Crystallize"
        case (.crystallize, .japanese):
            return "結晶化"
        }
    }

    var filterName: String {
        switch self {
        case .pixelation: return "CIPixellate"
        case .gaussianBlur: return "CIGaussianBlur"
        case .crystallize: return "CICrystallize"
        }
    }

    var parameterKey: String {
        switch self {
        case .pixelation: return kCIInputScaleKey
        case .gaussianBlur: return kCIInputRadiusKey
        case .crystallize: return kCIInputRadiusKey
        }
    }

    var intensityRange: ClosedRange<Double> {
        switch self {
        case .pixelation: return 5...100
        case .gaussianBlur: return 5...50
        case .crystallize: return 5...100
        }
    }

    var defaultIntensity: Double {
        switch self {
        case .pixelation: return 20
        case .gaussianBlur: return 15
        case .crystallize: return 20
        }
    }
}
