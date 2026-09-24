import SwiftUI
import UIKit

struct GameView: View {
    @ObservedObject var model: AppModel
    let onHome: () -> Void

    var body: some View {
        Group {
            if let game = model.game {
                switch game.phase {
                case .secretView: SecretView(model: model, game: game)
                case .passDevice: PassDeviceView(model: model, game: game)
                case .playing: PlayingView(model: model, game: game, onHome: onHome)
                case .win, .lose: ResultView(model: model, game: game, onHome: onHome)
                }
            } else {
                InvalidGameView(onHome: onHome)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.canvas.ignoresSafeArea())
    }
}

struct InvalidGameView: View {
    let onHome: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.circle").font(.system(size: 44)).foregroundStyle(Palette.amber)
            Text("ゲームを読み込めませんでした").font(.system(size: 20, weight: .bold, design: .rounded))
            Text("ホームに戻り、新しいゲームを始めてください。")
                .font(.system(size: 14)).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
            PrimaryAction(title: "ホームへ", symbol: "house.fill", action: onHome).frame(maxWidth: 330)
        }.padding(24)
    }
}

struct SecretView: View {
    @ObservedObject var model: AppModel
    let game: GameState
    @Environment(\.scenePhase) private var scenePhase
    @State private var hold = SecretHoldState()
    @State private var revealTask: Task<Void, Never>?
    @State private var pressToken = UUID()
    @State private var cancelledUntilRelease = false

    var body: some View {
        ZStack {
            Palette.navy.ignoresSafeArea()
            GeometryReader { geometry in
                let compact = geometry.size.height < 630
                let gap: CGFloat = compact ? 4 : 5
                let tileHeight: CGFloat = compact ? 43 : 49
                let mapHeight = tileHeight * 5 + gap * 4

                VStack(spacing: compact ? 11 : 15) {
                    HStack {
                        Text("LINK DUO").font(.system(size: 12, weight: .black, design: .rounded)).tracking(2).foregroundStyle(.white.opacity(0.86))
                        Spacer()
                        Label("PRIVATE / \(game.turnLimit - game.turnRemaining + 1)", systemImage: "lock.fill")
                            .font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1)
                            .foregroundStyle(Palette.tealLight)
                    }
                    VStack(spacing: compact ? 5 : 8) {
                        Image(systemName: hold.isRevealed ? "eye.fill" : "eye.slash.fill")
                            .font(.system(size: compact ? 24 : 28, weight: .medium))
                            .foregroundStyle(hold.isRevealed ? Palette.tealLight : Color.white.opacity(0.83))
                        Text("\(game.playerName(game.currentClueGiver))だけが見てください")
                            .font(.system(size: compact ? 18 : 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white).multilineTextAlignment(.center)
                            .lineLimit(2).minimumScaleFactor(0.85)
                        Text(hold.isRevealed ? "指を押したまま、盤面を確認" : "端末を自分側に向けてから長押し")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.69))
                    }
                    HStack(spacing: 7) {
                        legend(.target, count: 9)
                        legend(.neutral, count: 13)
                        legend(.danger, count: 3)
                    }

                    ZStack {
                        if hold.isRevealed {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gap), count: 5), spacing: gap) {
                                ForEach(game.words.indices, id: \.self) { index in
                                    SecretMapCell(word: game.words[index], role: game.keys[game.currentClueGiver][index], height: tileHeight)
                                }
                            }
                            .accessibilityLabel("\(game.playerName(game.currentClueGiver))の秘密マップ")
                        } else {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(.white.opacity(0.055))
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(.white.opacity(0.17), lineWidth: 1)
                            VStack(spacing: 11) {
                                Image(systemName: "hand.point.up.left.fill")
                                    .font(.system(size: 28, weight: .light))
                                Text("長押し中だけ秘密マップを表示")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white.opacity(0.63))
                        }
                    }
                    .frame(height: mapHeight)
                    .overlay(alignment: .topLeading) {
                        if !hold.isRevealed {
                            Text("HIDDEN FIELD")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1.5).foregroundStyle(.white.opacity(0.58))
                                .padding(11)
                        }
                    }

                    Spacer(minLength: 0)
                    holdControl
                }
                .padding(.horizontal, 19)
                .padding(.top, compact ? 8 : 12)
                .padding(.bottom, 8)
                .frame(maxWidth: 540, maxHeight: .infinity)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                cancelledUntilRelease = false
            } else {
                cancelledUntilRelease = true
                finishPress()
            }
        }
        .onDisappear { revealTask?.cancel() }
    }

    private func legend(_ role: Role, count: Int) -> some View {
        HStack(spacing: 5) {
            Text(role.symbol).font(.system(size: 12, weight: .black, design: .rounded))
            Text("\(role.title) \(count)").font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(role == .target ? Palette.tealLight : role == .danger ? Color(hex: 0xE6A09A) : Color.white.opacity(0.78))
        .frame(maxWidth: .infinity, minHeight: 30)
        .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 9))
    }

    private var holdControl: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(hold.isRevealed ? Palette.lime : Color.white)
                HStack(spacing: 9) {
                    Image(systemName: hold.isRevealed ? "eye.fill" : "hand.point.up.left.fill")
                    Text(hold.isRevealed ? "秘密マップを表示中" : "長押しして秘密を見る")
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.navy)
                GeometryReader { width in
                    Capsule().fill(Palette.teal)
                        .frame(width: hold.isPressing ? width.size.width : 0, height: 3)
                        .animation(hold.isPressing ? .linear(duration: 0.65) : nil, value: hold.isPressing)
                }
                .frame(height: 3)
                .padding(.horizontal, 15)
                .padding(.bottom, 5)
            }
            .frame(height: 62)
            .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged(updatePress)
                    .onEnded { _ in
                        cancelledUntilRelease = false
                        finishPress()
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("長押しして秘密マップを見る")
            .accessibilityValue(hold.isRevealed ? "表示中" : "非表示")
            .accessibilityHint("押したまま見ることができます。指を離すと端末を渡す画面になります")
            Text("指を離すとすぐに隠れます")
                .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.65))
        }
    }

    private func updatePress(_ value: DragGesture.Value) {
        guard !cancelledUntilRelease else { return }
        if hypot(value.translation.width, value.translation.height) > 35 {
            cancelledUntilRelease = true
            finishPress()
            return
        }
        guard !hold.isPressing else { return }
        hold.begin()
        let token = UUID()
        pressToken = token
        revealTask?.cancel()
        revealTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(650)) }
            catch { return }
            guard pressToken == token, hold.isPressing else { return }
            hold.reveal()
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }

    private func finishPress() {
        revealTask?.cancel()
        revealTask = nil
        pressToken = UUID()
        if hold.end() { model.closeSecret() }
    }
}

