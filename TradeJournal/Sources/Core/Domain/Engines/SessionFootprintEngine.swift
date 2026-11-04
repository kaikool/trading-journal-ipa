import Foundation

// MARK: - Session Footprint & Volume Profile Engine
/// Mathematical engine for calculating session-sliced Footprint Volume Profiles,
/// Point of Control (POC), 70% Value Area (VAH / VAL), and Naked POC mitigation tracking.
/// Configured strictly to GMT+7 (Bangkok/Hanoi/Jakarta) aligned with Asian, European, and US market sessions.
public enum SessionFootprintEngine {

    // Native IANA Time Zones for exact market hours with automatic DST (Daylight Saving Time) handling
    public static let tokyoTimeZone: TimeZone = TimeZone(identifier: "Asia/Tokyo") ?? TimeZone(secondsFromGMT: 9 * 3600) ?? .current
    public static let londonTimeZone: TimeZone = TimeZone(identifier: "Europe/London") ?? TimeZone(secondsFromGMT: 0) ?? .current
    public static let newYorkTimeZone: TimeZone = TimeZone(identifier: "America/New_York") ?? TimeZone(secondsFromGMT: -5 * 3600) ?? .current
    public static let calendarTimeZone: TimeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? TimeZone(secondsFromGMT: 7 * 3600) ?? .current
    public static let sessionTimeZone: TimeZone = calendarTimeZone

    // MARK: - 1. Tick Row Size Calculation across ALL Currency Pairs & Asset Classes
    public static func defaultRowSize(for symbol: String, samplePrice: Decimal? = nil) -> Decimal {
        let clean = symbol.uppercased().replacingOccurrences(of: "/", with: "").replacingOccurrences(of: "_", with: "")

        // 1. Precious Metals & Commodities
        if clean.contains("XAU") || clean.contains("GOLD") {
            return Decimal(1.0) // $1.00 per bin (100 ticks of 0.01)
        } else if clean.contains("XAG") || clean.contains("SILVER") {
            return Decimal(string: "0.02") ?? Decimal(0.02) // $0.02 per bin
        } else if clean.contains("USOIL") || clean.contains("UKOIL") || clean.contains("WTI") || clean.contains("BRENT") || clean.contains("OIL") {
            return Decimal(string: "0.10") ?? Decimal(0.10) // $0.10 per bin
        }

        // 2. Major Equity Indices
        if clean.contains("US30") || clean.contains("DJ30") || clean.contains("WS30") || clean.contains("DJI") {
            return Decimal(10.0) // 10 points
        } else if clean.contains("NAS100") || clean.contains("USTEC") || clean.contains("US100") || clean.contains("NDX") {
            return Decimal(5.0) // 5 points
        } else if clean.contains("SPX500") || clean.contains("US500") || clean.contains("SPX") {
            return Decimal(1.0) // 1 point
        } else if clean.contains("GER40") || clean.contains("DE30") || clean.contains("DE40") || clean.contains("DAX") {
            return Decimal(5.0) // 5 points
        } else if clean.contains("UK100") || clean.contains("FTSE") {
            return Decimal(2.0)
        } else if clean.contains("JP225") || clean.contains("NKY") {
            return Decimal(10.0)
        }

        // 3. Crypto Currencies
        if clean.contains("BTC") {
            return Decimal(25.0) // $25.00
        } else if clean.contains("ETH") {
            return Decimal(2.0) // $2.00
        } else if clean.contains("SOL") {
            return Decimal(string: "0.20") ?? Decimal(0.20)
        }

        // 4. Forex JPY Pairs (USD/JPY, EUR/JPY, GBP/JPY, AUD/JPY, CAD/JPY, CHF/JPY, NZD/JPY)
        if clean.contains("JPY") {
            return Decimal(string: "0.01") ?? Decimal(0.01) // 1 pip (10 fractional ticks)
        }

        // 5. Forex Standard 5-digit Pairs (EUR/USD, GBP/USD, AUD/USD, NZD/USD, USD/CAD, USD/CHF, crosses)
        let isStandardForex = clean.count >= 6 && (
            clean.contains("USD") || clean.contains("EUR") || clean.contains("GBP") ||
            clean.contains("AUD") || clean.contains("NZD") || clean.contains("CAD") ||
            clean.contains("CHF")
        )
        if isStandardForex {
            return Decimal(string: "0.0001") ?? Decimal(0.0001) // 1 pip (10 fractional ticks)
        }

        // 6. Dynamic Fallback based on Price Magnitude if symbol is unknown/exotic
        if let price = samplePrice, price > 0 {
            if price > Decimal(10000) {
                return Decimal(10.0)
            } else if price > Decimal(1000) {
                return Decimal(1.0)
            } else if price > Decimal(50) {
                return Decimal(string: "0.05") ?? Decimal(0.05)
            } else if price > Decimal(5) {
                return Decimal(string: "0.01") ?? Decimal(0.01)
            } else {
                return Decimal(string: "0.0001") ?? Decimal(0.0001)
            }
        }

        return Decimal(string: "0.0001") ?? Decimal(0.0001)
    }

