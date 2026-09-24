import SwiftUI

enum AppScreen: Equatable {
    case home, setup, game, rules, stats, settings, words, tutorial
}

enum Palette {
    static let canvas = Color(hex: 0xF3F2ED)
    static let card = Color(hex: 0xFFFFFF)
    static let ink = Color(hex: 0x15252A)
    static let secondary = Color(hex: 0x677579)
    static let line = Color(hex: 0xDDE2DD)
    static let teal = Color(hex: 0x146F68)
    static let tealLight = Color(hex: 0xDDF1E9)
    static let mint = Color(hex: 0xBCE8D5)
    static let lime = Color(hex: 0xD8F36B)
    static let amber = Color(hex: 0xB77832)
    static let amberLight = Color(hex: 0xF6EBD7)
    static let danger = Color(hex: 0x9E4747)
    static let dangerLight = Color(hex: 0xF6E5E2)
    static let navy = Color(hex: 0x142B31)
}

struct Eyebrow: View {
    let text: String
    var color: Color = Palette.teal
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .tracking(1.8)
            .foregroundStyle(color)
    }
}

struct QuietGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: Circle())
        } else {
            content.background(.regularMaterial, in: Circle())
        }
    }
}

struct InstrumentPanel<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.line.opacity(0.8), lineWidth: 1))
            .shadow(color: Palette.navy.opacity(0.045), radius: 18, y: 7)
    }
}

extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: 1
        )
    }
}

struct ContentView: View {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var screen: AppScreen = .home
    @State private var wordsReturnScreen: AppScreen = .settings
    @State private var privacyCover = false
    @State private var didRouteInitialTutorial = false

    var body: some View {
        Group {
            switch screen {
            case .home:
                HomeView(model: model, onNavigate: navigate)
            case .setup:
                SetupView(model: model, onBack: { screen = .home }, onManageWords: { wordsReturnScreen = .setup; screen = .words }, onStart: {
                    if model.startNewGame() { screen = .game }
                })
            case .game:
                GameView(model: model, onHome: { model.abandonToHome(); screen = .home })
            case .rules:
                RulesView(onBack: { screen = .home })
            case .stats:
                StatsView(model: model, onBack: { screen = .home })
            case .settings:
                SettingsView(model: model, onBack: { screen = .home }, onWords: { wordsReturnScreen = .settings; screen = .words })
            case .words:
                CustomWordsView(model: model, onBack: { screen = wordsReturnScreen })
            case .tutorial:
                TutorialView(onSkip: { model.finishTutorial(); screen = .home }, onStart: {
                    model.finishTutorial()
                    screen = .setup
                })
            }
        }
        .background(Palette.canvas.ignoresSafeArea())
        .foregroundStyle(Palette.ink)
        .preferredColorScheme(.light)
        .alert("お知らせ", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("閉じる", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .overlay {
            if privacyCover {
                ZStack {
                    Palette.navy.ignoresSafeArea()
                    VStack(spacing: 12) {
                        Image(systemName: "lock.fill").font(.system(size: 30, weight: .medium))
                        Text("LINK DUO").font(.system(size: 13, weight: .bold, design: .rounded)).tracking(2)
                    }.foregroundStyle(.white.opacity(0.9))
                }.transition(.opacity)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            privacyCover = phase != .active
        }
        .onAppear {
            guard !didRouteInitialTutorial else { return }
            didRouteInitialTutorial = true
#if DEBUG
            let previewArgs = ProcessInfo.processInfo.arguments
            if previewArgs.contains("--ui-preview-playing") {
                model.finishTutorial()
                if model.startNewGame() {
                    model.closeSecret()
                    model.acknowledgePass()
                    screen = .game
                }
                return
            }
            if previewArgs.contains("--ui-preview-home") {
                model.finishTutorial()
                screen = .home
                return
            }
#endif
            if !model.tutorialSeen { screen = .tutorial }
        }
    }

    private func navigate(_ next: AppScreen) { screen = next }
}

struct ScreenHeader: View {
    let title: String
    var eyebrow: String? = nil
    var onBack: (() -> Void)? = nil
    var trailing: AnyView? = nil

    var body: some View {
        HStack(spacing: 12) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .modifier(QuietGlass())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("戻る")
            }
            VStack(alignment: .leading, spacing: 2) {
                if let eyebrow {
                    Eyebrow(text: eyebrow, color: Palette.secondary)
                }
                Text(title).font(.system(size: 23, weight: .bold, design: .rounded)).tracking(-0.7).foregroundStyle(Palette.ink)
            }
            Spacer(minLength: 8)
            if let trailing { trailing }
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

struct PrimaryAction: View {
    let title: String
    var symbol: String? = nil
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let symbol { Image(systemName: symbol).font(.system(size: 15, weight: .semibold)) }
                Text(title).font(.system(size: 16, weight: .bold, design: .rounded)).tracking(0.2)
                Spacer(minLength: 0)
                Image(systemName: "arrow.right").font(.system(size: 13, weight: .semibold)).opacity(0.72)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 19)
            .frame(minHeight: 58)
            .background(disabled ? Palette.secondary : Palette.navy, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1))
            .shadow(color: disabled ? .clear : Palette.navy.opacity(0.15), radius: 13, y: 6)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(disabled)
    }
}

struct SecondaryAction: View {
    let title: String
    var symbol: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if let symbol { Image(systemName: symbol).font(.system(size: 15, weight: .semibold)) }
                Text(title).font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.secondary)
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 15)
            .frame(minHeight: 52)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.line, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct LogoMark: View {
    var size: CGFloat = 46
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous).fill(Palette.navy)
            VStack(spacing: size * 0.06) {
                HStack(spacing: size * 0.06) {
                    square(Palette.tealLight); square(Palette.card); square(Palette.tealLight)
                }
                HStack(spacing: size * 0.06) {
                    square(Palette.card); square(Palette.teal); square(Palette.card)
                }
                HStack(spacing: size * 0.06) {
                    square(Palette.tealLight); square(Palette.card); square(Palette.tealLight)
                }
            }.padding(size * 0.18)
        }.frame(width: size, height: size)
    }
    private func square(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: size * 0.045, style: .continuous).fill(color)
    }
}

