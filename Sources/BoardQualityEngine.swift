import Foundation

/// Curated semantic families cover the strongest collisions; the remaining score is a heuristic,
/// not a claim that arbitrary Japanese word pairs have been semantically classified.
enum BoardQualityEngine {
    struct Entry {
        let word: Word
        let normalized: String
        let cluster: Int?
        let isAbstract: Bool
        let isLong: Bool
        let isShort: Bool
    }

    struct Prepared {
        let buckets: [(category: String, entries: [Entry])]
        let all: [Entry]
    }

    private static let families: [Set<String>] = [
        ["犬", "子犬", "柴犬", "秋田犬"], ["猫", "子猫", "黒猫"],
        ["雨", "小雨", "大雨", "夕立"], ["雪", "吹雪", "粉雪"],
        ["電車", "列車", "鉄道", "新幹線"], ["船", "客船", "汽船"],
        ["飛行機", "旅客機", "航空機"], ["太陽", "日光", "陽光"],
        ["海", "大海原", "海洋"], ["山", "山脈", "登山"],
        ["手紙", "便箋", "封筒"], ["時計", "腕時計", "目覚まし時計"]
    ]

    static func prepare(_ words: [Word]) -> Prepared {
        let clusterByWord = Dictionary(uniqueKeysWithValues: families.enumerated().flatMap { index, family in
            family.map { ($0, index) }
        })
        let entries = words.map { word -> Entry in
            let text = word.text.precomposedStringWithCompatibilityMapping.lowercased()
            return Entry(word: word, normalized: text, cluster: clusterByWord[word.text],
                         isAbstract: word.category == "感情・概念", isLong: word.text.count >= 8,
                         isShort: word.text.count == 1)
        }
        let grouped = Dictionary(grouping: entries, by: { $0.word.category })
        return Prepared(buckets: grouped.keys.sorted().map { ($0, grouped[$0]!) }, all: entries)
    }

    static func select<R: RandomNumberGenerator>(from words: [Word], difficulty: Difficulty,
                                                  pack: WordPack, using rng: inout R) -> [Word] {
        select(from: prepare(words), difficulty: difficulty, pack: pack, using: &rng)
    }

    static func select<R: RandomNumberGenerator>(from prepared: Prepared, difficulty: Difficulty,
                                                  pack: WordPack, using rng: inout R) -> [Word] {
        let count = pack == .custom ? 1 : 4
        var candidates: [(entries: [Entry], score: Int)] = []
        for _ in 0..<count {
            let board = sample(prepared, strict: pack != .custom, using: &rng)
            candidates.append((board, difficultyScore(board)))
        }
        candidates.sort { $0.score < $1.score }
        let chosen: Int
        switch difficulty {
        case .easy: chosen = 0
        case .normal, .custom: chosen = count / 2
        case .hard: chosen = min(2, count - 1)
        case .expert: chosen = count - 1
        }
        return candidates[chosen].entries.map(\.word).shuffled(using: &rng)
    }

    static func isBalanced(_ words: [Word]) -> Bool {
        guard words.count == 25 else { return false }
        let entries = prepare(words).all
        var selected: [Entry] = []
        var counts: [String: Int] = [:]
        for entry in entries {
            guard acceptable(entry, among: selected, counts: counts, strict: true) else { return false }
            selected.append(entry)
            counts[entry.word.category, default: 0] += 1
        }
        return true
    }

    static func difficultyScore(_ entries: [Entry]) -> Int {
        let abstract = entries.filter(\.isAbstract).count
        let long = entries.filter(\.isLong).count
        let short = entries.filter(\.isShort).count
        let demanding = entries.filter { ["科学", "職業", "感情・概念"].contains($0.word.category) }.count
        return abstract * 6 + long * 5 + demanding * 2 - short * 2
    }

    private static func sample<R: RandomNumberGenerator>(_ prepared: Prepared, strict: Bool,
                                                           using rng: inout R) -> [Entry] {
        var selected: [Entry] = []
        var counts: [String: Int] = [:]
        let order = prepared.buckets.indices.shuffled(using: &rng)
        // Fair category rotation with a random starting word in each bucket.
        while selected.count < 25 {
            var advanced = false
            for bucketIndex in order where selected.count < 25 {
                let bucket = prepared.buckets[bucketIndex]
                guard !bucket.entries.isEmpty, !strict || counts[bucket.category, default: 0] < 3 else { continue }
                let start = Int.random(in: 0..<bucket.entries.count, using: &rng)
                for offset in 0..<bucket.entries.count {
                    let entry = bucket.entries[(start + offset) % bucket.entries.count]
                    if acceptable(entry, among: selected, counts: counts, strict: strict) {
                        selected.append(entry)
                        counts[bucket.category, default: 0] += 1
                        advanced = true
                        break
                    }
                }
            }
            if !advanced { break }
        }
        // Custom packs may have only one category. Built-in packs have ample category coverage.
        if selected.count < 25 {
            for entry in prepared.all.shuffled(using: &rng) where selected.count < 25 {
                if acceptable(entry, among: selected, counts: counts, strict: false) {
                    selected.append(entry)
                    counts[entry.word.category, default: 0] += 1
                }
            }
        }
        return selected
    }

    private static func acceptable(_ entry: Entry, among selected: [Entry],
                                   counts: [String: Int], strict: Bool) -> Bool {
        if strict {
            if counts[entry.word.category, default: 0] >= 3 { return false }
            if entry.isAbstract && selected.filter(\.isAbstract).count >= 5 { return false }
            if entry.isShort && selected.filter(\.isShort).count >= 4 { return false }
            if entry.isLong && selected.filter(\.isLong).count >= 3 { return false }
        }
        return !selected.contains { other in
            if entry.normalized == other.normalized { return true }
            if !strict { return false }
            if let cluster = entry.cluster, cluster == other.cluster { return true }
            return min(entry.normalized.count, other.normalized.count) >= 2 &&
                (entry.normalized.contains(other.normalized) || other.normalized.contains(entry.normalized))
        }
    }
}