    // MARK: - 2. Session Time Intervals Aligned to Native IANA Time Zones
    /// Tokyo (Asia): 09:00 - 18:00 Asia/Tokyo
    /// London (Europe): 08:00 - 17:00 Europe/London (DST automatically handled)
    /// New York (US): 08:00 - 17:00 America/New_York (DST automatically handled)
    /// Daily: Complete Asia-to-US institutional cycle (Tokyo Open 09:00 Tokyo to NY Close 17:00 NY)
    /// Weekly: Monday Tokyo Open (09:00 Tokyo) to Friday New York Close (17:00 NY)
    public static func sessionInterval(
        for session: FootprintSessionType,
        on date: Date
    ) -> (start: Date, end: Date)? {
        switch session {
        case .tokyo:
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = tokyoTimeZone
            let comps = cal.dateComponents([.year, .month, .day], from: date)
            guard let dayStart = cal.date(from: comps),
                  let s = cal.date(bySettingHour: 9, minute: 0, second: 0, of: dayStart),
                  let e = cal.date(bySettingHour: 18, minute: 0, second: 0, of: dayStart) else { return nil }
            return (s, e)

        case .london:
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = londonTimeZone
            let comps = cal.dateComponents([.year, .month, .day], from: date)
            guard let dayStart = cal.date(from: comps),
                  let s = cal.date(bySettingHour: 8, minute: 0, second: 0, of: dayStart),
                  let e = cal.date(bySettingHour: 17, minute: 0, second: 0, of: dayStart) else { return nil }
            return (s, e)

        case .newYork:
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = newYorkTimeZone
            let comps = cal.dateComponents([.year, .month, .day], from: date)
            guard let dayStart = cal.date(from: comps),
                  let s = cal.date(bySettingHour: 8, minute: 0, second: 0, of: dayStart),
                  let e = cal.date(bySettingHour: 17, minute: 0, second: 0, of: dayStart) else { return nil }
            return (s, e)

        case .daily:
            var tokyoCal = Calendar(identifier: .gregorian)
            tokyoCal.timeZone = tokyoTimeZone
            let tComps = tokyoCal.dateComponents([.year, .month, .day], from: date)
            guard let tDayStart = tokyoCal.date(from: tComps),
                  let proposedS = tokyoCal.date(bySettingHour: 9, minute: 0, second: 0, of: tDayStart) else { return nil }
            let cycleDateComps: DateComponents
            if date < proposedS, let priorDay = tokyoCal.date(byAdding: .day, value: -1, to: tDayStart) {
                cycleDateComps = tokyoCal.dateComponents([.year, .month, .day], from: priorDay)
            } else {
                cycleDateComps = tComps
            }
            guard let cycleDayStart = tokyoCal.date(from: cycleDateComps),
                  let s = tokyoCal.date(bySettingHour: 9, minute: 0, second: 0, of: cycleDayStart) else { return nil }

            var nyCal = Calendar(identifier: .gregorian)
            nyCal.timeZone = newYorkTimeZone
            var nyComps = DateComponents()
            nyComps.year = cycleDateComps.year
            nyComps.month = cycleDateComps.month
            nyComps.day = cycleDateComps.day
            nyComps.hour = 17
            nyComps.minute = 0
            nyComps.second = 0
            guard let e = nyCal.date(from: nyComps) else { return nil }
            return (s, e)

        case .weekly:
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = calendarTimeZone
            var comp = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            comp.weekday = 2 // Monday
            guard let monday = cal.date(from: comp) else { return nil }

            var tokyoCal = Calendar(identifier: .gregorian)
            tokyoCal.timeZone = tokyoTimeZone
            let tComps = tokyoCal.dateComponents([.year, .month, .day], from: monday)
            guard let tDayStart = tokyoCal.date(from: tComps),
                  let s = tokyoCal.date(bySettingHour: 9, minute: 0, second: 0, of: tDayStart) else { return nil }

            comp.weekday = 6 // Friday
            guard let friday = cal.date(from: comp) else { return nil }
            var nyCal = Calendar(identifier: .gregorian)
            nyCal.timeZone = newYorkTimeZone
            let nyComps = nyCal.dateComponents([.year, .month, .day], from: friday)
            var nyEndComps = DateComponents()
            nyEndComps.year = nyComps.year
            nyEndComps.month = nyComps.month
            nyEndComps.day = nyComps.day
            nyEndComps.hour = 17
            nyEndComps.minute = 0
            nyEndComps.second = 0
            guard let e = nyCal.date(from: nyEndComps) else { return nil }
            return (s, e)

        case .monthly:
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = calendarTimeZone
            let comp = cal.dateComponents([.year, .month], from: date)
            guard let startOfMonth = cal.date(from: comp),
                  let endOfMonth = cal.date(byAdding: .month, value: 1, to: startOfMonth) else { return nil }
            return (startOfMonth, endOfMonth)
        }
    }

