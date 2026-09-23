import Foundation

enum Player: String, Codable, CaseIterable, Hashable {
    case a = "A"
    case b = "B"

    var other: Player { self == .a ? .b : .a }
    var defaultName: String { self == .a ? "Player A" : "Player B" }
    var shortName: String { self == .a ? "A" : "B" }
}

enum Role: String, Codable, CaseIterable, Hashable {
    case target = "TARGET"
    case neutral = "NEUTRAL"
    case danger = "DANGER"

    var symbol: String {
        switch self {
        case .target: return "✓"
        case .neutral: return "—"
        case .danger: return "!"
        }
    }

    var title: String {
        switch self {
        case .target: return "仲間"
        case .neutral: return "一般"
        case .danger: return "危険"
        }
    }
}

enum Difficulty: String, Codable, CaseIterable, Identifiable, Hashable {
    case easy = "Easy"
    case normal = "Normal"
    case hard = "Hard"
    case expert = "Expert"
    case custom = "Custom"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .easy: return "Easy"
        case .normal: return "Normal"
        case .hard: return "Hard"
        case .expert: return "Expert"
        case .custom: return "Custom"
        }
    }
    var subtitle: String {
        switch self {
        case .easy: return "11ターン・ゆったり"
        case .normal: return "9ターン・標準"
        case .hard: return "8ターン・経験者向け"
        case .expert: return "7ターン・高難度"
        case .custom: return "5〜15ターン"
        }
    }
    func turnLimit(custom: Int) -> Int {
        switch self {
        case .easy: return 11
        case .normal: return 9
        case .hard: return 8
        case .expert: return 7
        case .custom: return min(15, max(5, custom))
        }
    }
}

enum WordPack: String, Codable, CaseIterable, Identifiable, Hashable {
    case standard = "STANDARD"
    case mixed = "MIXED"
    case custom = "CUSTOM"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .standard: return "STANDARD"
        case .mixed: return "MIXED"
        case .custom: return "CUSTOM"
        }
    }
    var description: String {
        switch self {
        case .standard: return "日常に近い1,200語以上"
        case .mixed: return "全カテゴリから選ぶ1,600語以上"
        case .custom: return "ふたりで登録した単語"
        }
    }
}

enum GamePhase: String, Codable, Hashable {
    case secretView = "SECRET_VIEW"
    case passDevice = "PASS_DEVICE"
    case playing = "PLAYING"
    case win = "WIN"
    case lose = "LOSE"

    var isActive: Bool { self == .secretView || self == .passDevice || self == .playing }
}

enum GameEvent: String, Codable, Hashable {
    case target = "TARGET"
    case neutral = "NEUTRAL"
    case danger = "DANGER"
    case turnEnd = "TURN_END"
}

struct Word: Codable, Hashable, Identifiable {
    let id: String
    let text: String
    let category: String
}

struct Clue: Codable, Equatable {
    let giver: Player
    let word: String
    let count: Int
}

struct KeyMaps: Codable, Equatable {
    let a: [Role]
    let b: [Role]

    subscript(_ player: Player) -> [Role] { player == .a ? a : b }
}

struct GameSettings: Codable {
    var playerA = "Player A"
    var playerB = "Player B"
    var difficulty: Difficulty = .normal
    var customTurns = 9
    var pack: WordPack = .standard
    var quickTap = false
    var customWords: [Word] = []

    func playerName(_ player: Player) -> String {
        let raw = player == .a ? playerA : playerB
        let clean = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        return clean.isEmpty ? player.defaultName : clean
    }
}

struct GameState: Codable, Identifiable {
    var id: String
    let words: [Word]
    let keys: KeyMaps
    var currentClueGiver: Player
    var turnRemaining: Int
    let turnLimit: Int
    var turnsUsed: Int
    let difficulty: Difficulty
    let pack: WordPack
    let playerAName: String
    let playerBName: String
    var foundIndices: [Int]
    var neutralByA: [Int]
    var neutralByB: [Int]
    var wrongGuesses: Int
    var currentClue: Clue?
    var phase: GamePhase
    var lastEvent: GameEvent?
    var lastEventIndex: Int?
    let startedAt: Date
    var completedAt: Date?
    var elapsedSeconds: Int?

    func playerName(_ player: Player) -> String { player == .a ? playerAName : playerBName }
    func neutralIndices(for player: Player) -> [Int] { player == .a ? neutralByA : neutralByB }
}

