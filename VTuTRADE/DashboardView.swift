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
    @State private var selectedExperiment = "EXP-003"
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
                        metric("記録済み累計損益", yen(client.dashboard?.totalProfit), "yensign.circle")
                        metric("勝率", String(format: "%.1f%%", client.dashboard?.winRate ?? 0), "chart.bar")
                    }
                    analysisCard
                    experimentHistoryCard
                    historyCard
                    if let error = client.error {
                        Text(error).font(.footnote).foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text("※ 決済履歴ファイルに記録された取引のみを集計。未記録の取引がある場合、実際の損益と異なる可能性があります。")
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
            Text("注文記録：\(client.dashboard?.orders ?? 0)件  ／  決済記録：\(client.dashboard?.totalTrades ?? 0)件")
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
                Text("テクニカル分析").font(.headline)
                Spacer()
                Text(client.dashboard?.signal ?? "—")
                    .font(.subheadline.bold()).foregroundStyle(Theme.cyan)
            }
            HStack {
                valueColumn("USD/JPY", number(client.dashboard?.analysis?.close, 3))
                valueColumn("RSI14", number(client.dashboard?.analysis?.rsi14, 2))
            }
            Divider().overlay(Theme.muted.opacity(0.3))
            HStack {
                valueColumn("EMA9", number(client.dashboard?.analysis?.ema9, 5))
                valueColumn("EMA21", number(client.dashboard?.analysis?.ema21, 5))
            }
            if let t = client.dashboard?.analysis?.time {
                Text("足の確定時刻（日本時間）：\(candleCloseJST(t))")
                    .font(.caption2).foregroundStyle(Theme.muted)
            }
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
                                    if let timestamp = trade.timestamp {
                                        Text(jstTime(timestamp))
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

    private func jstTime(_ text: String) -> String {
        guard let date = parseISO8601(text) else { return text }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(secondsFromGMT: 9)
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter.string(from: date)
    }

    // analysis.time は確定した1分足の開始時刻（UTC）。60秒後が確定時刻。
    private func candleCloseJST(_ text: String) -> String {
        guard let start = parseISO8601(text) else { return "取得できません（\(text)）" }
        let close = start.addingTimeInterval(60)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(secondsFromGMT: 9)
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter.string(from: close)
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近の決済履歴").font(.headline)
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
}

private extension View {
    func cardStyle() -> some View {
        self.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }
}
