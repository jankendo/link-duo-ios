import XCTest
@testable import LINKDUO

final class GameDomainTests: XCTestCase {
    private var words: [Word] {
        (0..<700).map { Word(id: "test:\($0)", text: "言葉\($0)", category: ["日常", "食べ物", "動物", "自然"][ $0 % 4]) }
    }

    func testKeyGeneratorMaintainsRulesAcrossTenThousandGamesAndMovesTargets() {
        var rng = SeededGenerator(seed: 0xC0FFEE)
        var targetAByCell = Array(repeating: 0, count: 25)
        var targetBByCell = Array(repeating: 0, count: 25)
        for _ in 0..<10_000 {
            let keys = GameEngine.generateKeyMaps(using: &rng)
            XCTAssertTrue(GameEngine.validate(keys))
            for index in 0..<25 {
                if keys.a[index] == .target { targetAByCell[index] += 1 }
                if keys.b[index] == .target { targetBByCell[index] += 1 }
            }
        }
        XCTAssertTrue(targetAByCell.allSatisfy { (3_200...4_000).contains($0) })
        XCTAssertTrue(targetBByCell.allSatisfy { (3_200...4_000).contains($0) })
        XCTAssertGreaterThan(Set(targetAByCell).count, 10)
        XCTAssertGreaterThan(Set(targetBByCell).count, 10)
    }

    func testNewGameHasUniqueRandomBoardAndStartsWithPlayerA() throws {
        var settings = GameSettings()
        settings.pack = .mixed
        let first = try GameEngine.makeGame(settings: settings, allWords: words)
        let second = try GameEngine.makeGame(settings: settings, allWords: words)
        XCTAssertEqual(first.words.count, 25)
        XCTAssertEqual(Set(first.words.map(\.id)).count, 25)
        XCTAssertEqual(first.currentClueGiver, .a)
        XCTAssertEqual(first.phase, .secretView)
        XCTAssertEqual(first.turnRemaining, 9)
        XCTAssertNotEqual(first.words.map(\.id), second.words.map(\.id))
    }

    func testPassAndPlayFlowHidesSecretBeforeOtherPlayerReceivesDevice() throws {
        let game = try GameEngine.makeGame(settings: GameSettings(), allWords: words)
        let hidden = GameEngine.closeSecret(game)
        XCTAssertEqual(hidden.phase, .passDevice)
        XCTAssertEqual(hidden.keys, game.keys)
        let playing = GameEngine.acknowledgePass(hidden)
        XCTAssertEqual(playing.phase, .playing)
        XCTAssertEqual(playing.currentClueGiver, .a)
        XCTAssertEqual(GameEngine.acknowledgePass(game).phase, .secretView)
    }

    func testClueRequiresAWordAndNumberAndStoresItForCurrentGiver() throws {
        var game = try GameEngine.makeGame(settings: GameSettings(), allWords: words)
        game.phase = .playing
        let unchanged = GameEngine.recordClue(game, word: "  ", count: 2)
        XCTAssertNil(unchanged.currentClue)
        let recorded = GameEngine.recordClue(game, word: "宇宙", count: 2)
        XCTAssertEqual(recorded.currentClue, Clue(giver: .a, word: "宇宙", count: 2))
        XCTAssertNil(GameEngine.recordClue(game, word: "宇宙", count: 10).currentClue)
    }

    func testTargetCanContinueOrEndTurnAndCannotBeGuessedTwice() throws {
        var game = try GameEngine.makeGame(settings: GameSettings(), allWords: words)
        game.phase = .playing
        let target = try XCTUnwrap(game.keys.a.firstIndex(of: .target))
        let hit = GameEngine.resolveGuess(game, index: target)
        XCTAssertEqual(hit.outcome, .target)
        XCTAssertTrue(hit.state.foundIndices.contains(target))
        XCTAssertEqual(GameEngine.resolveGuess(hit.state, index: target).outcome, .invalid)
        let continuing = GameEngine.continueTurn(hit.state)
        XCTAssertNil(continuing.lastEvent)
        let ended = GameEngine.endTurn(hit.state, now: game.startedAt.addingTimeInterval(45))
        XCTAssertEqual(ended.phase, .secretView)
        XCTAssertEqual(ended.currentClueGiver, .b)
        XCTAssertEqual(ended.turnRemaining, game.turnLimit - 1)
        XCTAssertEqual(ended.turnsUsed, 1)
    }