struct MatchRecord: Codable, Identifiable {
    let id: String
    let date: Date
    let won: Bool
    let difficulty: Difficulty
    let turnsUsed: Int
    let playSeconds: Int
    let targetsFound: Int
    let dangerSelected: Bool
}

struct MatchStats {
    let games: Int
    let wins: Int
    let winRate: Int
    let currentStreak: Int
    let bestStreak: Int
    let averageTurns: Double?
    let fastestSeconds: Int?
}

enum GameError: LocalizedError {
    case insufficientWords
    case invalidTurns
    case invalidState

    var errorDescription: String? {
        switch self {
        case .insufficientWords: return "この単語パックには、重複しない単語が25語以上必要です。"
        case .invalidTurns: return "ターン数は5〜15で設定してください。"
        case .invalidState: return "ゲーム状態を読み込めませんでした。新しいゲームを始めてください。"
        }
    }
}

enum GuessOutcome: Equatable {
    case invalid
    case target
    case win
    case neutral
    case danger
    case turnLimit
}

enum GameEngine {
    static let boardCount = 25
    static let targetsPerPlayer = 9
    static let dangersPerPlayer = 3
    static let sharedTargets = 3
    static let totalTargets = 15

    static func generateKeyMaps() -> KeyMaps {
        var rng = SystemRandomNumberGenerator()
        return generateKeyMaps(using: &rng)
    }

    static func generateKeyMaps<R: RandomNumberGenerator>(using rng: inout R) -> KeyMaps {
        for _ in 0..<1_000 {
            let positions = Array(0..<boardCount).shuffled(using: &rng)
            let shared = Set(positions[0..<sharedTargets])
            let targetsA = shared.union(positions[sharedTargets..<targetsPerPlayer])
            let bExclusiveStart = targetsPerPlayer
            let bExclusiveEnd = bExclusiveStart + targetsPerPlayer - sharedTargets
            let targetsB = shared.union(positions[bExclusiveStart..<bExclusiveEnd])
            let dangersA = Array((0..<boardCount).filter { !targetsA.contains($0) }.shuffled(using: &rng).prefix(dangersPerPlayer))
            let dangersB = Array((0..<boardCount).filter { !targetsB.contains($0) }.shuffled(using: &rng).prefix(dangersPerPlayer))
            let a = (0..<boardCount).map { index -> Role in
                if targetsA.contains(index) { return .target }
                if dangersA.contains(index) { return .danger }
                return .neutral
            }
            let b = (0..<boardCount).map { index -> Role in
                if targetsB.contains(index) { return .target }
                if dangersB.contains(index) { return .danger }
                return .neutral
            }
            let maps = KeyMaps(a: a, b: b)
            if validate(maps) { return maps }
        }
        preconditionFailure("Unable to generate valid LINK DUO key maps")
    }

    static func validate(_ keys: KeyMaps) -> Bool {
        guard keys.a.count == boardCount, keys.b.count == boardCount else { return false }
        let targetsA = Set(keys.a.indices.filter { keys.a[$0] == .target })
        let targetsB = Set(keys.b.indices.filter { keys.b[$0] == .target })
        let dangersA = Set(keys.a.indices.filter { keys.a[$0] == .danger })
        let dangersB = Set(keys.b.indices.filter { keys.b[$0] == .danger })
        return targetsA.count == targetsPerPlayer
            && targetsB.count == targetsPerPlayer
            && targetsA.intersection(targetsB).count == sharedTargets
            && targetsA.union(targetsB).count == totalTargets
            && dangersA.count == dangersPerPlayer
            && dangersB.count == dangersPerPlayer
            && targetsA.isDisjoint(with: dangersA)
            && targetsB.isDisjoint(with: dangersB)
    }

