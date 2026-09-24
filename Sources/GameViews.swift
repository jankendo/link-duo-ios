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
                        Text("LINK DUO").font(.system(size: 11, weight: .black, design: .rounded)).tracking(2).foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        Label("PRIVATE MAP", systemImage: "lock.fill")
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
                    .fill(hold.isRevealed ? Palette.tealLight : Color.white)
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
                Spacer()
                ZStack {
                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 1).frame(width: 184, height: 184)
                    Circle().fill(Color.white.opacity(0.05)).frame(width: 148, height: 148)
                    Image(systemName: "lock.fill").font(.system(size: 46, weight: .light)).foregroundStyle(Palette.tealLight)
                }
                VStack(spacing: 8) {
                    Text("PASS THE DEVICE").font(.system(size: 9, weight: .bold, design: .rounded)).tracking(2).foregroundStyle(.white.opacity(0.52))
                    Text("\(game.playerName(nextPlayer))へ\n端末を渡してください")
                        .font(.system(size: 24, weight: .bold, design: .rounded)).multilineTextAlignment(.center).lineSpacing(3).foregroundStyle(.white)
                    Text("秘密マップは閉じています")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.62)).padding(.top, 2)
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
                    .foregroundStyle(Palette.navy).frame(maxWidth: .infinity, minHeight: 56)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            VStack(spacing: 7) {
                HStack(spacing: 8) {
                    Button { showExitPrompt = true } label: {
                        Image(systemName: "chevron.down").font(.system(size: 14, weight: .bold))
                            .frame(width: 44, height: 44).background(Palette.card, in: Circle()).overlay(Circle().stroke(Palette.line, lineWidth: 1))
                    }.buttonStyle(.plain).accessibilityLabel("ゲームを閉じる")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(game.playerName(game.currentClueGiver)) がヒント")
                            .font(.system(size: 13, weight: .bold, design: .rounded)).lineLimit(1)
                        Text("\(game.playerName(guesser)) が推理")
                            .font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 2)
                    Button { showRules = true } label: {
                        Image(systemName: "questionmark")
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.secondary)
                            .frame(width: 44, height: 44).background(Palette.card, in: Circle()).overlay(Circle().stroke(Palette.line, lineWidth: 1))
                    }.buttonStyle(.plain).accessibilityLabel("遊び方")
                }
                .frame(height: 44)

                VStack(spacing: 6) {
                    HStack {
                        Text("TURN \(game.turnLimit - game.turnRemaining + 1)")
                            .font(.system(size: 9, weight: .bold, design: .rounded)).tracking(1.2).foregroundStyle(Palette.secondary)
                        Spacer()
                        HStack(spacing: 4) {
                            Text("\(game.turnRemaining)").font(.system(size: 16, weight: .bold, design: .rounded)).monospacedDigit()
                            Text("ターン残り").font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.secondary)
                        }
                        Spacer()
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(game.foundIndices.count)").font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(Palette.teal).monospacedDigit()
                            Text("/ 15").font(.system(size: 10, weight: .semibold)).foregroundStyle(Palette.secondary)
                        }
                    }
                    GeometryReader { bar in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(hex: 0xE8EAE7))
                            Capsule().fill(Palette.teal).frame(width: bar.size.width * CGFloat(game.foundIndices.count) / 15)
                        }
                    }.frame(height: 5)
                }
                .padding(.horizontal, 13).padding(.vertical, 9)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))

                clueEntry
                board
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack(spacing: 5) {
                    Image(systemName: "hand.tap").font(.system(size: 10))
                    Text("カードを選択して推理。色と記号の両方で状態を確認できます。")
                        .font(.system(size: 9, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
                }.foregroundStyle(Palette.secondary).frame(height: 17)
            }
            .padding(.horizontal, 12)
            .padding(.top, 5)
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
        HStack(spacing: 6) {
            Image(systemName: "quote.bubble").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.teal)
            TextField("ヒントを記録（口頭だけでもOK）", text: $clueDraft)
                .font(.system(size: 13, weight: .medium))
                .submitLabel(.done)
                .onSubmit(saveClue)
                .accessibilityLabel("ヒントの単語")
            Button { clueCount = max(1, clueCount - 1) } label: {
                Image(systemName: "minus").font(.system(size: 11, weight: .bold)).frame(width: 44, height: 44).background(Palette.canvas, in: RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain).accessibilityLabel("ヒント数を減らす")
            Text("\(clueCount)").font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit().frame(minWidth: 13)
            Button { clueCount = min(9, clueCount + 1) } label: {
                Image(systemName: "plus").font(.system(size: 11, weight: .bold)).frame(width: 44, height: 44).background(Palette.canvas, in: RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain).accessibilityLabel("ヒント数を増やす")
            Button(action: saveClue) {
                Text("記録").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 11).frame(height: 44).background(Palette.teal, in: RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain).disabled(clueDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(clueDraft.isEmpty ? 0.45 : 1)
        }
        .padding(.horizontal, 8).frame(height: 54)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.line, lineWidth: 1))
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
                if let cellRole { Text(cellRole.symbol).font(.system(size: 11, weight: .black, design: .rounded)) }
                Text(word.text)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.9)
                    .foregroundStyle(isFound ? Color(hex: 0x145E59) : isNeutralForTurn ? Color(hex: 0x5B6870) : Palette.ink)
            }
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity).frame(height: cellHeight)
            .background(isFound ? Palette.tealLight : isNeutralForTurn ? Color(hex: 0xE9EBEA) : Palette.card, in: RoundedRectangle(cornerRadius: cellHeight < 54 ? 9 : 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cellHeight < 54 ? 9 : 12).stroke(isFound ? Palette.teal.opacity(0.24) : Palette.line.opacity(isNeutralForTurn ? 0.75 : 1), lineWidth: 1))
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
            VStack(spacing: 18) {
                VStack(spacing: 11) {
                    ZStack {
                        Circle().fill((didWin ? Palette.teal : Palette.danger).opacity(0.10)).frame(width: 102, height: 102)
                        Image(systemName: didWin ? "checkmark.seal.fill" : (game.lastEvent == .danger ? "exclamationmark.triangle.fill" : "hourglass.bottomhalf.filled"))
                            .font(.system(size: 42, weight: .medium)).foregroundStyle(didWin ? Palette.teal : Palette.danger)
                    }.padding(.top, 17)
                    Text(didWin ? "MISSION COMPLETE" : "MISSION FAILED")
                        .font(.system(size: 23, weight: .black, design: .rounded)).tracking(1.3)
                        .foregroundStyle(didWin ? Palette.teal : Palette.danger)
                    Text(didWin ? "ふたりで仲間を見つけました" : reason)
                        .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(Palette.ink)
                }

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
            .padding(.horizontal, 19).padding(.bottom, 15)
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