struct HomeView: View {
    @ObservedObject var model: AppModel
    let onNavigate: (AppScreen) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 21) {
                HStack(spacing: 12) {
                    LogoMark(size: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LINK DUO").font(.system(size: 15, weight: .black, design: .rounded)).tracking(2.2)
                        Text("COOPERATIVE WORD GAME").font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1.1).foregroundStyle(Palette.secondary)
                    }
                    Spacer()
                    Button { onNavigate(.settings) } label: {
                        Image(systemName: "slider.horizontal.3").font(.system(size: 16, weight: .medium)).foregroundStyle(Palette.ink)
                            .frame(width: 44, height: 44).modifier(QuietGlass())
                    }.buttonStyle(.plain).accessibilityLabel("設定")
                }
                .padding(.top, 9)

                VStack(alignment: .leading, spacing: 11) {
                    Eyebrow(text: "TWO MINDS · ONE MISSION")
                    Text("言葉でつなぐ、\nふたりの直感。")
                        .font(.system(size: 34, weight: .bold, design: .rounded)).tracking(-1.8)
                        .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                    Text("秘密の地図を頼りに、25の言葉から\n15の仲間を見つけよう。")
                        .font(.system(size: 14, weight: .medium)).lineSpacing(4).foregroundStyle(Palette.secondary)
                }
                .padding(.top, 8)

                MissionArtwork()
                    .frame(height: 205)
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    PrimaryAction(title: "新しいゲームを始める", symbol: "sparkle") { onNavigate(.setup) }
                    if model.hasResumableGame {
                        SecondaryAction(title: "つづきから", symbol: "arrow.clockwise") {
                            if model.resumeGame() { onNavigate(.game) }
                        }
                    }
                }
                HStack(spacing: 10) {
                    SecondaryAction(title: "遊び方", symbol: "book.closed") { onNavigate(.rules) }
                    SecondaryAction(title: "成績", symbol: "chart.bar.xaxis") { onNavigate(.stats) }
                }
                HStack(spacing: 7) {
                    Image(systemName: "iphone.gen3").foregroundStyle(Palette.teal)
                    Text("スマホ1台・2人専用・オフラインで遊べます")
                        .foregroundStyle(Palette.secondary)
                }
                .font(.system(size: 11, weight: .medium))
                .padding(.bottom, 15)
            }
            .padding(.horizontal, 22)
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
        }
    }
}

