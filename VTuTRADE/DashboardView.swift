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
    @State private var selectedExperiment = "EXP-006"
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
                        metric("EXP-006 累計損益", yen(client.dashboard?.totalProfit), "yensign.circle")
                        metric("EXP-006 勝率", String(format: "%.1f%%", client.dashboard?.winRate ?? 0), "chart.bar")
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
            .onChange(of: client.history?.experiments.map(\.experimentId) ?? []) { _, ids in
                // 初回にEXP-006が無い場合も、実在する実験を表示する。
                if !ids.contains(selectedExperiment), let first = ids.first {
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