    public static func sessionDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = sessionTimeZone
        return formatter.string(from: date)
    }

    // MARK: - 3. Volume Binning & Profile Calculation
    /// Accumulates tick volume into discrete price bins of size `rowSize`
    /// and extracts POC, VAH, and VAL at 70% value area threshold.
    public static func computeProfile(
        bars: [MarketBar],
        symbol: String,
        sessionType: FootprintSessionType,
        sessionDate: String,
        startTime: Date,
        endTime: Date,
        rowSize: Decimal? = nil
    ) -> SessionProfileSnapshot? {
        guard !bars.isEmpty else { return nil }

        let step = rowSize ?? defaultRowSize(for: symbol, samplePrice: bars.first?.close)
        let stepDouble = NSDecimalNumber(decimal: step).doubleValue
        guard stepDouble > 0 else { return nil }

        var binsMap: [Int: Decimal] = [:]
        var totalVolume: Decimal = .zero
        var minBarLow: Decimal = bars[0].low
        var maxBarHigh: Decimal = bars[0].high

        for bar in bars {
            minBarLow = min(minBarLow, bar.low)
            maxBarHigh = max(maxBarHigh, bar.high)
            totalVolume += bar.volume

            let lowD = NSDecimalNumber(decimal: bar.low).doubleValue
            let highD = NSDecimalNumber(decimal: bar.high).doubleValue

            let startKey = Int(floor(lowD / stepDouble))
            let endKey = max(startKey, Int(floor(highD / stepDouble)))
            let spanCount = endKey - startKey + 1

            let volPerBin = bar.volume / Decimal(max(1, spanCount))
            for k in startKey...endKey {
                binsMap[k, default: .zero] += volPerBin
            }
        }

        guard !binsMap.isEmpty, totalVolume > .zero else { return nil }

        let sortedKeys = binsMap.keys.sorted()
        guard let minKey = sortedKeys.first, let maxKey = sortedKeys.last else { return nil }
        let profileMidKey = Double(minKey + maxKey) / 2.0

        // Find Point of Control (POC) with maximum volume
        var maxV: Decimal = .zero
        var pocKey: Int = minKey
        var bestDist: Double = Double.greatestFiniteMagnitude

        for k in sortedKeys {
            let v = binsMap[k] ?? .zero
            if v > maxV {
                maxV = v
                pocKey = k
                bestDist = abs(Double(k) - profileMidKey)
            } else if v == maxV && v > .zero {
                let candidateDist = abs(Double(k) - profileMidKey)
                if candidateDist < bestDist || (candidateDist == bestDist && k > pocKey) {
                    pocKey = k
                    bestDist = candidateDist
                }
            }
        }

        // Value Area Expansion (70% Target)
        guard let pocIndex = sortedKeys.firstIndex(of: pocKey) else { return nil }
        let targetVolume = totalVolume * Decimal(0.70)
        var accumulatedVolume: Decimal = binsMap[pocKey] ?? .zero

        var valKey = pocKey
        var vahKey = pocKey
        var belowIdx = pocIndex - 1
        var aboveIdx = pocIndex + 1
        let n = sortedKeys.count

        while accumulatedVolume < targetVolume {
            let hasBelow = belowIdx >= 0
            let hasAbove = aboveIdx < n
            if !hasBelow && !hasAbove { break }

            let belowKey = hasBelow ? sortedKeys[belowIdx] : nil
            let aboveKey = hasAbove ? sortedKeys[aboveIdx] : nil
            let belowV = belowKey != nil ? (binsMap[belowKey!] ?? .zero) : Decimal(-1)
            let aboveV = aboveKey != nil ? (binsMap[aboveKey!] ?? .zero) : Decimal(-1)

            let chooseAbove: Bool
            if hasAbove && !hasBelow {
                chooseAbove = true
            } else if hasBelow && !hasAbove {
                chooseAbove = false
            } else if aboveV > belowV {
                chooseAbove = true
            } else if belowV > aboveV {
                chooseAbove = false
            } else {
                let aboveDist = abs((aboveKey ?? pocKey) - pocKey)
                let belowDist = abs(pocKey - (belowKey ?? pocKey))
                chooseAbove = aboveDist <= belowDist
            }

            let chosenIdx = chooseAbove ? aboveIdx : belowIdx
            guard chosenIdx >= 0 && chosenIdx < n else { break }
            let chosenKey = sortedKeys[chosenIdx]
            let chosenV = binsMap[chosenKey] ?? .zero

            accumulatedVolume += max(chosenV, .zero)
            if chooseAbove {
                vahKey = chosenKey
                aboveIdx += 1
            } else {
                valKey = chosenKey
                belowIdx -= 1
            }
        }

        let pocPrice = Decimal(pocKey) * step + (step / Decimal(2))
        let valPrice = Decimal(valKey) * step
        let vahPrice = Decimal(vahKey) * step + step
        let profileHigh = Decimal(maxKey) * step + step
        let profileLow = Decimal(minKey) * step

        return SessionProfileSnapshot(
            symbol: symbol,
            sessionType: sessionType,
            sessionDate: sessionDate,
            startTime: startTime,
            endTime: endTime,
            pocPrice: pocPrice,
            vahPrice: vahPrice,
            valPrice: valPrice,
            profileHigh: profileHigh,
            profileLow: profileLow,
            totalVolume: totalVolume,
            isNaked: true,
            mitigatedAt: nil
        )
    }

    // MARK: - 4. Naked POC Mitigation Tracking
    /// Checks past unmitigated snapshots against subsequent price action bars.
    /// If any subsequent bar's range [low, high] spans the snapshot POC, it is marked mitigated.
    public static func updateMitigations(
        snapshots: inout [SessionProfileSnapshot],
        subsequentBars: [MarketBar]
    ) {
        guard !snapshots.isEmpty && !subsequentBars.isEmpty else { return }

        for i in snapshots.indices {
            guard snapshots[i].isNaked else { continue }
            let snapPoc = snapshots[i].pocPrice
            let snapEndTimeMs = Int64(snapshots[i].endTime.timeIntervalSince1970 * 1000.0)

            for bar in subsequentBars where bar.timestamp >= snapEndTimeMs {
                if bar.high >= snapPoc && bar.low <= snapPoc {
                    snapshots[i].isNaked = false
                    snapshots[i].mitigatedAt = bar.date
                    break
                }
            }
        }
    }

    // MARK: - 5. Value Migration / Order Flow Direction
    /// Assesses whether value areas are shifting upward (Bullish), downward (Bearish), or compressing.
    public static func evaluateValueMigration(
        currentPoc: Decimal?,
        previousPoc: Decimal?,
        currentClose: Decimal?
    ) -> String {
        guard let curPoc = currentPoc, let prevPoc = previousPoc else { return "NEUTRAL" }
        if curPoc > prevPoc {
            if let close = currentClose, close > curPoc {
                return "BULLISH EXPANSION"
            }
            return "BULLISH BIAS"
        } else if curPoc < prevPoc {
            if let close = currentClose, close < curPoc {
                return "BEARISH EXPANSION"
            }
            return "BEARISH BIAS"
        } else {
            return "CONSOLIDATION / BALANCED"
        }
    }

    // MARK: - 6. Extract Unified Key Levels
    /// Produces a clean, sorted collection of KeyLevel items for UI rendering and AI prompt injection.
    public static func extractKeyLevels(
        snapshots: [SessionProfileSnapshot],
        developingPoc: Decimal? = nil,
        developingSession: FootprintSessionType? = nil,
        previousDayHigh: Decimal? = nil,
        previousDayLow: Decimal? = nil
    ) -> [KeyLevel] {
        var levels: [KeyLevel] = []

        // 1. Previous Day High & Low
        if let pdh = previousDayHigh, pdh > .zero {
            levels.append(KeyLevel(type: .pdh, price: pdh, label: "PDH"))
        }
        if let pdl = previousDayLow, pdl > .zero {
            levels.append(KeyLevel(type: .pdl, price: pdl, label: "PDL"))
        }

        // 2. Developing Live POC
        if let devPoc = developingPoc, let devSess = developingSession {
            levels.append(KeyLevel(
                type: .sessionPoc(devSess),
                price: devPoc,
                label: "Live \(devSess.shortCode) POC"
            ))
        }

        // 3. Completed Session Profiles (4 Independent Retention Buckets)
        // sessionSnapshots: 3 most recent sessions (1 Tokyo, 1 London, 1 New York)
        // dailySnapshots: 10 most recent days
        // weeklySnapshots: 3 most recent weeks
        // higherSnapshots: None (No M/Q/Y)
        var ageMap: [FootprintSessionType: Int] = [:]
        for snap in snapshots.sorted(by: { $0.endTime > $1.endTime }) {
            guard snap.sessionType != .monthly else { continue }
            let age = ageMap[snap.sessionType, default: 0] + 1
            ageMap[snap.sessionType] = age

            let maxKeep: Int = {
                switch snap.sessionType {
                case .daily: return 10
                case .weekly: return 3
                case .tokyo, .london, .newYork: return 1
                case .monthly: return 0
                }
            }()
            guard age <= maxKeep else { continue }

            // Age 1 is the immediate prior staircase step
            if age == 1 {
                let priorLabel = snap.isNaked
                    ? "Prior \(snap.sessionType.shortCode) POC [NPOC]"
                    : "Prior \(snap.sessionType.shortCode) POC"
                levels.append(KeyLevel(
                    type: .sessionPoc(snap.sessionType),
                    price: snap.pocPrice,
                    label: priorLabel,
                    isNaked: snap.isNaked
                ))
            } else if snap.isNaked {
                // Older untested levels act as magnetic liquidity rays
                levels.append(KeyLevel(
                    type: .nakedPoc(snap.sessionType, age: age),
                    price: snap.pocPrice,
                    label: "NPOC [\(snap.sessionType.shortCode)-\(age)]",
                    isNaked: true
                ))
            } else if age <= 3 {
                // Keep recent tested historical staircase steps
                levels.append(KeyLevel(
                    type: .sessionPoc(snap.sessionType),
                    price: snap.pocPrice,
                    label: "\(snap.sessionType.shortCode)-\(age) POC"
                ))
            }
        }

        return levels
    }

    // MARK: - 7. Staircase Step Comparison (Bậc thang POC)
    public struct StaircaseStep: Sendable, Equatable {
        public let sessionType: FootprintSessionType
        public let currentPoc: Decimal?
        public let priorPoc: Decimal?
        public let stepDirection: String
    }

    public static func compareStaircaseSteps(
        snapshots: [SessionProfileSnapshot],
        developingPoc: Decimal? = nil,
        developingSession: FootprintSessionType? = nil
    ) -> [FootprintSessionType: StaircaseStep] {
        var result: [FootprintSessionType: StaircaseStep] = [:]

        for sType in FootprintSessionType.allCases {
            let sortedSnaps = snapshots.filter { $0.sessionType == sType }.sorted(by: { $0.endTime > $1.endTime })
            let priorPoc = sortedSnaps.first?.pocPrice
            let curPoc = (developingSession == sType) ? developingPoc : nil

            let dir: String
            if let cur = curPoc, let prior = priorPoc {
                if cur > prior {
                    dir = "HIGHER STEP (\(cur) > \(prior))"
                } else if cur < prior {
                    dir = "LOWER STEP (\(cur) < \(prior))"
                } else {
                    dir = "FLAT STEP (\(cur) == \(prior))"
                }
            } else if let prior = priorPoc {
                dir = "PRIOR LOCKED AT \(prior)"
            } else {
                dir = "NO_DATA"
            }

            result[sType] = StaircaseStep(
                sessionType: sType,
                currentPoc: curPoc,
                priorPoc: priorPoc,
                stepDirection: dir
            )
        }

        return result
    }

    // MARK: - 8. Bar-by-Bar Developing Staircase POC Steps
    private static let staircaseCacheLock = NSLock()
    private static var staircaseCache: [String: [(timestamp: Int64, pocPrice: Decimal)]] = [:]

    /// Computes the progressive POC step line as volume accumulates throughout a session.
    public static func computeStaircaseSteps(
        bars: [MarketBar],
        symbol: String,
        rowSize: Decimal? = nil
    ) -> [(timestamp: Int64, pocPrice: Decimal)] {
        guard !bars.isEmpty else { return [] }
        let cacheKey = "\(symbol)_\(bars.count)_\(bars.first?.timestamp ?? 0)_\(bars.last?.timestamp ?? 0)_\(bars.last?.close ?? 0)"
        staircaseCacheLock.lock()
        if let cached = staircaseCache[cacheKey] {
            staircaseCacheLock.unlock()
            return cached
        }
        staircaseCacheLock.unlock()

        let step = rowSize ?? defaultRowSize(for: symbol, samplePrice: bars.first?.close)
        let stepDouble = NSDecimalNumber(decimal: step).doubleValue
        guard stepDouble > 0 else { return [] }

        var binsMap: [Int: Decimal] = [:]
        var maxV: Decimal = .zero
        var pocKey: Int = 0
        var results: [(timestamp: Int64, pocPrice: Decimal)] = []
        results.reserveCapacity(bars.count)

        for bar in bars {
            let lowD = NSDecimalNumber(decimal: bar.low).doubleValue
            let highD = NSDecimalNumber(decimal: bar.high).doubleValue
            let startKey = Int(floor(lowD / stepDouble))
            let endKey = max(startKey, Int(floor(highD / stepDouble)))
            let spanCount = max(1, endKey - startKey + 1)
            let effectiveVol = bar.volume > 0 ? bar.volume : Decimal(100)
            let volPerBin = effectiveVol / Decimal(spanCount)

            for k in startKey...endKey {
                let newV = binsMap[k, default: .zero] + volPerBin
                binsMap[k] = newV
                if newV > maxV {
                    maxV = newV
                    pocKey = k
                }
            }

            let pocPrice = Decimal(pocKey) * step + (step / Decimal(2))
            results.append((timestamp: bar.timestamp, pocPrice: pocPrice))
        }

        staircaseCacheLock.lock()
        if staircaseCache.count > 128 {
            staircaseCache.removeAll(keepingCapacity: true)
        }
        staircaseCache[cacheKey] = results
        staircaseCacheLock.unlock()

        return results
    }
}