struct MissionArtwork: View {
    private let active: Set<Int> = [2, 6, 10, 12, 18, 21, 24]
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Palette.navy)
                Circle().stroke(.white.opacity(0.08), lineWidth: 1)
                    .frame(width: 235, height: 235).offset(x: proxy.size.width - 163, y: -125)
                Circle().stroke(.white.opacity(0.08), lineWidth: 1)
                    .frame(width: 325, height: 325).offset(x: proxy.size.width - 218, y: -169)
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Eyebrow(text: "THE FIELD / 01", color: Palette.mint)
                        Spacer()
                        Image(systemName: "circle.hexagongrid")
                            .font(.system(size: 18, weight: .light)).foregroundStyle(Palette.mint)
                    }
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("25 : 15")
                                .font(.system(size: 40, weight: .light, design: .rounded))
                                .tracking(-2).monospacedDigit().foregroundStyle(.white)
                            Text("見えている言葉。隠された答え。")
                                .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(13), spacing: 4), count: 5), spacing: 4) {
                            ForEach(0..<25, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(active.contains(i) ? Palette.lime : .white.opacity(0.22))
                                    .frame(width: 13, height: 13)
                            }
                        }
                        .frame(width: 81)
                    }
                }
                .padding(23)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
    }
}

struct FeaturePill: View {
    let symbol: String
    let title: String
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 10, weight: .bold))
            Text(title).font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(Palette.teal)
        .padding(.horizontal, 9).padding(.vertical, 8)
        .background(Palette.tealLight.opacity(0.72), in: Capsule())
        .lineLimit(1).minimumScaleFactor(0.8)
    }
}

struct SetupView: View {
    @ObservedObject var model: AppModel
    let onBack: () -> Void
    let onManageWords: () -> Void
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "ゲームを準備", eyebrow: "NEW ROUND", onBack: onBack)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    sectionTitle("PLAYERS", "ふたりの名前")
                    VStack(spacing: 10) {
                        NameField(label: "PLAYER A", text: Binding(
                            get: { model.settings.playerA },
                            set: { value in model.updateSettings { $0.playerA = value } }
                        ), icon: "a.circle.fill")
                        NameField(label: "PLAYER B", text: Binding(
                            get: { model.settings.playerB },
                            set: { value in model.updateSettings { $0.playerB = value } }
                        ), icon: "b.circle.fill")
                    }

                    sectionTitle("DIFFICULTY", "制限ターンを選択")
                    VStack(spacing: 8) {
                        ForEach(Difficulty.allCases) { difficulty in
                            SelectionRow(
                                title: difficulty.title,
                                subtitle: difficulty.subtitle,
                                selected: model.settings.difficulty == difficulty,
                                trailing: difficulty == .custom ? nil : "\(difficulty.turnLimit(custom: model.settings.customTurns))"
                            ) {
                                model.updateSettings { $0.difficulty = difficulty }
                            }
                        }
                        if model.settings.difficulty == .custom {
                            HStack {
                                Text("ターン数").font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Stepper("\(model.settings.customTurns) ターン", value: Binding(
                                    get: { model.settings.customTurns },
                                    set: { value in model.updateSettings { $0.customTurns = value } }
                                ), in: 5...15).labelsHidden()
                                Text("\(model.settings.customTurns) ターン").font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit()
                            }
                            .padding(14).background(Palette.card, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    sectionTitle("WORD PACK", "盤面の単語")
                    VStack(spacing: 8) {
                        ForEach(WordPack.allCases) { pack in
                            SelectionRow(
                                title: pack.title,
                                subtitle: pack == .custom ? "登録済み \(model.customWordCount)語 · 25語以上で使用可能" : pack.description,
                                selected: model.settings.pack == pack,
                                trailing: pack == .custom ? "\(model.customWordCount)" : nil
                            ) {
                                model.updateSettings { $0.pack = pack }
                            }
                        }
                        if model.settings.pack == .custom && model.customWordCount < 25 {
                            Button(action: onManageWords) {
                                Label("単語を25語以上登録", systemImage: "plus.circle.fill")
                                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.teal)
                                    .frame(maxWidth: .infinity, minHeight: 44).background(Palette.tealLight.opacity(0.6), in: RoundedRectangle(cornerRadius: 13))
                            }.buttonStyle(.plain)
                        }
                    }
                    PrimaryAction(title: "ゲーム開始", symbol: "play.fill", disabled: model.settings.pack == .custom && model.customWordCount < 25, action: onStart)
                        .padding(.top, 3)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 13)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func sectionTitle(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.5).foregroundStyle(Palette.teal)
            Text(subtitle).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
        }
    }
}

