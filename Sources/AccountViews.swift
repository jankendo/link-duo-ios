import SwiftUI

struct StatsView: View {
    @ObservedObject var model: AppModel
    let onBack: () -> Void
    @State private var confirmClear = false

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "成績と履歴", eyebrow: "YOUR RECORD", onBack: onBack)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 17) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                        StatTile(value: "\(model.stats.games)", label: "総プレイ", symbol: "gamecontroller.fill", tint: Palette.navy)
                        StatTile(value: "\(model.stats.wins)", label: "勝利", symbol: "checkmark.seal.fill", tint: Palette.teal)
                        StatTile(value: "\(model.stats.winRate)%", label: "勝率", symbol: "chart.pie.fill", tint: Palette.amber)
                        StatTile(value: "\(model.stats.currentStreak)", label: "連勝中", symbol: "flame.fill", tint: Palette.danger)
                        StatTile(value: "\(model.stats.bestStreak)", label: "最高連勝", symbol: "trophy.fill", tint: Palette.amber)
                        StatTile(value: averageTurns, label: "平均クリアターン", symbol: "arrow.trianglehead.2.clockwise", tint: Palette.teal)
                    }
                    HStack {
                        Text("最速クリア").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.secondary)
                        Spacer()
                        Text(model.stats.fastestSeconds.map(formatDuration) ?? "—")
                            .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink).monospacedDigit()
                    }.padding(14).background(Palette.card, in: RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.line, lineWidth: 1))

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("最近のゲーム").font(.system(size: 17, weight: .bold, design: .rounded))
                            Text("この端末に保存された最新20件")
                                .font(.system(size: 10)).foregroundStyle(Palette.secondary)
                        }
                        Spacer()
                        if !model.history.isEmpty {
                            Button("履歴を消去") { confirmClear = true }
                                .font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.danger)
                        }
                    }
                    if model.history.isEmpty {
                        VStack(spacing: 9) {
                            Image(systemName: "chart.bar.xaxis").font(.system(size: 26)).foregroundStyle(Palette.secondary.opacity(0.7))
                            Text("ゲームを始めると、ここに記録が残ります")
                                .font(.system(size: 12)).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity).padding(.vertical, 25)
                            .background(Palette.card, in: RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(Palette.line, lineWidth: 1))
                    } else {
                        VStack(spacing: 0) {
                            let recent = Array(model.history.prefix(20))
                            ForEach(recent) { record in
                                HistoryRow(record: record)
                                if record.id != recent.last?.id { Divider().overlay(Palette.line).padding(.leading, 14) }
                            }
                        }
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Palette.line, lineWidth: 1))
                    }
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20).padding(.top, 12)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
        }
        .confirmationDialog("保存された対戦履歴を消去しますか？", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("履歴を消去", role: .destructive) { model.clearHistory() }
            Button("キャンセル", role: .cancel) { }
        } message: { Text("成績も0に戻ります。この操作は取り消せません。") }
    }

    private var averageTurns: String {
        model.stats.averageTurns.map { String(format: "%.1f", $0) } ?? "—"
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return minutes == 0 ? "\(remainder)秒" : "\(minutes)分\(String(format: "%02d", remainder))秒"
    }
}

struct StatTile: View {
    let value: String
    let label: String
    let symbol: String
    let tint: Color
    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 34, height: 34).background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) {
                Text(value).font(.system(size: 18, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.75)
                Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11).frame(minHeight: 66)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))
    }
}

