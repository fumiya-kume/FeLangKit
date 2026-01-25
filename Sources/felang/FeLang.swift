import ArgumentParser

@main
struct FeLang: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "felang",
        abstract: "FE pseudo-language interpreter and toolkit",
        version: "1.0.0",
        subcommands: [Run.self, Parse.self, Tokenize.self, REPL.self],
        defaultSubcommand: Run.self
    )
}