struct NameField: View {
    let label: String
    @Binding var text: String
    let icon: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 22)).foregroundStyle(Palette.teal).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 9, weight: .bold, design: .rounded)).tracking(1.3).foregroundStyle(Palette.secondary)
                TextField(label, text: $text).font(.system(size: 15, weight: .semibold)).textInputAutocapitalization(.words).autocorrectionDisabled().submitLabel(.done)
            }
        }
        .padding(.horizontal, 14).frame(minHeight: 62)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Palette.line, lineWidth: 1))
    }
}

struct SelectionRow: View {
    let title: String
    let subtitle: String
    let selected: Bool
    var trailing: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20, weight: .medium)).foregroundStyle(selected ? Palette.teal : Palette.line)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
                    Text(subtitle).font(.system(size: 11, weight: .regular)).foregroundStyle(Palette.secondary).lineLimit(1).minimumScaleFactor(0.82)
                }
                Spacer(minLength: 4)
                if let trailing { Text(trailing).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(Palette.secondary).monospacedDigit() }
            }
            .padding(.horizontal, 13).frame(minHeight: 58)
            .background(selected ? Palette.tealLight.opacity(0.55) : Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Palette.teal.opacity(0.45) : Palette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct TutorialView: View {
    let onSkip: () -> Void
    let onStart: () -> Void
    @State private var page = 0
    private let items: [(String, String, String, Color)] = [
        ("square.grid.3x3.fill", "25枚の単語から\n仲間を探します", "盤面には毎回ちがう25個の言葉が並びます。目指すのは、ふたりで15人の仲間を見つけること。", Palette.teal),
        ("eye.slash.fill", "秘密の情報は\nそれぞれ別々", "ヒントを出す人だけが秘密マップを見ます。長押し中だけ表示され、指を離すと相手に渡す画面へ切り替わります。", Palette.navy),
        ("quote.bubble.fill", "言葉と数字で\nヒントをつなぐ", "「宇宙 2」のように、複数の単語を連想できるヒントを出します。相手は安全だと思うカードを選びます。", Palette.amber),
        ("flag.checkered", "危険を避けて\n15人を見つけよう", "一般ワードを選ぶとターン終了。危険ワードを選ぶと即ゲームオーバーです。ターンが尽きる前に仲間をそろえましょう。", Palette.danger)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                LogoMark(size: 36)
                Text("LINK DUO").font(.system(size: 12, weight: .black, design: .rounded)).tracking(2)
                Spacer()
                Button("スキップ", action: onSkip).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.secondary)
            }.padding(.horizontal, 22).padding(.top, 12)
            TabView(selection: $page) {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]
                    VStack(spacing: 22) {
                        Spacer()
                        ZStack {
                            Circle().fill(item.3.opacity(0.10)).frame(width: 190, height: 190)
                            Circle().stroke(item.3.opacity(0.17), lineWidth: 1).frame(width: 216, height: 216)
                            Image(systemName: item.0).font(.system(size: 49, weight: .medium)).foregroundStyle(item.3)
                        }.padding(.bottom, 10)
                        Text("0\(index + 1) / 04").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(2).foregroundStyle(item.3)
                        Text(item.1).font(.system(size: 27, weight: .bold, design: .rounded)).multilineTextAlignment(.center).lineSpacing(3)
                        Text(item.2).font(.system(size: 15)).lineSpacing(7).multilineTextAlignment(.center).foregroundStyle(Palette.secondary).padding(.horizontal, 30)
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .safeAreaInset(edge: .bottom, spacing: 0) {
                PrimaryAction(title: page == items.count - 1 ? "プレイを始める" : "次へ", symbol: page == items.count - 1 ? "play.fill" : "arrow.right") {
                    if page == items.count - 1 { onStart() } else { withAnimation(.easeInOut(duration: 0.2)) { page += 1 } }
                }
                .padding(.horizontal, 22).padding(.bottom, 8)
            }
        }
    }
}

