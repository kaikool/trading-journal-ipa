import Foundation

// MARK: - Standard 27: Concise & Dual-Language Alert Message Builder
/// Formats institutional notifications with minimal words, direct punchy insights,
/// structured line breaks, and dual English/Vietnamese language support
/// synced directly with the user's AI response language setting.
public enum NotificationMessageBuilder {
    
    // MARK: - Language Resolution
    
    @MainActor
    public static var isVietnameseActive: Bool {
        let lang = TradeDataStore.shared.aiSettings.language
        return lang == "vi"
    }
    
    // MARK: - 1. POC & Candlestick Pattern Alerts (Any Timeframe)
    
    public static func buildPocReactionAlert(
        symbol: String,
        timeframe: String,
        levelName: String,
        price: Decimal,
        pattern: CandlePatternType?,
        isVi: Bool
    ) -> (title: String, subtitle: String, body: String) {
        let cleanSymbol = symbol.uppercased()
        let cleanTf = timeframe.uppercased()
        let formattedPrice = Formatters.price(price, symbol: cleanSymbol)
        
        let patternName = pattern?.displayName ?? "POC Touch"
        let viPattern = vietnamesePatternName(for: pattern)
        let viLevel = vietnameseLevelName(for: levelName)
        
        if isVi {
            let title = "[PHẢN ỨNG POC - \(cleanSymbol)]"
            let subtitle = "\(viPattern) • \(viLevel) (\(cleanTf))"
            let action = vietnameseActionGuidance(pattern: pattern)
            let body = """
            Mốc: \(viLevel) (\(formattedPrice))
            Mẫu nến: \(viPattern)
            Hành động: \(action)
            """
            return (title, subtitle, body)
        } else {
            let title = "[POC REACTION - \(cleanSymbol)]"
            let subtitle = "\(patternName) • \(levelName) (\(cleanTf))"
            let action = englishActionGuidance(pattern: pattern)
            let body = """
            Level: \(levelName) (\(formattedPrice))
            Pattern: \(patternName)
            Action: \(action)
            """
            return (title, subtitle, body)
        }
    }
    
    // MARK: - 2. Economic News Radar (Forex Factory)
    
    public static func buildNewsAlert(
        currency: String,
        eventTitle: String,
        minutesRemaining: Int,
        timeString: String,
        isVi: Bool
    ) -> (title: String, subtitle: String, body: String) {
        let curr = currency.uppercased()
        
        if isVi {
            let title = "[TIN TỨC ĐỎ - \(curr)]"
            let subtitle = "\(eventTitle) trong \(minutesRemaining) phút"
            let body = """
            Sự kiện: \(eventTitle)
            Thời gian: \(timeString) (còn \(minutesRemaining)m)
            Biến động: Rất mạnh (High Impact)
            Hành động: Kiểm tra vị thế & dời Stop Loss
            """
            return (title, subtitle, body)
        } else {
            let title = "[NEWS RADAR - \(curr)]"
            let subtitle = "\(eventTitle) in \(minutesRemaining)m"
            let body = """
            Event: \(eventTitle)
            Release: \(timeString) (\(minutesRemaining)m remaining)
            Impact: High Volatility
            Action: Check open exposure & trailing stops
            """
            return (title, subtitle, body)
        }
    }
    
    // MARK: - 3. Discipline & Revenge Trading Warnings (Tilt)
    
    public static func buildTiltWarningAlert(
        lossCount: Int,
        drawdown: Decimal,
        currency: String,
        isVi: Bool
    ) -> (title: String, subtitle: String, body: String) {
        let formattedLoss = Formatters.formatCurrency(drawdown, currency: currency)
        
        if isVi {
            let title = "[CẢNH BÁO TÂM LÝ - TILT]"
            let subtitle = "\(lossCount) lệnh thua liên tiếp trong 60 phút"
            let body = """
            Phát hiện: \(lossCount) lệnh Stop Loss liên tiếp
            Tổng âm: -\(formattedLoss)
            Hành động: Rời khỏi bàn 30 phút. Tuyệt đối không giao dịch trả thù.
            """
            return (title, subtitle, body)
        } else {
            let title = "[DISCIPLINE RADAR - TILT]"
            let subtitle = "\(lossCount) Consecutive Losses in 60m"
            let body = """
            Trigger: \(lossCount) consecutive stopouts within 1 hour
            Loss: -\(formattedLoss)
            Action: Step away for 30 minutes. Do not revenge trade.
            """
            return (title, subtitle, body)
        }
    }
    
    // MARK: - 4. Morning Routine Checklist (08:00)
    
    public static func buildMorningRoutineAlert(isVi: Bool) -> (title: String, subtitle: String, body: String) {
        if isVi {
            let title = "[QUY TRÌNH BUỔI SÁNG - 08:00]"
            let subtitle = "Checklist chuẩn bị phiên giao dịch"
            let body = """
            1. Xem lịch tin tức Forex Factory trong ngày
            2. Xác định giới hạn lỗ tối đa ($500)
            3. Đánh dấu mốc Session POC & Daily POC
            4. Chỉ vào lệnh khi có đủ tín hiệu nến xác nhận
            """
            return (title, subtitle, body)
        } else {
            let title = "[MORNING ROUTINE - 08:00]"
            let subtitle = "Pre-Market Preparation Checklist"
            let body = """
            1. Review high-impact news on Forex Factory
            2. Verify max daily drawdown limit ($500)
            3. Mark Key Session POCs & Daily POCs
            4. Wait for confirmation pattern before entry
            """
            return (title, subtitle, body)
        }
    }
    