struct SecretMapCell: View {
    let word: Word
    let role: Role
    let height: CGFloat
    private var tint: Color {
        switch role {
        case .target: return Palette.tealLight
        case .neutral: return Color(hex: 0xDCE1E4)
        case .danger: return Color(hex: 0xE6A09A)
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(role.symbol).font(.system(size: 14, weight: .black, design: .rounded))
            Text(word.text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.85)
        }
        .foregroundStyle(Palette.navy)
        .frame(maxWidth: .infinity).frame(height: height)
        .background(tint, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(word.text)、\(role.title)")
    }
}

struct PassDeviceView: View {
    @ObservedObject var model: AppModel
    let game: GameState
    private var nextPlayer: Player { game.currentClueGiver.other }

    var body: some View {
        ZStack {
            Palette.navy.ignoresSafeArea()
            VStack(spacing: 20) {
                HStack {
                    Eyebrow(text: "LINK DUO / HANDOFF", color: Palette.mint)
                    Spacer()
                    Image(systemName: "lock.shield.fill").foregroundStyle(Palette.mint)
                }
                Spacer()
                ZStack {
                    Circle().stroke(Color.white.opacity(0.15), lineWidth: 1).frame(width: 212, height: 212)
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 1).frame(width: 176, height: 176)
                    Circle().fill(Palette.mint.opacity(0.11)).frame(width: 132, height: 132)
                    Image(systemName: "iphone.gen3").font(.system(size: 48, weight: .ultraLight)).foregroundStyle(Palette.mint)
                    Image(systemName: "arrow.right").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.navy).frame(width: 35, height: 35)
                        .background(Palette.lime, in: Circle()).offset(x: 65, y: 40)
                }
                VStack(spacing: 8) {
                    Eyebrow(text: "PASS THE DEVICE", color: Palette.mint)
                    Text("\(game.playerName(nextPlayer))へ\n端末を渡してください")
                        .font(.system(size: 27, weight: .bold, design: .rounded)).tracking(-0.7).multilineTextAlignment(.center).lineSpacing(3).foregroundStyle(.white)
                    Text("秘密マップは閉じています")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.7)).padding(.top, 2)
                }
                if game.lastEvent == .neutral {
                    Label("一般ワードでした · ターン終了", systemImage: "minus.circle.fill")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(hex: 0xD4DDE2))
                        .padding(.horizontal, 12).padding(.vertical, 9).background(.white.opacity(0.09), in: Capsule())
                }
                Spacer()
                Button(action: model.acknowledgePass) {
                    HStack(spacing: 9) {
                        Text("受け取りました").font(.system(size: 15, weight: .bold, design: .rounded))
                        Image(systemName: "arrow.right").font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(Palette.navy).frame(maxWidth: .infinity, minHeight: 58)
                    .background(Palette.lime, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle()).padding(.bottom, 10)
            }
            .padding(.horizontal, 23).padding(.top, 18).padding(.bottom, 8).frame(maxWidth: 500)
        }
    }
}

