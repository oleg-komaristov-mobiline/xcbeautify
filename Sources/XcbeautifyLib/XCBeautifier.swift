import Foundation

/// The single type responsible for formatting output.
public struct XCBeautifier {
    private let parser = Parser()
    private let formatter: Formatter
    private let preserveUnbeautifiedLines: Bool
    private let output: OutputHandler

    public struct Config {
        public enum OutputLevel {
            case all
            case warningsAndErrors
            case errorsOnly
        }
        let colored: Bool
        let renderer: Renderer
        let level: OutputLevel
        let preserveUnbeautifiedLines: Bool
        let additionalLines: () -> String?
        let writer: (String) -> Void

        public static func terminalRenderer(writer: @escaping (String) -> Void,
                                            level: OutputLevel = .all,
                                            colored: Bool = true) -> Self {
            .init(
                colored: colored,
                renderer: .terminal,
                level: level,
                preserveUnbeautifiedLines: false,
                additionalLines: { return nil },
                writer: writer)
        }
    }

    public var logLevel: Config.OutputLevel {
        var result: Config.OutputLevel
        if output.quieter {
            result = .errorsOnly
        }
        else if (output.quiet) {
            result = .warningsAndErrors
        }
        else {
            result = .all
        }
        return result
    }

    /// Creates an `XCBeautifier` instance.
    /// - Parameters:
    ///   - colored: Indicates if `XCBeautifier` should color its formatted output.
    ///   - renderer: Indicates the context, such as Terminal and GitHub Actions, where `XCBeautifier` is used.
    ///   - preserveUnbeautifiedLines: Indicates if `XCBeautifier` should preserve unrecognized output.
    ///   - additionalLines: A closure that provides `XCBeautifier` the subsequent console output when needed (i.e. multi-line output).
    public init(config: Config) {
        formatter = Formatter(
            colored: config.colored,
            renderer: config.renderer,
            additionalLines: config.additionalLines
        )
        self.preserveUnbeautifiedLines = config.preserveUnbeautifiedLines
        var quiet = false
        var quieter = false
        if (.errorsOnly == config.level) {
            quiet = true
            quieter = true
        }
        else if (.warningsAndErrors == config.level) {
            quiet = true
        }
        output = OutputHandler(quiet: quiet, quieter: quieter, isCI: false, config.writer)
    }

    private func internalFormat(line: String) -> (group: (any CaptureGroup)?, output: String)? {
        var formatted: String?
        let captureGroup = parser.parse(line: line)
        if let captureGroup {
            formatted = formatter.format(captureGroup: captureGroup)
        }
        else if preserveUnbeautifiedLines {
            formatted = line
        }
        guard let formatted else { return nil }
        return (captureGroup, formatted)
    }

    /// Formats `xcodebuild` console output.
    /// - Parameter line: The raw `xcodebuild` output.
    /// - Returns: The formatted output. Returns `nil` if the input is unrecognized, unless `preserveUnbeautifiedLines` is `true`.
    public func format(line: String) -> String? {
        return internalFormat(line: line)?.output
    }

    public func append(line: String) {
        guard let intermediate = internalFormat(line: line) else { return }
        guard let group = intermediate.group else {
            return
        }
        output.write(group.outputType, intermediate.output)
    }
}