struct HistoryRow: View {
    let record: MatchRecord
    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: record.won ? "checkmark.seal.fill" : record.dangerSelected ? "exclamationmark.triangle.fill" : "hourglass.bottomhalf.filled")
                .font(.system(size: 17)).foregroundStyle(record.won ? Palette.teal : Palette.danger).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(record.won ? "MISSION COMPLETE" : "MISSION FAILED")
                    .font(.system(size: 10, weight: .bold, design: .rounded)).tracking(0.5)
                    .foregroundStyle(record.won ? Palette.teal : Palette.danger)
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10)).foregroundStyle(Palette.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(record.targetsFound) / 15 · \(record.turnsUsed)T")
                    .font(.system(size: 11, weight: .bold, design: .rounded)).monospacedDigit()
                Text("\(record.difficulty.title) · \(duration(record.playSeconds))")
                    .font(.system(size: 9, weight: .medium)).foregroundStyle(Palette.secondary)
            }
        }.padding(.horizontal, 13).padding(.vertical, 12)
    }

    private func duration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return minutes > 0 ? "\(minutes)分" : "\(seconds)秒"
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    let onBack: () -> Void
    let onWords: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "設定", eyebrow: "PREFERENCES", onBack: onBack)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 19) {
                    VStack(spacing: 0) {
                        ToggleRow(title: "タップですぐ判定", detail: "カードをタップした時点で選択", isOn: Binding(
                            get: { model.settings.quickTap },
                            set: { value in model.updateSettings { $0.quickTap = value } }
                        ), symbol: "hand.tap.fill")
                    }
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1))

                    VStack(alignment: .leading, spacing: 9) {
                        Text("CUSTOM WORDS").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.4).foregroundStyle(Palette.teal)
                        SecondaryAction(title: "カスタム単語を管理", symbol: "text.badge.plus") { onWords() }
                        Text("単語はこの端末に保存されます。25語登録するとCUSTOMパックで遊べます。")
                            .font(.system(size: 11)).lineSpacing(4).foregroundStyle(Palette.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("ABOUT").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.4).foregroundStyle(Palette.teal)
                        VStack(spacing: 0) {
                            SettingInfoRow(label: "バージョン", value: "1.0.0")
                            Divider().overlay(Palette.line).padding(.leading, 14)
                            SettingInfoRow(label: "プレイ方式", value: "1台で2人・オフライン")
                            Divider().overlay(Palette.line).padding(.leading, 14)
                            SettingInfoRow(label: "保存先", value: "この端末のみ")
                        }.background(Palette.card, in: RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(Palette.line, lineWidth: 1))
                    }
                    Text("名前・設定・成績・途中のゲームはiPhone内に保存されます。アカウント登録や通信は必要ありません。")
                        .font(.system(size: 11)).lineSpacing(4).foregroundStyle(Palette.secondary)
                        .padding(.horizontal, 2)
                    Spacer(minLength: 25)
                }
                .padding(.horizontal, 20).padding(.top, 12)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
        }
    }
}

struct ToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool
    let symbol: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.teal).frame(width: 34, height: 34).background(Palette.tealLight.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 10)).foregroundStyle(Palette.secondary)
            }
            Spacer(minLength: 4)
            Toggle(title, isOn: $isOn).labelsHidden().tint(Palette.teal).accessibilityLabel(title)
        }.padding(.horizontal, 13).padding(.vertical, 12)
    }
}

struct SettingInfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.secondary)
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold))
        }.padding(.horizontal, 14).frame(minHeight: 43)
    }
}

struct CustomWordsView: View {
    @ObservedObject var model: AppModel
    let onBack: () -> Void
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "カスタム単語", eyebrow: "YOUR WORDS", onBack: onBack)
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("CUSTOM PACK").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.2).foregroundStyle(Palette.teal)
                    Spacer()
                    Text("\(model.customWordCount) / 300語").font(.system(size: 12, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(model.customWordCount >= 25 ? Palette.teal : Palette.secondary)
                }
                Text("ふたりだけの言葉で遊ぶ")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("地名や思い出の言葉も登録できます。25語以上でゲーム開始できます。")
                    .font(.system(size: 12)).lineSpacing(4).foregroundStyle(Palette.secondary)
                HStack(spacing: 8) {
                    TextField("単語を追加", text: $draft)
                        .font(.system(size: 14)).padding(.horizontal, 13).frame(height: 48)
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.line, lineWidth: 1))
                        .submitLabel(.done).onSubmit(addWord)
                    Button(action: addWord) {
                        Image(systemName: "plus").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 48, height: 48).background(Palette.teal, in: RoundedRectangle(cornerRadius: 13))
                    }.buttonStyle(.plain).accessibilityLabel("単語を追加")
                }
                if model.customWords.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "text.badge.plus").font(.system(size: 24)).foregroundStyle(Palette.secondary)
                        Text("まだ単語がありません").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 24).background(Palette.card, in: RoundedRectangle(cornerRadius: 15))
                } else {
                    List {
                        ForEach(model.settings.customWords) { word in
                            HStack(spacing: 10) {
                                Text(word.text).font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Button { model.removeCustomWord(id: word.id) } label: {
                                    Image(systemName: "trash").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.danger)
                                        .frame(width: 40, height: 40).contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityLabel("\(word.text)を削除")
                            }.listRowBackground(Palette.card)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 15))
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(Palette.line, lineWidth: 1))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 10)
            .frame(maxWidth: 560, maxHeight: .infinity).frame(maxWidth: .infinity)
        }
        .background(Palette.canvas)
    }

    private func addWord() {
        guard model.addCustomWord(draft) else { return }
        draft = ""
    }
}