struct RulesView: View {
    let onBack: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "遊び方", eyebrow: "HOW TO PLAY", onBack: onBack)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    ruleCard(number: "01", title: "目的", detail: "25枚の単語から、盤面全体にいる15人の仲間をすべて見つけます。ふたりで協力して、危険ワードを避けましょう。", symbol: "scope", tint: Palette.teal)
                    ruleCard(number: "02", title: "秘密マップ", detail: "ヒントを出す人は長押しで自分だけの地図を確認します。ふたりのマップは少しずつ違い、それぞれ9人の仲間と3つの危険があります。", symbol: "eye.slash", tint: Palette.navy)
                    ruleCard(number: "03", title: "ヒントと推理", detail: "ヒント役は「宇宙 2」のように言葉と数字を伝えます。推理役はカードを選び、ヒント役の地図で判定します。仲間なら続けるか、ターンを終えます。", symbol: "quote.bubble", tint: Palette.amber)
                    HStack(spacing: 9) {
                        roleLegend(.target); roleLegend(.neutral); roleLegend(.danger)
                    }
                    ruleCard(number: "04", title: "ターンと勝敗", detail: "一般ワードを選ぶとターンが終了します。危険ワードは即敗北。制限ターン内に15人を見つければ勝利です。", symbol: "flag.checkered", tint: Palette.danger)
                    Text("困ったら、ヒントはアプリに入力せず口頭だけでも遊べます。正解を一度にすべて説明するヒントは避けて、ふたりの会話を楽しんでください。")
                        .font(.system(size: 12)).lineSpacing(5).foregroundStyle(Palette.secondary).padding(15)
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(Palette.line, lineWidth: 1))
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20).padding(.top, 12).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
        }
    }

    private func ruleCard(number: String, title: String, detail: String, symbol: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 16, weight: .semibold)).foregroundStyle(tint)
                    .frame(width: 38, height: 38).background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                Text(number).font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(Palette.secondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 16, weight: .bold, design: .rounded))
                Text(detail).font(.system(size: 12)).lineSpacing(4).foregroundStyle(Palette.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14).background(Palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1))
    }

    private func roleLegend(_ role: Role) -> some View {
        HStack(spacing: 5) {
            Text(role.symbol).font(.system(size: 12, weight: .black, design: .rounded))
            Text(role.title).font(.system(size: 11, weight: .semibold))
        }.foregroundStyle(role == .target ? Palette.teal : role == .danger ? Palette.danger : Palette.secondary)
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(role == .target ? Palette.tealLight : role == .danger ? Palette.dangerLight : Color(hex: 0xECEEED), in: RoundedRectangle(cornerRadius: 11))
    }
}