struct PlayingView: View {
    @ObservedObject var model: AppModel
    let game: GameState
    let onHome: () -> Void
    @State private var clueDraft = ""
    @State private var clueCount = 1
    @State private var selectedIndex: Int?
    @State private var showRules = false
    @State private var showExitPrompt = false
    private var guesser: Player { game.currentClueGiver.other }

    var body: some View {
        GeometryReader { outer in
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Button { showExitPrompt = true } label: {
                        Image(systemName: "chevron.down").font(.system(size: 14, weight: .bold))
                            .frame(width: 44, height: 44).modifier(QuietGlass())
                    }.buttonStyle(.plain).accessibilityLabel("ゲームを閉じる")
                    VStack(alignment: .leading, spacing: 3) {
                        Eyebrow(text: "LINK DUO / LIVE")
                        Text("\(game.playerName(game.currentClueGiver)) → \(game.playerName(guesser))")
                            .font(.system(size: 12, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 2)
                    Button { showRules = true } label: {
                        Image(systemName: "questionmark")
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.ink)
                            .frame(width: 44, height: 44).modifier(QuietGlass())
                    }.buttonStyle(.plain).accessibilityLabel("遊び方")
                }
                .frame(height: 44)

                HStack(spacing: 13) {
                    VStack(alignment: .leading, spacing: 3) {
                        Eyebrow(text: "TURN \(game.turnLimit - game.turnRemaining + 1)", color: Palette.mint)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(game.turnRemaining)").font(.system(size: 28, weight: .semibold, design: .rounded)).monospacedDigit()
                            Text("残り").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 7) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(game.foundIndices.count)").font(.system(size: 24, weight: .semibold, design: .rounded)).monospacedDigit()
                            Text("/ 15  仲間").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                        }
                        HStack(spacing: 3) {
                            ForEach(0..<15, id: \.self) { index in
                                Capsule().fill(index < game.foundIndices.count ? Palette.lime : .white.opacity(0.22))
                                    .frame(width: 6, height: 5)
                            }
                        }.accessibilityHidden(true)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 19).frame(height: 78)
                .background(Palette.navy, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityElement(children: .combine)

                clueEntry
                board
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                HStack(spacing: 5) {
                    Image(systemName: "hand.tap").font(.system(size: 11))
                    Text("単語をタップして推理 · ✓ 仲間  — 一般")
                        .font(.system(size: 11, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
                }.foregroundStyle(Palette.secondary).frame(height: 18)
            }
            .padding(.horizontal, 15)
            .padding(.top, 6)
            .padding(.bottom, 4)
            .frame(maxWidth: 540, maxHeight: .infinity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if game.lastEvent == .target {
                    TargetDecisionOverlay(
                        word: game.lastEventIndex.map { game.words[$0].text } ?? "",
                        onContinue: model.continueTurn,
                        onEnd: model.endTurn
                    )
                    .transition(.opacity)
                }
            }
            .confirmationDialog(
                selectedWord.map { "「\($0.text)」を選びますか？" } ?? "このカードを選びますか？",
                isPresented: Binding(get: { selectedIndex != nil }, set: { if !$0 { selectedIndex = nil } }),
                titleVisibility: .visible
            ) {
                Button("このカードを選ぶ") {
                    if let selectedIndex { _ = model.resolveGuess(index: selectedIndex) }
                    selectedIndex = nil
                }
                Button("キャンセル", role: .cancel) { selectedIndex = nil }
            } message: {
                Text("ヒント役の秘密マップで判定します。")
            }
            .confirmationDialog("ゲームを一時中断しますか？", isPresented: $showExitPrompt, titleVisibility: .visible) {
                Button("ホームへ戻る") { onHome() }
                Button("ゲームを続ける", role: .cancel) { }
            } message: { Text("進行状況はこの端末に保存されます。") }
            .sheet(isPresented: $showRules) {
                RulesView(onBack: { showRules = false })
                    .presentationDetents([.large])
            }
            .onChange(of: game.id + game.currentClueGiver.rawValue) { _, _ in
                clueDraft = ""
                clueCount = 1
            }
            .onChange(of: outer.size.width) { _, _ in selectedIndex = nil }
        }
    }

    private var selectedWord: Word? { selectedIndex.map { game.words[$0] } }

    private var clueEntry: some View {
        HStack(spacing: 5) {
            Image(systemName: "quote.bubble.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.teal)
            TextField("ヒント（任意）", text: $clueDraft)
                .font(.system(size: 13, weight: .medium))
                .submitLabel(.done)
                .onSubmit(saveClue)
                .accessibilityLabel("ヒントの単語")
            Button { clueCount = max(1, clueCount - 1) } label: {
                Image(systemName: "minus").font(.system(size: 11, weight: .bold)).frame(width: 44, height: 44).background(Palette.canvas, in: RoundedRectangle(cornerRadius: 11))
            }.buttonStyle(.plain).accessibilityLabel("ヒント数を減らす")
            Text("\(clueCount)").font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit().frame(minWidth: 13)
            Button { clueCount = min(9, clueCount + 1) } label: {
                Image(systemName: "plus").font(.system(size: 11, weight: .bold)).frame(width: 44, height: 44).background(Palette.canvas, in: RoundedRectangle(cornerRadius: 11))
            }.buttonStyle(.plain).accessibilityLabel("ヒント数を増やす")
            Button(action: saveClue) {
                Text("記録").font(.system(size: 11, weight: .bold))
                    .foregroundStyle(clueDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Palette.secondary : .white)
                    .padding(.horizontal, 11).frame(height: 44)
                    .background(clueDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Palette.canvas : Palette.teal, in: RoundedRectangle(cornerRadius: 11))
            }.buttonStyle(.plain).disabled(clueDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 8).frame(height: 54)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(Palette.line, lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            if let clue = game.currentClue {
                Text("\(clue.word) · \(clue.count)")
                    .font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(Palette.teal)
                    .padding(.horizontal, 6).padding(.vertical, 2).background(Palette.tealLight, in: Capsule())
                    .offset(x: -8, y: -7)
            }
        }
    }

    private var board: some View {
        GeometryReader { proxy in
            let boardSize = min(proxy.size.width, proxy.size.height)
            let gap: CGFloat = boardSize < 330 ? 3 : 4
            let cellHeight = max(45, (boardSize - 4 * gap) / 5)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gap), count: 5), spacing: gap) {
                ForEach(game.words.indices, id: \.self) { index in
                    wordCard(index: index, cellHeight: cellHeight)
                }
            }
            .frame(width: boardSize, height: boardSize, alignment: .top)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func wordCard(index: Int, cellHeight: CGFloat) -> some View {
        let word = game.words[index]
        let isFound = game.foundIndices.contains(index)
        let isNeutralForTurn = game.neutralIndices(for: game.currentClueGiver).contains(index)
        let isUnavailable = isFound || isNeutralForTurn || game.lastEvent == .target
        let cellRole: Role? = isFound ? .target : (isNeutralForTurn ? .neutral : nil)
        return Button {
            guard !isUnavailable else { return }
            if model.settings.quickTap { _ = model.resolveGuess(index: index) }
            else { selectedIndex = index }
        } label: {
            VStack(spacing: 2) {
                if let cellRole {
                    Text(cellRole.symbol).font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(isFound ? Palette.teal : Palette.secondary)
                }
                Text(word.text)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.9)
                    .foregroundStyle(isFound ? Color(hex: 0x145E59) : isNeutralForTurn ? Color(hex: 0x5B6870) : Palette.ink)
            }
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity).frame(height: cellHeight)
            .background(isFound ? Palette.tealLight : isNeutralForTurn ? Color(hex: 0xE3E7E3) : Palette.card, in: RoundedRectangle(cornerRadius: cellHeight < 54 ? 10 : 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cellHeight < 54 ? 10 : 13).strokeBorder(isFound ? Palette.teal.opacity(0.45) : Palette.line.opacity(isNeutralForTurn ? 0.8 : 1), lineWidth: 1))
            .shadow(color: isFound || isNeutralForTurn ? .clear : Palette.navy.opacity(0.07), radius: 3, y: 2)
        }
        .buttonStyle(CardTapStyle())
        .disabled(isUnavailable)
        .accessibilityLabel(word.text + (isFound ? "、仲間、発見済み" : isNeutralForTurn ? "、この地図では一般" : ""))
        .accessibilityHint(isUnavailable ? "すでに判定済みです" : "ダブルタップして選択")
    }

