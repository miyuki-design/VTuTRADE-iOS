import Foundation
import Security

struct Trade: Decodable, Identifiable {
    let tradeId: String?
    let contract: String?
    let profit: Double?
    let result: String?
    let timestamp: String?
    let timestampJst: String?
    let orderTimestampJst: String?
    let orderAnalysis: Analysis?
    let orderDirection: String?
    var id: String { tradeId ?? UUID().uuidString }
    enum CodingKeys: String, CodingKey {
        case tradeId = "trade_id", contract, profit, result, timestamp
        case timestampJst = "timestamp_jst"
        case orderTimestampJst = "order_timestamp_jst"
        case orderAnalysis = "order_analysis"
        case orderDirection = "order_direction"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .tradeId) { tradeId = s }
        else if let n = try? c.decode(Int.self, forKey: .tradeId) { tradeId = String(n) }
        else { tradeId = nil }
        contract = try c.decodeIfPresent(String.self, forKey: .contract)
        profit = try c.decodeIfPresent(Double.self, forKey: .profit)
        result = try c.decodeIfPresent(String.self, forKey: .result)
        timestamp = try c.decodeIfPresent(String.self, forKey: .timestamp)
        timestampJst = try c.decodeIfPresent(String.self, forKey: .timestampJst)
        orderTimestampJst = try c.decodeIfPresent(String.self, forKey: .orderTimestampJst)
        orderAnalysis = try c.decodeIfPresent(Analysis.self, forKey: .orderAnalysis)
        orderDirection = try c.decodeIfPresent(String.self, forKey: .orderDirection)
    }
}
// EXP-006/007共通の価格分析データと、過去実験のEMA/RSIデータを復号する。
// 未提供の項目はnilのままにし、古い履歴も読み込めるようにする。
struct Analysis: Decodable {
    let time: String?
    let close: Double?
    let price15sec: Double?
    let price5min: Double?
    let change15sec: Double?
    let change5min: Double?
    let strategy: String?

    // 旧実験の履歴表示に必要なので残す。
    let ema9: Double?
    let ema21: Double?
    let rsi14: Double?

    enum CodingKeys: String, CodingKey {
        case time, close, strategy, ema9, ema21, rsi14
        case price15sec = "price_15sec"
        case price5min = "price_5min"
        case change15sec = "change_15sec"
        case change5min = "change_5min"
    }

    // EXP-006/007共通のHIGH価格条件: 5分では下落、直近15秒では上昇。
    // 実際の注文には時間・安全制御など、別の条件も必要。
    var highPriceConditionMet: Bool? {
        guard let close, let price15sec, let price5min else { return nil }
        return close < price5min && close > price15sec
    }
}
struct ExperimentHistory: Decodable {
    let environment: String
    let experiments: [ExperimentSummary]
}

struct ExperimentSummary: Decodable, Identifiable {
    let experimentId: String
    let name: String
    let totalTrades: Int
    let wins: Int
    let losses: Int
    let winRate: Double
    let totalProfit: Double
    let averageProfit: Double
    let firstTradeJst: String?
    let lastTradeJst: String?
    let recentTrades: [Trade]
    var id: String { experimentId }
    enum CodingKeys: String, CodingKey {
        case name, wins, losses
        case experimentId = "experiment_id"
        case totalTrades = "total_trades"
        case winRate = "win_rate"
        case totalProfit = "total_profit"
        case averageProfit = "average_profit"
        case firstTradeJst = "first_trade_jst"
        case lastTradeJst = "last_trade_jst"
        case recentTrades = "recent_trades"
    }
}

struct Dashboard: Decodable {
    let environment: String
    let paused: Bool
    let canResume: Bool?
    let engineStatus: String?
    let orders: Int?
    let totalProfit: Double
    let totalTrades: Int
    let wins: Int
    let winRate: Double
    let signal: String?
    let analysis: Analysis?
    let recentTrades: [Trade]
    enum CodingKeys: String, CodingKey {
        case environment, paused, orders, wins, signal, analysis
        case canResume = "can_resume"
        case engineStatus = "engine_status", totalProfit = "total_profit"
        case totalTrades = "total_trades", winRate = "win_rate", recentTrades = "recent_trades"
    }
}

enum SecureToken {
    private static let service = "VTuTRADE.API"
    private static let account = "accessToken"
    static func read() -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrService as String: service,
                                     kSecAttrAccount as String: account,
                                     kSecReturnData as String: true,
                                     kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else { return "" }
        return value
    }
    static func save(_ value: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrService as String: service,
                                     kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
        guard let data = value.data(using: .utf8) else { return }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }
}

@MainActor
final class TradeClient: ObservableObject {
    @Published var dashboard: Dashboard?
    @Published var history: ExperimentHistory?
    @Published var historyError: String?
    @Published var error: String?
    @Published var loading = false
    @Published var controlBusy = false
    @Published var endpoint = UserDefaults.standard.string(forKey: "endpoint") ?? ""
    @Published var token = SecureToken.read()
    @Published var lastUpdated: Date?

    func saveSettings() {
        endpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(endpoint, forKey: "endpoint")
        SecureToken.save(token)
    }
    private func request(_ path: String, method: String = "GET") async throws -> Data {
        guard let root = URL(string: endpoint), root.scheme == "https",
              root.host != nil, root.user == nil, root.password == nil,
              root.query == nil, root.fragment == nil,
              !token.isEmpty else { throw APIError.invalidSettings }
        let url = root.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 12
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw APIError.http(http.statusCode) }
        return data
    }
    func refresh() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let data = try await request("status")
            let model = try JSONDecoder().decode(Dashboard.self, from: data)
            guard model.environment == "DEMO" else { throw APIError.notDemo }
            dashboard = model
            lastUpdated = Date()
            error = nil
            do {
                let historyData = try await request("history")
                let historyModel = try JSONDecoder().decode(ExperimentHistory.self, from: historyData)
                guard historyModel.environment == "DEMO" else { throw APIError.notDemo }
                history = historyModel
                historyError = nil
            } catch {
                historyError = "実験別戦歴の取得に失敗：\(error.localizedDescription)"
            }
        } catch { self.error = error.localizedDescription }
    }
    func pause() async {
        guard dashboard?.paused == false, !controlBusy else { return }
        controlBusy = true
        defer { controlBusy = false }
        do {
            _ = try await request("pause", method: "POST")
            await refresh()
        } catch { self.error = error.localizedDescription }
    }
    func resume() async {
        guard dashboard?.paused == true,
              dashboard?.canResume == true,
              !controlBusy else { return }
        controlBusy = true
        defer { controlBusy = false }
        do {
            _ = try await request("resume", method: "POST")
            await refresh()
        } catch {
            self.error = "再開できませんでした：\(error.localizedDescription)"
            await refresh()
        }
    }
}

enum APIError: LocalizedError {
    case invalidSettings, invalidResponse, notDemo, http(Int)
    var errorDescription: String? {
        switch self {
        case .invalidSettings: return "HTTPS接続先とAPIトークンを設定してください。"
        case .invalidResponse: return "サーバーの応答を確認できません。"
        case .notDemo: return "デモ環境以外には接続しません。"
        case .http(let status): return "APIエラー（HTTP \(status)）"
        }
    }
}
