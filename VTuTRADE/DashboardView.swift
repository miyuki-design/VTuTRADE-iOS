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
            Button {
                confirmPause = true
            } label: {
                Label("新規注文を一時停止", systemImage: "pause.fill")
                    .frame(maxWidth: .infinity).padding(12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(client.dashboard?.paused != false)
            Text("再開操作は安全性の検証が完了するまで無効です。")
                .font(.caption).foregroundStyle(Theme.muted)
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
                Text("足の確定時刻 (UTC)：\(t)").font(.caption2).foregroundStyle(Theme.muted)
            }
        }.cardStyle()
    }

    private func valueColumn(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(Theme.muted)
            Text(value).font(.system(.body, design: .monospaced).bold())
        }.frame(maxWidth: .infinity, alignment: .leading)
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
