import SwiftUI

private enum Theme {
    static let background = Color(red: 0.045, green: 0.065, blue: 0.13)
    static let card = Color(red: 0.085, green: 0.115, blue: 0.20)
    static let cyan = Color(red: 0.39, green: 0.83, blue: 0.96)
    static let muted = Color(red: 0.66, green: 0.73, blue: 0.83)
}

struct DashboardView: View {
    @StateObject private var client = TradeClient()
    @State private var showSettings = false
    @State private var confirmPause = false
    @State private var confirmResume = false
    @State private var selectedExperiment = "EXP-007"
    private let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Label("DEMO ONLY", systemImage: "checkmark.shield.fill")
                            .font(.caption.bold()).foregroundStyle(Theme.cyan)
                        Spacer()
                        if let date = client.lastUpdated {
                            Text(date, style: .time).font(.caption).foregroundStyle(Theme.muted)
                        }
                    }
                    statusCard
                    HStack(spacing: 12) {
                        metric("EXP-007 累計損益", yen(client.dashboard?.totalProfit), "yensign.circle")
                        metric("EXP-007 勝率", String(format: "%.1f%%", client.dashboard?.winRate ?? 0), "chart.bar")
                    }
                    analysisCard
                    experimentHistoryCard
                    historyCard
                    if let error = client.error {
                        Text(error).font(.footnote).foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text("※ EXP-007の成績は記録済みのEXP-007決済分のみ。日次安全判定の対象期間とは異なる場合があります。未記録の取引があれば実際の損益とも異なります。")
                        .font(.caption2).foregroundStyle(Theme.muted)
                }.padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .foregroundStyle(.white)
            .navigationTitle("VTuTRADE")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { Task { await client.refresh() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }.disabled(client.loading)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(isPresented: $showSettings) {
                settingsView
            }
            .alert("新規注文を停止しますか？", isPresented: $confirmPause) {
                Button("停止する", role: .destructive) { Task { await client.pause() } }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("保有中の注文はキャンセルせず、決済まで監視する設計です。")
            }
            .alert("新規注文を再開しますか？", isPresented: $confirmResume) {
                Button("再開する") { Task { await client.resume() } }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("DEMO環境で新規注文を再開します。エンジンがREADYで未決済注文や復旧待ちがない場合に限り、サーバーが許可します。")
            }
            .task { await client.refresh() }
            .onReceive(timer) { _ in
                if !showSettings { Task { await client.refresh() } }
            }
            .onChange(of: client.history?.experiments.map(\.experimentId) ?? []) { previousIDs, ids in
                // EXP-007の取引が初めて記録された際、自動的に最新実験へ切り替える。
                // その後、ユーザーが過去実験を選択した場合は選択を尊重する。
                if ids.contains("EXP-007") && !previousIDs.contains("EXP-007") {
                    selectedExperiment = "EXP-007"
                } else if !ids.contains(selectedExperiment), let first = ids.first {
                    selectedExperiment = first
                }
            }
        }
        .tint(Theme.cyan)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Circle().fill(client.dashboard?.paused == false ? .green : .orange)
                    .frame(width: 9, height: 9)
                Text(client.dashboard == nil ? "接続待ち" : (client.dashboard!.paused ? "新規注文：一時停止中" : "新規注文：許可中"))
                    .font(.headline)
            }
            Text("エンジン状態：\(client.dashboard?.engineStatus ?? "未取得")")
                .font(.subheadline).foregroundStyle(Theme.muted)
            Text("注文記録（全期間）：\(client.dashboard?.orders ?? 0)件")
                .font(.caption).foregroundStyle(Theme.muted)
            Text("決済記録（EXP-007）：\(client.dashboard?.totalTrades ?? 0)件")
                .font(.caption).foregroundStyle(Theme.muted)
            if client.dashboard?.paused == false {
                Button {
                    confirmPause = true
                } label: {
                    Label("新規注文を一時停止", systemImage: "pause.fill")
                        .frame(maxWidth: .infinity).padding(12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(client.controlBusy)
            } else {
                Button {
                    confirmResume = true
                } label: {
                    Label("新規注文を再開", systemImage: "play.fill")
                        .frame(maxWidth: .infinity).padding(12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(client.dashboard?.canResume != true || client.controlBusy)
                if client.dashboard != nil && client.dashboard?.canResume != true {
                    Text("再開不可：エンジンのREADY状態・未決済注文・復旧待ちを確認してください。")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
            }
        }.cardStyle()
    }

    private func metric(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(Theme.muted)
            Text(value).font(.title3.bold()).minimumScaleFactor(0.7).lineLimit(1)
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle()
    }

    private var analysisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("テクニカル分析（EXP-007）").font(.headline)
                Spacer()
                Text("参考: \(client.dashboard?.signal ?? "—")")
                    .font(.subheadline.bold()).foregroundStyle(Theme.cyan)
            }
            HStack(spacing: 12) {
                valueColumn("USD/JPY（基準）", number(client.dashboard?.analysis?.close, 3))
                valueColumn("5分間の変動", priceChange(client.dashboard?.analysis?.change5min))
            }
            Divider().overlay(Theme.muted.opacity(0.3))
            HStack(spacing: 12) {
                valueColumn("15秒間の変動", priceChange(client.dashboard?.analysis?.change15sec))
                valueColumn("HIGH価格条件", highConditionText(client.dashboard?.analysis))
            }
            if let t = client.dashboard?.analysis?.time {
                // APIのtimeはUTCの分析基準時刻。1分を加算せずJSTへ変換する。
                Text("分析基準時刻（日本時間）：\(jstTime(t))")
                    .font(.caption2).foregroundStyle(Theme.muted)
            }
            Text("※ 参考値は毎分00秒の基準価格から算出。HIGH価格条件が成立しても、注文時刻・安全制御などを満たさなければ発注されません。")
                .font(.caption2).foregroundStyle(Theme.muted)
        }.cardStyle()
    }

    private func valueColumn(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(Theme.muted)
            Text(value).font(.system(.body, design: .monospaced).bold())
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var experimentHistoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("実験別戦歴").font(.headline)
            if let experiments = client.history?.experiments, !experiments.isEmpty {
                Picker("実験", selection: $selectedExperiment) {
                    ForEach(experiments) { experiment in
                        Text(experiment.name).tag(experiment.experimentId)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.cyan)

                if let experiment = experiments.first(where: { $0.experimentId == selectedExperiment })
                    ?? experiments.first {
                    HStack(spacing: 12) {
                        valueColumn("取引数", "\(experiment.totalTrades)件")
                        valueColumn("勝率", String(format: "%.2f%%", experiment.winRate))
                    }
                    HStack(spacing: 12) {
                        valueColumn("勝ち", "\(experiment.wins)件")
                        valueColumn("負け", "\(experiment.losses)件")
                    }
                    Divider().overlay(Theme.muted.opacity(0.3))
                    Text("累計損益：\(yen(experiment.totalProfit))")
                        .font(.headline)
                        .foregroundStyle(experiment.totalProfit < 0 ? .orange : Theme.cyan)
                    Text("平均損益：\(yen(experiment.averageProfit))")
                        .font(.subheadline)
                    if let start = experiment.firstTradeJst, let end = experiment.lastTradeJst {
                        Text("期間（日本時間）：\(start) 〜 \(end)")
                            .font(.caption2).foregroundStyle(Theme.muted)
                    }
                    Text("直近の決済履歴（最大20件）")
                        .font(.subheadline.bold())
                    if experiment.recentTrades.isEmpty {
                        Text("決済履歴はありません")
                            .font(.caption).foregroundStyle(Theme.muted)
                    } else {
                        ForEach(experiment.recentTrades) { trade in
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(trade.result == "WIN" ? "勝ち" : (trade.result == "LOSS" ? "負け" : "未判定"))
                                        .font(.caption.bold())
                                    Text("ID: \(trade.tradeId ?? "—")")
                                        .font(.caption2).foregroundStyle(Theme.muted)
                                    if let timestamp = trade.timestampJst ?? trade.timestamp {
                                        Text("決済：" + displayJST(timestamp))
                                            .font(.caption2).foregroundStyle(Theme.muted)
                                    }
                                    if let orderTime = trade.orderTimestampJst {
                                        Text("注文：" + displayJST(orderTime))
                                            .font(.caption2).foregroundStyle(Theme.muted)
                                    }
                                    if let analysis = trade.orderAnalysis {
                                        Text(orderReason(analysis, direction: trade.orderDirection ?? trade.contract?.components(separatedBy: "|").last))
                                            .font(.caption2).foregroundStyle(Theme.muted)
                                    }
                                }
                                Spacer(minLength: 8)
                                Text(yen(trade.profit))
                                    .font(.subheadline.bold())
                                    .foregroundStyle((trade.profit ?? 0) < 0 ? .orange : Theme.cyan)
                            }
                            Divider().overlay(Theme.muted.opacity(0.2))
                        }
                    }
                }
            } else {
                Text(client.historyError ?? "実験別戦歴を取得しています…")
                    .font(.caption).foregroundStyle(Theme.muted)
            }
            if let error = client.historyError, client.history != nil {
                Text(error).font(.caption).foregroundStyle(.orange)
            }
            Text("※ デモ取引の決済ログから集計。実験の境界はサーバー側の記録に基づきます。")
                .font(.caption2).foregroundStyle(Theme.muted)
        }.cardStyle()
    }

    private func parseISO8601(_ text: String) -> Date? {
        let withFractions = ISO8601DateFormatter()
        withFractions.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractions.date(from: text) { return date }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: text)
    }

    private func displayJST(_ text: String) -> String {
        if text.count == 19 && text.contains("/") { return text }
        return jstTime(text)
    }

    private func orderReason(_ analysis: Analysis, direction: String?) -> String {
        // EXP-006/007の注文時記録は生の価格を優先。丸められた変動幅だけで成立判定しない。
        if let close = analysis.close, let five = analysis.price5min, let fifteen = analysis.price15sec {
            let condition = close < five && close > fifteen ? "成立" : "不成立"
            return String(
                format: "5分/15秒戦略｜5分 %+.3f円 / 15秒 %+.3f円｜HIGH価格条件 %@",
                close - five, close - fifteen, condition
            )
        }
        // 一部の注文履歴に差分のみが残っている場合は、条件を断定しない。
        if let fiveChange = analysis.change5min, let fifteenChange = analysis.change15sec {
            return String(format: "5分 %+.3f円 / 15秒 %+.3f円｜判定条件の詳細は未確認", fiveChange, fifteenChange)
        }
        // 旧戦略の履歴は既存のEMA/RSI説明を維持する。
        guard let short = analysis.ema9, let long = analysis.ema21, let rsi = analysis.rsi14 else {
            return "注文理由：分析値なし"
        }
        let trend = short > long ? "上昇傾向" : (short < long ? "下落傾向" : "横ばい")
        let strategy: String
        if direction == "LOW" && short > long && rsi > 50 && rsi < 70 {
            strategy = "逆張りLOW条件成立"
        } else if direction == "HIGH" && short < long && rsi > 30 && rsi < 50 {
            strategy = "逆張りHIGH条件成立"
        } else {
            strategy = "当時の戦略条件は未確認"
        }
        return String(format: "%@・%@｜EMA9 %.5f / EMA21 %.5f / RSI %.2f", trend, strategy, short, long, rsi)
    }

    private func jstTime(_ text: String) -> String {
        guard let date = parseISO8601(text) else { return text }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60)
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近の決済履歴（EXP-007）").font(.headline)
            if let trades = client.dashboard?.recentTrades, !trades.isEmpty {
                ForEach(trades) { trade in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trade.contract ?? "契約不明").font(.caption).lineLimit(2)
                            Text("ID: \(trade.tradeId ?? "—")")
                                .font(.caption2).foregroundStyle(Theme.muted)
                        }
                        Spacer(minLength: 8)
                        Text(yen(trade.profit)).font(.subheadline.bold())
                            .foregroundStyle((trade.profit ?? 0) < 0 ? .orange : Theme.cyan)
                    }
                    Divider().overlay(Theme.muted.opacity(0.2))
                }
            } else {
                Text("表示できる決済履歴はありません")
                    .font(.subheadline).foregroundStyle(Theme.muted)
            }
        }.cardStyle()
    }

    private var settingsView: some View {
        NavigationStack {
            Form {
                Section("安全な接続先") {
                    TextField("https://your-private-endpoint.example", text: $client.endpoint)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .keyboardType(.URL)
                    SecureField("APIトークン", text: $client.token)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section {
                    Text("HTTPS接続のみ許可します。Oracle VMの127.0.0.1にはiPhoneから直接接続できません。認証付きのHTTPS通信経路を別途構築してください。")
                        .font(.footnote)
                }
                Section {
                    Button("保存して接続確認") {
                        client.saveSettings()
                        showSettings = false
                        Task { await client.refresh() }
                    }
                }
            }
            .navigationTitle("接続設定")
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button("閉じる") { showSettings = false }
            }}
        }
    }

    private func yen(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.currency(code: "JPY").precision(.fractionLength(0)))
    }
    private func number(_ value: Double?, _ digits: Int) -> String {
        guard let value else { return "—" }
        return String(format: "%.*f", digits, value)
    }
    private func priceChange(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%+.3f円", value)
    }
    private func highConditionText(_ analysis: Analysis?) -> String {
        guard let matched = analysis?.highPriceConditionMet else { return "判定不可" }
        return matched ? "成立" : "不成立"
    }
}

private extension View {
    func cardStyle() -> some View {
        self.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }
}