    static func validate(_ state: GameState) -> Bool {
        guard state.words.count == boardCount,
              Set(state.words.map(\.id)).count == boardCount,
              validate(state.keys),
              (5...15).contains(state.turnLimit),
              (0...state.turnLimit).contains(state.turnRemaining),
              state.turnsUsed >= 0,
              state.foundIndices.allSatisfy({ (0..<boardCount).contains($0) }),
              Set(state.foundIndices).count == state.foundIndices.count,
              state.neutralByA.allSatisfy({ (0..<boardCount).contains($0) }),
              state.neutralByB.allSatisfy({ (0..<boardCount).contains($0) }),
              Set(state.neutralByA).count == state.neutralByA.count,
              Set(state.neutralByB).count == state.neutralByB.count,
              state.lastEventIndex.map({ (0..<boardCount).contains($0) }) ?? true
        else { return false }
        let targetUnion = Set(state.keys.a.indices.filter { state.keys.a[$0] == .target || state.keys.b[$0] == .target })
        return Set(state.foundIndices).isSubset(of: targetUnion)
    }

    static func makeGame(settings: GameSettings, allWords: [Word], now: Date = Date()) throws -> GameState {
        let pool: [Word]
        switch settings.pack {
        case .standard:
            let categories: Set<String> = ["日常", "食べ物", "動物", "自然", "旅行", "場所", "スポーツ", "文化", "乗り物", "物", "エンタメ一般"]
            pool = allWords.filter { categories.contains($0.category) }
        case .mixed:
            pool = allWords
        case .custom:
            pool = settings.customWords
        }
        let uniqueWords = deduplicated(pool)
        guard uniqueWords.count >= boardCount else { throw GameError.insufficientWords }
        if settings.difficulty == .custom && !(5...15).contains(settings.customTurns) { throw GameError.invalidTurns }
        var rng = SystemRandomNumberGenerator()
        let words = selectWords(uniqueWords, using: &rng)
        let keys = generateKeyMaps(using: &rng)
        let limit = settings.difficulty.turnLimit(custom: settings.customTurns)
        let state = GameState(
            id: UUID().uuidString,
            words: words,
            keys: keys,
            currentClueGiver: .a,
            turnRemaining: limit,
            turnLimit: limit,
            turnsUsed: 0,
            difficulty: settings.difficulty,
            pack: settings.pack,
            playerAName: settings.playerName(.a),
            playerBName: settings.playerName(.b),
            foundIndices: [],
            neutralByA: [],
            neutralByB: [],
            wrongGuesses: 0,
            currentClue: nil,
            phase: .secretView,
            lastEvent: nil,
            lastEventIndex: nil,
            startedAt: now,
            completedAt: nil,
            elapsedSeconds: nil
        )
        guard validate(state) else { throw GameError.invalidState }
        return state
    }

    static func closeSecret(_ state: GameState) -> GameState {
        guard validate(state), state.phase == .secretView else { return state }
        var next = state
        next.phase = .passDevice
        return next
    }

    static func acknowledgePass(_ state: GameState) -> GameState {
        guard validate(state), state.phase == .passDevice else { return state }
        var next = state
        next.phase = .playing
        next.lastEvent = nil
        next.lastEventIndex = nil
        return next
    }

    static func recordClue(_ state: GameState, word: String, count: Int) -> GameState {
        guard validate(state), state.phase == .playing else { return state }
        let clean = String(word.trimmingCharacters(in: .whitespacesAndNewlines).prefix(16))
        guard !clean.isEmpty, (1...9).contains(count) else { return state }
        var next = state
        next.currentClue = Clue(giver: state.currentClueGiver, word: clean, count: count)
        return next
    }

    static func continueTurn(_ state: GameState) -> GameState {
        guard validate(state), state.phase == .playing, state.lastEvent == .target else { return state }
        var next = state
        next.lastEvent = nil
        next.lastEventIndex = nil
        return next
    }

    static func endTurn(_ state: GameState, now: Date = Date()) -> GameState {
        guard validate(state), state.phase == .playing, state.lastEvent == .target else { return state }
        var next = state
        next.lastEvent = .turnEnd
        next.lastEventIndex = nil
        return beginNextTurn(next, now: now)
    }