    private func saveClue() {
        model.recordClue(word: clueDraft, count: clueCount)
    }
}

struct CardTapStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct TargetDecisionOverlay: View {
    let word: String
    let onContinue: () -> Void
    let onEnd: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.36).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 32)).foregroundStyle(Palette.teal)
                Text("仲間を見つけた").font(.system(size: 19, weight: .bold, design: .rounded))
                Text("「\(word)」は正解です")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.secondary)
                Text("もう1枚考えるか、ここでターンを終えます。")
                    .font(.system(size: 11)).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
                Button(action: onContinue) {
                    Text("推理を続ける").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48).background(Palette.teal, in: RoundedRectangle(cornerRadius: 13))
                }.buttonStyle(.plain)
                Button(action: onEnd) {
                    Text("ここでターン終了").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, minHeight: 43).background(Palette.canvas, in: RoundedRectangle(cornerRadius: 13))
                }.buttonStyle(.plain)
            }
            .padding(20).frame(maxWidth: 330)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.16), radius: 24, y: 10)
            .padding(.horizontal, 24)
        }
    }
}

struct ResultView: View {
    @ObservedObject var model: AppModel
    let game: GameState
    let onHome: () -> Void
    @State private var showMap = false
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 5)

    private var didWin: Bool { game.phase == .win }
    private var reason: String { game.lastEvent == .danger ? "危険ワードを選びました" : "ターンを使い切りました" }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 17) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 25, style: .continuous).fill(Palette.navy)
                    Circle().stroke(.white.opacity(0.12), lineWidth: 1).frame(width: 207, height: 207).offset(x: 205, y: -110)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Eyebrow(text: "LINK DUO / RESULT", color: Palette.mint)
                            Spacer()
                            Image(systemName: didWin ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 30)).foregroundStyle(didWin ? Palette.lime : Color(hex: 0xE6A09A))
                        }
                        Spacer(minLength: 9)
                        Text(didWin ? "MISSION\nCOMPLETE" : "MISSION\nFAILED")
                            .font(.system(size: 32, weight: .black, design: .rounded)).tracking(-0.7)
                            .lineSpacing(-2).foregroundStyle(.white)
                        Text(didWin ? "ふたりで仲間を見つけました" : reason)
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.77))
                    }
                    .padding(23)
                }
                .frame(height: 215).clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))

                HStack(spacing: 8) {
                    ResultMetric(value: "\(game.foundIndices.count) / 15", label: "発見した仲間", symbol: "person.fill", tint: Palette.teal)
                    ResultMetric(value: "\(game.turnsUsed)", label: "使用ターン", symbol: "arrow.trianglehead.2.clockwise", tint: Palette.amber)
                    ResultMetric(value: Self.duration(game.elapsedSeconds ?? 0), label: "プレイ時間", symbol: "clock", tint: Palette.navy)
                }
                if !didWin {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.danger)
                        Text("誤答 \(game.wrongGuesses)回").font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text(game.difficulty.title).font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.secondary)
                    }.padding(13).background(Palette.card, in: RoundedRectangle(cornerRadius: 13))
                }

                Button { withAnimation(.easeInOut(duration: 0.2)) { showMap.toggle() } } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(showMap ? "秘密マップを隠す" : "答え合わせを見る")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                            Text("A・Bそれぞれの判定と、見つけたカード")
                                .font(.system(size: 10)).foregroundStyle(Palette.secondary)
                        }
                        Spacer()
                        Image(systemName: showMap ? "chevron.up" : "chevron.down").font(.system(size: 12, weight: .bold))
                    }.foregroundStyle(Palette.ink).padding(14).background(Palette.card, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))
                }.buttonStyle(.plain)

                if showMap {
                    HStack(spacing: 8) {
                        resultLegend(.target, name: "仲間")
                        resultLegend(.neutral, name: "一般")
                        resultLegend(.danger, name: "危険")
                    }
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(game.words.indices, id: \.self) { index in
                            ResultMapCell(word: game.words[index], roleA: game.keys.a[index], roleB: game.keys.b[index], found: game.foundIndices.contains(index))
                        }
                    }.padding(8).background(Palette.card, in: RoundedRectangle(cornerRadius: 17)).overlay(RoundedRectangle(cornerRadius: 17).stroke(Palette.line, lineWidth: 1))
                }

                VStack(spacing: 9) {
                    PrimaryAction(title: "もう一度", symbol: "arrow.clockwise") { _ = model.startRematch() }
                    SecondaryAction(title: "ホームへ", symbol: "house.fill", action: onHome)
                }
                Text("この結果は、この端末の成績に保存されました。")
                    .font(.system(size: 10)).foregroundStyle(Palette.secondary).padding(.bottom, 14)
            }
            .padding(.horizontal, 19).padding(.top, 12).padding(.bottom, 15)
            .frame(maxWidth: 520).frame(maxWidth: .infinity)
        }
        .background(Palette.canvas)
    }

    private func resultLegend(_ role: Role, name: String) -> some View {
        HStack(spacing: 4) {
            Text(role.symbol).font(.system(size: 11, weight: .black))
            Text(name).font(.system(size: 10, weight: .semibold))
        }.foregroundStyle(role == .target ? Palette.teal : role == .danger ? Palette.danger : Palette.secondary)
            .frame(maxWidth: .infinity, minHeight: 31).background(Palette.card, in: RoundedRectangle(cornerRadius: 9))
    }

    private static func duration(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let remainder = max(0, seconds) % 60
        return minutes == 0 ? "\(remainder)秒" : "\(minutes):\(String(format: "%02d", remainder))"
    }
}

