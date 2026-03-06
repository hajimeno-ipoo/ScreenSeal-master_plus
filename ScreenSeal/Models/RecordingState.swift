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

    var statusText: String? {
        switch self {
        case .idle:
            return nil
        case .countdown(let secondsRemaining):
            return "Recording starts in \(secondsRemaining)..."
        case .starting:
            return "Recording: starting..."
        case .recording(_, let startedAt):
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            return "Recording: ON (started at \(formatter.string(from: startedAt)))"
        case .stopping:
            return "Recording: stopping..."
        case .failed(let message):
            return message
        }
    }

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}