    static func resolveGuess(_ state: GameState, index: Int, now: Date = Date()) -> (state: GameState, outcome: GuessOutcome) {
        guard validate(state), state.phase == .playing, state.words.indices.contains(index),
              !state.foundIndices.contains(index), !state.neutralIndices(for: state.currentClueGiver).contains(index),
              state.lastEvent != .target else { return (state, .invalid) }
        var next = state
        next.lastEventIndex = index
        let role = state.keys[state.currentClueGiver][index]
        switch role {
        case .target:
            next.foundIndices.append(index)
            next.lastEvent = .target
            let targetUnion = Set(state.keys.a.indices.filter { state.keys.a[$0] == .target || state.keys.b[$0] == .target })
            if Set(next.foundIndices) == targetUnion {
                next.turnsUsed += 1
                next.turnRemaining = max(0, next.turnRemaining - 1)
                next = finish(next, phase: .win, now: now)
                return (next, .win)
            }
            return (next, .target)
        case .danger:
            next.wrongGuesses += 1
            next.turnsUsed += 1
            next.turnRemaining = max(0, next.turnRemaining - 1)
            next.lastEvent = .danger
            next = finish(next, phase: .lose, now: now)
            return (next, .danger)
        case .neutral:
            if state.currentClueGiver == .a { next.neutralByA.append(index) }
            else { next.neutralByB.append(index) }
            next.wrongGuesses += 1
            next.lastEvent = .neutral
            next = beginNextTurn(next, now: now)
            return (next, next.phase == .lose ? .turnLimit : .neutral)
        }
    }

    static func role(for index: Int, in state: GameState, player: Player) -> Role { state.keys[player][index] }

    private static func beginNextTurn(_ state: GameState, now: Date) -> GameState {
        var next = state
        next.turnRemaining = max(0, state.turnRemaining - 1)
        next.turnsUsed += 1
        next.currentClue = nil
        if next.turnRemaining == 0 && next.foundIndices.count < totalTargets {
            return finish(next, phase: .lose, now: now)
        }
        next.currentClueGiver = state.currentClueGiver.other
        next.phase = .secretView
        return next
    }

    private static func finish(_ state: GameState, phase: GamePhase, now: Date) -> GameState {
        var next = state
        next.phase = phase
        next.completedAt = now
        next.elapsedSeconds = max(0, Int(now.timeIntervalSince(state.startedAt)))
        return next
    }

    private static func deduplicated(_ words: [Word]) -> [Word] {
        var seen = Set<String>()
        return words.filter {
            let key = normalize($0.text)
            return !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !key.isEmpty && seen.insert(key).inserted
        }
    }

    private static func normalize(_ text: String) -> String {
        let folded = text.precomposedStringWithCompatibilityMapping.lowercased(with: Locale(identifier: "ja_JP"))
        return folded.filter { !$0.isWhitespace && $0 != "・" && $0 != "‐" && $0 != "-" }
    }

    private static func selectWords<R: RandomNumberGenerator>(_ pool: [Word], using rng: inout R) -> [Word] {
        var categories = Dictionary(grouping: pool, by: \.category)
        var order = Array(categories.keys).shuffled(using: &rng)
        for key in order { categories[key]?.shuffle(using: &rng) }
        var selected: [Word] = []
        var counts: [String: Int] = [:]
        while selected.count < boardCount {
            var moved = false
            for category in order where selected.count < boardCount {
                guard let nextCount = counts[category], nextCount >= 3 else {
                    guard var bucket = categories[category], !bucket.isEmpty else { continue }
                    selected.append(bucket.removeLast())
                    categories[category] = bucket
                    counts[category, default: 0] += 1
                    moved = true
                    continue
                }
            }
            if !moved { break }
        }
        if selected.count < boardCount {
            let used = Set(selected.map(\.id))
            selected.append(contentsOf: pool.filter { !used.contains($0.id) }.shuffled(using: &rng).prefix(boardCount - selected.count))
        }
        return selected.shuffled(using: &rng)
    }
}

enum StatsCalculator {
    static func calculate(_ history: [MatchRecord]) -> MatchStats {
        let sorted = history.sorted { $0.date > $1.date }
        let wins = sorted.filter(\.won)
        var current = 0
        for record in sorted {
            guard record.won else { break }
            current += 1
        }
        var best = 0
        var streak = 0
        for record in sorted.reversed() {
            if record.won { streak += 1; best = max(best, streak) }
            else { streak = 0 }
        }
        let average = wins.isEmpty ? nil : Double(wins.reduce(0) { $0 + $1.turnsUsed }) / Double(wins.count)
        return MatchStats(
            games: sorted.count,
            wins: wins.count,
            winRate: sorted.isEmpty ? 0 : Int((Double(wins.count) / Double(sorted.count) * 100).rounded()),
            currentStreak: current,
            bestStreak: best,
            averageTurns: average,
            fastestSeconds: wins.map(\.playSeconds).min()
        )
    }
}