struct ResultMetric: View {
    let value: String
    let label: String
    let symbol: String
    let tint: Color
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(tint)
            Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.8).monospacedDigit()
            Text(label).font(.system(size: 9, weight: .medium)).foregroundStyle(Palette.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity).frame(height: 72)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))
    }
}

struct ResultMapCell: View {
    let word: Word
    let roleA: Role
    let roleB: Role
    let found: Bool

    var body: some View {
        VStack(spacing: 3) {
            Text(word.text).font(.system(size: 9, weight: .semibold, design: .rounded)).lineLimit(2).minimumScaleFactor(0.72).multilineTextAlignment(.center)
            HStack(spacing: 3) {
                Text("A\(roleA.symbol)").foregroundStyle(color(roleA))
                Text("B\(roleB.symbol)").foregroundStyle(color(roleB))
            }.font(.system(size: 7, weight: .black, design: .rounded)).lineLimit(1).minimumScaleFactor(0.75)
            if found { Image(systemName: "checkmark.circle.fill").font(.system(size: 8)).foregroundStyle(Palette.teal) }
        }
        .frame(maxWidth: .infinity).frame(height: 55)
        .padding(.horizontal, 1)
        .background(found ? Palette.tealLight.opacity(0.65) : Palette.canvas, in: RoundedRectangle(cornerRadius: 8))
    }

    private func color(_ role: Role) -> Color {
        switch role {
        case .target: return Palette.teal
        case .neutral: return Palette.secondary
        case .danger: return Palette.danger
        }
    }
}
