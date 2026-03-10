import Foundation

enum RecordingState: Equatable {
    case idle
    case countdown(secondsRemaining: Int)
    case starting
    case recording(url: URL, startedAt: Date)
    case stopping
    case failed(message: String)

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    func statusText(in language: AppLanguage) -> String? {
        switch self {
        case .idle:
            return nil
        case .countdown(let secondsRemaining):
            return AppStrings.recordingStartsIn(secondsRemaining, in: language)
        case .starting:
            return AppStrings.recordingStarting(in: language)
        case .recording(_, let startedAt):
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            formatter.locale = Locale(identifier: language.localeIdentifier)
            return AppStrings.recordingStartedAt(formatter.string(from: startedAt), in: language)
        case .stopping:
            return AppStrings.recordingStopping(in: language)
        case .failed(let message):
            return message
        }
    }

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}
