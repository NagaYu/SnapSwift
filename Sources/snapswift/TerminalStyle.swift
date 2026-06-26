import Foundation

/// Minimal ANSI styling helper that politely disables itself when output is not a TTY,
/// when `NO_COLOR` is set, or when the user passes `--no-color`.
struct TerminalStyle {
    let enabled: Bool

    init(forced: Bool? = nil) {
        if let forced {
            self.enabled = forced
        } else if ProcessInfo.processInfo.environment["NO_COLOR"] != nil {
            self.enabled = false
        } else {
            self.enabled = isatty(fileno(stdout)) == 1
        }
    }

    private func wrap(_ text: String, _ code: String) -> String {
        guard enabled else { return text }
        return "\u{001B}[\(code)m\(text)\u{001B}[0m"
    }

    func bold(_ s: String) -> String { wrap(s, "1") }
    func dim(_ s: String) -> String { wrap(s, "2") }
    func red(_ s: String) -> String { wrap(s, "31") }
    func green(_ s: String) -> String { wrap(s, "32") }
    func yellow(_ s: String) -> String { wrap(s, "33") }
    func blue(_ s: String) -> String { wrap(s, "34") }
    func magenta(_ s: String) -> String { wrap(s, "35") }
    func cyan(_ s: String) -> String { wrap(s, "36") }
    func gray(_ s: String) -> String { wrap(s, "90") }
}
