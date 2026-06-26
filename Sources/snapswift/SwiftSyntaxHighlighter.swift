import Foundation

/// A tiny, dependency-free Swift syntax highlighter for terminal output.
///
/// It tokenizes one line at a time (so it composes with streaming output) and colors
/// keywords, types, function calls, strings, comments, and numbers via ``TerminalStyle``.
struct SwiftSyntaxHighlighter {
    let style: TerminalStyle

    private static let keywords: Set<String> = [
        "import", "struct", "class", "enum", "protocol", "extension", "func", "var", "let",
        "if", "else", "guard", "return", "for", "in", "while", "switch", "case", "default",
        "some", "any", "self", "Self", "init", "deinit", "subscript", "static", "public",
        "private", "fileprivate", "internal", "open", "final", "lazy", "weak", "unowned",
        "nil", "true", "false", "do", "try", "catch", "throws", "rethrows", "async", "await",
        "where", "as", "is", "typealias", "associatedtype", "mutating", "nonmutating",
        "override", "convenience", "required", "indirect", "@State", "@Binding", "@main",
    ]

    func highlight(_ line: String) -> String {
        guard style.enabled else { return line }
        let chars = Array(line)
        var result = ""
        var i = 0

        while i < chars.count {
            let c = chars[i]

            // Line comment: color to end of line.
            if c == "/", i + 1 < chars.count, chars[i + 1] == "/" {
                result += style.gray(String(chars[i...]))
                break
            }

            // String literal.
            if c == "\"" {
                var j = i + 1
                var str = "\""
                while j < chars.count {
                    str.append(chars[j])
                    if chars[j] == "\"" && chars[j - 1] != "\\" { j += 1; break }
                    j += 1
                }
                result += style.green(str)
                i = j
                continue
            }

            // Identifier / keyword / type / call.
            if c.isLetter || c == "_" || c == "@" {
                var j = i
                var word = ""
                if c == "@" { word.append(c); j += 1 }
                while j < chars.count, chars[j].isLetter || chars[j].isNumber || chars[j] == "_" {
                    word.append(chars[j]); j += 1
                }
                if Self.keywords.contains(word) {
                    result += style.magenta(word)
                } else if let first = word.first, first == "@" {
                    result += style.magenta(word)
                } else if let first = word.first, first.isUppercase {
                    result += style.cyan(word)
                } else if j < chars.count, chars[j] == "(" {
                    result += style.yellow(word)
                } else {
                    result += word
                }
                i = j
                continue
            }

            // Number.
            if c.isNumber {
                var j = i
                var num = ""
                while j < chars.count, chars[j].isNumber || chars[j] == "." {
                    num.append(chars[j]); j += 1
                }
                result += style.blue(num)
                i = j
                continue
            }

            result.append(c)
            i += 1
        }

        return result
    }
}