    // MARK: - 5. Pre-Session Open Routine (London 13:45 / NY 19:15)
    
    public static func buildSessionOpenAlert(
        sessionName: String,
        timeString: String,
        isVi: Bool
    ) -> (title: String, subtitle: String, body: String) {
        if isVi {
            let title = "[MỞ PHIÊN - \(sessionName.uppercased())]"
            let subtitle = "Thanh khoản mở trong 15 phút (\(timeString))"
            let body = """
            Phiên: \(sessionName) Open lúc \(timeString)
            Trọng tâm: Quan sát biên Initial Balance & dịch chuyển POC
            Hành động: Tránh fomo râu nến quét 5 phút đầu
            """
            return (title, subtitle, body)
        } else {
            let title = "[SESSION OPEN - \(sessionName.uppercased())]"
            let subtitle = "Liquidity opens in 15 minutes (\(timeString))"
            let body = """
            Session: \(sessionName) Open at \(timeString)
            Focus: Observe Initial Balance & POC migration
            Action: Avoid chasing first 5-minute liquidity wicks
            """
            return (title, subtitle, body)
        }
    }
    
    // MARK: - 6. End-of-Day Journal Review (22:30)
    
    public static func buildJournalReviewAlert(
        tradeCount: Int,
        isVi: Bool
    ) -> (title: String, subtitle: String, body: String) {
        if isVi {
            let title = "[NHẬT KÝ CUỐI NGÀY - 22:30]"
            let subtitle = "Tổng kết \(tradeCount) lệnh đã giao dịch hôm nay"
            let body = """
            Hôm nay: \(tradeCount) lệnh đã đóng
            Hành động:
            - Ghi chép cảm xúc và nhật ký lệnh
            - Đánh giá tuân thủ quy tắc và gắn nhãn sai lầm
            - Lưu biểu đồ replay để rút kinh nghiệm
            """
            return (title, subtitle, body)
        } else {
            let title = "[JOURNAL REVIEW - 22:30]"
            let subtitle = "Review \(tradeCount) closed trades from today"
            let body = """
            Today: \(tradeCount) trades closed
            Action:
            - Log emotional state and execution notes
            - Tag discipline mistakes and playbook rules
            - Save chart replay for review
            """
            return (title, subtitle, body)
        }
    }
    
    // MARK: - Internal Pattern & Level Helpers
    
    private static func vietnamesePatternName(for pattern: CandlePatternType?) -> String {
        guard let p = pattern else { return "Chạm mốc POC" }
        switch p {
        case .bullishPinbar: return "Rút râu tăng (Hammer)"
        case .bearishPinbar: return "Rút râu giảm (Shooting Star)"
        case .bullishEngulfing: return "Nến nhấn chìm tăng"
        case .bearishEngulfing: return "Nến nhấn chìm giảm"
        case .marubozuBullish: return "Nến Marubozu tăng lực"
        case .marubozuBearish: return "Nến Marubozu giảm lực"
        case .insideBar: return "Inside Bar tích lũy"
        case .doji: return "Nến Doji nén giá"
        case .morningStar: return "Sao Mai đảo chiều tăng"
        case .eveningStar: return "Sao Hôm đảo chiều giảm"
        case .tweezerBottom: return "Đáy đôi từ chối giá"
        case .tweezerTop: return "Đỉnh đôi từ chối giá"
        case .threeWhiteSoldiers: return "Ba chàng lính trắng tăng"
        case .threeBlackCrows: return "Ba con quạ đen giảm"
        }
    }
    
    private static func vietnameseLevelName(for levelName: String) -> String {
        let clean = levelName.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.contains("Daily POC") { return "Daily POC (D1)" }
        if clean.contains("Weekly POC") { return "Weekly POC (W1)" }
        if clean.contains("Tokyo POC") { return "Tokyo POC" }
        if clean.contains("London POC") { return "London POC" }
        if clean.contains("New York POC") { return "New York POC" }
        if clean.contains("Monthly POC") { return "Monthly POC (MN)" }
        if clean.contains("Naked POC") { return "Naked POC (chưa test)" }
        return clean
    }
    
    private static func vietnameseActionGuidance(pattern: CandlePatternType?) -> String {
        guard let p = pattern else { return "Theo dõi phản ứng giá quanh mốc" }
        if p.isBullish {
            return "Khả năng bật tăng từ hỗ trợ. Chờ xác nhận để Long."
        } else if p.isBearish {
            return "Khả năng bật giảm từ kháng cự. Chờ xác nhận để Short."
        } else {
            return "Giá đang tích lũy nén biên độ. Chờ breakout."
        }
    }
    
    private static func englishActionGuidance(pattern: CandlePatternType?) -> String {
        guard let p = pattern else { return "Monitor reaction around key volume level" }
        if p.isBullish {
            return "Potential bounce from support. Watch for Long setup."
        } else if p.isBearish {
            return "Potential rejection from resistance. Watch for Short setup."
        } else {
            return "Price compressing at volume node. Await breakout."
        }
    }
}