    func testNeutralEndsTurnAndIsTrackedForOnlyTheCurrentMap() throws {
        var game = try GameEngine.makeGame(settings: GameSettings(), allWords: words)
        game.phase = .playing
        let neutral = try XCTUnwrap(game.keys.a.firstIndex(of: .neutral))
        let result = GameEngine.resolveGuess(game, index: neutral)
        XCTAssertEqual(result.outcome, .neutral)
        XCTAssertEqual(result.state.phase, .secretView)
        XCTAssertEqual(result.state.currentClueGiver, .b)
        XCTAssertEqual(result.state.neutralByA, [neutral])
        XCTAssertTrue(result.state.neutralByB.isEmpty)
        XCTAssertEqual(result.state.wrongGuesses, 1)
        let passed = GameEngine.acknowledgePass(GameEngine.closeSecret(result.state))
        XCTAssertNil(passed.lastEvent)
    }

    func testDangerEndsGameImmediately() throws {
        var game = try GameEngine.makeGame(settings: GameSettings(), allWords: words)
        game.phase = .playing
        let danger = try XCTUnwrap(game.keys.a.firstIndex(of: .danger))
        let result = GameEngine.resolveGuess(game, index: danger)
        XCTAssertEqual(result.outcome, .danger)
        XCTAssertEqual(result.state.phase, .lose)
        XCTAssertEqual(result.state.lastEvent, .danger)
        XCTAssertEqual(result.state.turnRemaining, game.turnLimit - 1)
        XCTAssertEqual(result.state.wrongGuesses, 1)
    }

    func testTurnLimitCausesLossWhenNeutralUsesFinalTurn() throws {
        var game = try GameEngine.makeGame(settings: GameSettings(), allWords: words)
        game.phase = .playing
        game.turnRemaining = 1
        let neutral = try XCTUnwrap(game.keys.a.firstIndex(of: .neutral))
        let result = GameEngine.resolveGuess(game, index: neutral)
        XCTAssertEqual(result.outcome, .turnLimit)
        XCTAssertEqual(result.state.phase, .lose)
        XCTAssertEqual(result.state.turnRemaining, 0)
        XCTAssertEqual(result.state.turnsUsed, 1)
    }

    func testFindingAllFifteenUnionTargetsWinsImmediately() throws {
        var game = try GameEngine.makeGame(settings: GameSettings(), allWords: words)
        game.phase = .playing
        let union = Set((0..<25).filter { game.keys.a[$0] == .target || game.keys.b[$0] == .target })
        let lastTarget = try XCTUnwrap(union.first(where: { game.keys.a[$0] == .target }))
        game.foundIndices = Array(union.subtracting(Set([lastTarget])))
        let result = GameEngine.resolveGuess(game, index: lastTarget, now: game.startedAt.addingTimeInterval(120))
        XCTAssertEqual(result.outcome, .win)
        XCTAssertEqual(result.state.phase, .win)
        XCTAssertEqual(result.state.foundIndices.count, 15)
        XCTAssertEqual(result.state.elapsedSeconds, 120 as Int?)
    }

    func testActiveGameCanBeSavedAndRestoredWithoutLosingItsBoard() throws {
        let game = try GameEngine.makeGame(settings: GameSettings(), allWords: words)
        let data = try JSONEncoder().encode(game)
        let restored = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertTrue(GameEngine.validate(restored))
        XCTAssertEqual(restored.id, game.id)
        XCTAssertEqual(restored.words, game.words)
        XCTAssertEqual(restored.keys, game.keys)
        XCTAssertEqual(restored.phase, .secretView)
    }

    func testStatsCalculateWinRateAndStreaks() {
        let now = Date()
        let history = [
            record("1", won: true, turns: 7, seconds: 80, daysAgo: 0, now: now),
            record("2", won: true, turns: 8, seconds: 90, daysAgo: 1, now: now),
            record("3", won: false, turns: 4, seconds: 35, daysAgo: 2, now: now),
            record("4", won: true, turns: 9, seconds: 120, daysAgo: 3, now: now)
        ]
        let stats = StatsCalculator.calculate(history)
        XCTAssertEqual(stats.games, 4)
        XCTAssertEqual(stats.wins, 3)
        XCTAssertEqual(stats.winRate, 75)
        XCTAssertEqual(stats.currentStreak, 2)
        XCTAssertEqual(stats.bestStreak, 2)
        XCTAssertEqual(stats.averageTurns, 8.0)
        XCTAssertEqual(stats.fastestSeconds, 80)
    }

    private func record(_ id: String, won: Bool, turns: Int, seconds: Int, daysAgo: Int, now: Date) -> MatchRecord {
        MatchRecord(id: id, date: now.addingTimeInterval(TimeInterval(-daysAgo * 86_400)), won: won, difficulty: .normal, turnsUsed: turns, playSeconds: seconds, targetsFound: won ? 15 : 6, dangerSelected: false)
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
