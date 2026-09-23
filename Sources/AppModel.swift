import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var settings: GameSettings
    @Published private(set) var game: GameState?
    @Published private(set) var history: [MatchRecord]
    @Published private(set) var tutorialSeen: Bool
    @Published var errorMessage: String?

    private let defaults: UserDefaults
    private let settingsKey = "link-duo-ios.settings.v1"
    private let gameKey = "link-duo-ios.active-game.v1"
    private let historyKey = "link-duo-ios.history.v1"
    private let tutorialKey = "link-duo-ios.tutorial-seen.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.settings = Self.decode(GameSettings.self, key: "link-duo-ios.settings.v1", defaults: defaults) ?? GameSettings()
        self.history = Self.decode([MatchRecord].self, key: "link-duo-ios.history.v1", defaults: defaults) ?? []
        let restored = Self.decode(GameState.self, key: "link-duo-ios.active-game.v1", defaults: defaults)
        self.game = restored.flatMap { GameEngine.validate($0) && $0.phase.isActive ? $0 : nil }
        self.tutorialSeen = defaults.bool(forKey: "link-duo-ios.tutorial-seen.v1")
        if self.game == nil { defaults.removeObject(forKey: "link-duo-ios.active-game.v1") }
    }

    var hasResumableGame: Bool { game?.phase.isActive == true }
    var stats: MatchStats { StatsCalculator.calculate(history) }
    var customWordCount: Int { settings.customWords.count }

    func updateSettings(_ update: (inout GameSettings) -> Void) {
        var next = settings
        update(&next)
        next.customTurns = min(15, max(5, next.customTurns))
        settings = next
        Self.encode(next, key: settingsKey, defaults: defaults)
    }

    func startNewGame() -> Bool {
        do {
            let allWords = WordRepository.all
            guard allWords.count >= 600 else {
                errorMessage = "単語データを読み込めませんでした。アプリを再起動してください。"
                return false
            }
            let next = try GameEngine.makeGame(settings: settings, allWords: allWords)
            game = next
            Self.encode(next, key: gameKey, defaults: defaults)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func resumeGame() -> Bool {
        guard let game, game.phase.isActive, GameEngine.validate(game) else {
            errorMessage = "つづきから遊べるゲームがありません。"
            return false
        }
        return true
    }

    func closeSecret() {
        guard let game else { return }
        commit(GameEngine.closeSecret(game))
    }

    func acknowledgePass() {
        guard let game else { return }
        commit(GameEngine.acknowledgePass(game))
    }

    func recordClue(word: String, count: Int) {
        guard let game else { return }
        commit(GameEngine.recordClue(game, word: word, count: count))
    }

    func resolveGuess(index: Int) -> GuessOutcome {
        guard let game else { return .invalid }
        let result = GameEngine.resolveGuess(game, index: index)
        if result.outcome != .invalid { commit(result.state) }
        return result.outcome
    }

    func continueTurn() {
        guard let game else { return }
        commit(GameEngine.continueTurn(game))
    }

    func endTurn() {
        guard let game else { return }
        commit(GameEngine.endTurn(game))
    }

    func abandonToHome() {
        // An in-progress round remains saved so it can be resumed from Home.
        guard let game, game.phase.isActive else { return }
        Self.encode(game, key: gameKey, defaults: defaults)
    }

    func startRematch() -> Bool {
        startNewGame()
    }

    func finishTutorial() {
        tutorialSeen = true
        defaults.set(true, forKey: tutorialKey)
    }

    func addCustomWord(_ input: String) -> Bool {
        let clean = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...14).contains(clean.count) else {
            errorMessage = "単語は2〜14文字で入力してください。"
            return false
        }
        let key = Self.normalized(clean)
        guard !settings.customWords.contains(where: { Self.normalized($0.text) == key }) else {
            errorMessage = "同じ単語はすでに登録されています。"
            return false
        }
        guard settings.customWords.count < 300 else {
            errorMessage = "カスタム単語は300語まで登録できます。"
            return false
        }
        updateSettings { $0.customWords.append(Word(id: "custom-\(UUID().uuidString)", text: clean, category: "カスタム")) }
        return true
    }

    func removeCustomWord(id: String) {
        updateSettings { $0.customWords.removeAll { $0.id == id } }
    }

    func clearHistory() {
        history = []
        Self.encode(history, key: historyKey, defaults: defaults)
    }

    private func commit(_ next: GameState) {
        guard GameEngine.validate(next) else {
            errorMessage = GameError.invalidState.localizedDescription
            return
        }
        game = next
        if next.phase.isActive {
            Self.encode(next, key: gameKey, defaults: defaults)
            return
        }
        defaults.removeObject(forKey: gameKey)
        guard !history.contains(where: { $0.id == next.id }) else { return }
        let record = MatchRecord(
            id: next.id,
            date: next.completedAt ?? Date(),
            won: next.phase == .win,
            difficulty: next.difficulty,
            turnsUsed: next.turnsUsed,
            playSeconds: next.elapsedSeconds ?? 0,
            targetsFound: next.foundIndices.count,
            dangerSelected: next.lastEvent == .danger
        )
        history.insert(record, at: 0)
        history = Array(history.prefix(100))
        Self.encode(history, key: historyKey, defaults: defaults)
    }

    private static func normalized(_ text: String) -> String {
        text.precomposedStringWithCompatibilityMapping
            .lowercased(with: Locale(identifier: "ja_JP"))
            .filter { !$0.isWhitespace && $0 != "・" && $0 != "‐" && $0 != "-" }
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, key: String, defaults: UserDefaults) -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func encode<Value: Encodable>(_ value: Value, key: String, defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}

enum WordRepository {
    static let all: [Word] = {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([Word].self, from: data) else { return [] }
        return words
    }()
}
