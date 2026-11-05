import SwiftUI

// MARK: - Footprint Key Levels Overlay (TradingView Footprint Alignment)
extension SharedChartCanvas {

    private struct RightTagItem {
        let y: CGFloat
        let code: String
        let color: Color
    }

    private struct ClusteredTag: Identifiable {
        var id: String { "\(y)_\(text)" }
        let y: CGFloat
        let text: String
        let color: Color
    }

    private static func clusterTags(_ tags: [RightTagItem]) -> [ClusteredTag] {
        guard !tags.isEmpty else { return [] }
        let sorted = tags.sorted { $0.y < $1.y }
        var clusters: [(y: CGFloat, codes: [String], color: Color, count: Int)] = []

        for tag in sorted {
            if let idx = clusters.firstIndex(where: { abs($0.y - tag.y) <= 14 }) {
                clusters[idx].codes.append(tag.code)
                clusters[idx].count += 1
                clusters[idx].y = (clusters[idx].y + tag.y) / 2.0
            } else {
                clusters.append((y: tag.y, codes: [tag.code], color: tag.color, count: 1))
            }
        }

        return clusters.map { c in
            let labelText = c.count > 1 ? "⚡ [\(c.codes.joined(separator: " | "))]" : "[\(c.codes[0])]"
            return ClusteredTag(y: c.y, text: labelText, color: c.color)
        }
    }

    @ViewBuilder
    public static func footprintOverlay(
        bars: [MarketBar],
        symbol: String,
        keyLevels: [KeyLevel],
        sessionProfiles: [SessionProfileSnapshot],
        developingProfiles: [DevelopingProfile],
        plotWidth: CGFloat,
        plotHeight: CGFloat,
        stepX: CGFloat,
        minP: Double,
        span: Double,
        panOffset: CGFloat
    ) -> some View {
        let filteredProfiles = filteredTradingViewProfiles(sessionProfiles)
        let rightTags = collectRightBorderTags(
            bars: bars,
            filteredProfiles: filteredProfiles,
            developingProfiles: developingProfiles,
            plotWidth: plotWidth,
            plotHeight: plotHeight,
            stepX: stepX,
            minP: minP,
            span: span,
            panOffset: panOffset
        )
        let clusteredTags = clusterTags(rightTags)

        ZStack(alignment: .topLeading) {
            ForEach(filteredProfiles, id: \.snap.id) { item in
                sessionProfileSegment(
                    bars: bars,
                    symbol: symbol,
                    snap: item.snap,
                    tag: item.tag,
                    plotWidth: plotWidth,
                    plotHeight: plotHeight,
                    stepX: stepX,
                    minP: minP,
                    span: span,
                    panOffset: panOffset
                )
            }

            ForEach(developingProfiles, id: \.sessionType) { dev in
                developingProfileSegment(
                    bars: bars,
                    symbol: symbol,
                    dev: dev,
                    plotWidth: plotWidth,
                    plotHeight: plotHeight,
                    stepX: stepX,
                    minP: minP,
                    span: span,
                    panOffset: panOffset
                )
            }

            intradayKeyLevels(
                bars: bars,
                keyLevels: keyLevels,
                plotWidth: plotWidth,
                plotHeight: plotHeight,
                stepX: stepX,
                minP: minP,
                span: span,
                panOffset: panOffset
            )

            // Anti-Overlap Confluence Tags on Right Border
            ForEach(clusteredTags) { cTag in
                Text(cTag.text)
                    .font(AppTypography.captionMicro)
                    .foregroundColor(cTag.color)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(AppColors.cardBackground.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .position(x: plotWidth - 34, y: cTag.y)
            }
        }
    }

    private static func collectRightBorderTags(
        bars: [MarketBar],
        filteredProfiles: [(snap: SessionProfileSnapshot, tag: String)],
        developingProfiles: [DevelopingProfile],
        plotWidth: CGFloat,
        plotHeight: CGFloat,
        stepX: CGFloat,
        minP: Double,
        span: Double,
        panOffset: CGFloat
    ) -> [RightTagItem] {
        var tags: [RightTagItem] = []

        for item in filteredProfiles {
            let snap = item.snap
            let pocD = (snap.pocPrice as NSDecimalNumber).doubleValue
            guard pocD >= (minP - span * 0.05) && pocD <= (minP + span * 1.05) else { continue }
            let y = plotHeight - CGFloat((pocD - minP) / span) * plotHeight
            let col = sessionColor(for: snap.sessionType)

            let startIdx = bars.firstIndex(where: { $0.date >= snap.startTime })
            let endIdx = bars.lastIndex(where: { $0.date <= snap.endTime })
            if let sI = startIdx ?? (bars.first.map { snap.endTime >= $0.date ? 0 : nil } ?? nil) {
                let eI = endIdx ?? min(bars.count - 1, sI)
                if snap.isNaked {
                    let rayEndIdx = findRayEndIndex(after: eI, for: snap.pocPrice, in: bars)
                    let rayXEnd = CGFloat(rayEndIdx) * stepX + (stepX / 2.0) + panOffset
                    if rayXEnd >= (plotWidth - 20) {
                        tags.append(RightTagItem(y: max(8, min(plotHeight - 8, y)), code: item.tag, color: col))
                    }
                }
            }
        }

        for dev in developingProfiles {
            guard let curPoc = dev.currentPoc else { continue }
            let pocD = (curPoc as NSDecimalNumber).doubleValue
            guard pocD >= (minP - span * 0.05) && pocD <= (minP + span * 1.05) else { continue }
            let y = plotHeight - CGFloat((pocD - minP) / span) * plotHeight
            let col = sessionColor(for: dev.sessionType)
            let x2 = CGFloat(max(0, bars.count - 1)) * stepX + (stepX / 2.0) + panOffset
            if x2 >= 0 {
                let devTag = dev.sessionType == .daily ? "D" : (dev.sessionType == .weekly ? "W" : (dev.sessionType == .tokyo ? "TYO" : (dev.sessionType == .london ? "LDN" : "NYC")))
                tags.append(RightTagItem(y: max(8, min(plotHeight - 8, y)), code: devTag, color: col))
            }
        }

        return tags
    }

    private static func filteredTradingViewProfiles(
        _ sessionProfiles: [SessionProfileSnapshot]
    ) -> [(snap: SessionProfileSnapshot, tag: String)] {
        guard !sessionProfiles.isEmpty else { return [] }
        let daily = sessionProfiles.filter { $0.sessionType == .daily }.sorted { $0.startTime > $1.startTime }
        let weekly = sessionProfiles.filter { $0.sessionType == .weekly }.sorted { $0.startTime > $1.startTime }
        let tokyo = sessionProfiles.filter { $0.sessionType == .tokyo }.sorted { $0.startTime > $1.startTime }
        let london = sessionProfiles.filter { $0.sessionType == .london }.sorted { $0.startTime > $1.startTime }
        let ny = sessionProfiles.filter { $0.sessionType == .newYork }.sorted { $0.startTime > $1.startTime }

        var list: [(SessionProfileSnapshot, String)] = []
        // 4 Independent Retention Buckets:
        // dailySnapshots: 10 most recent days
        for (idx, snap) in daily.prefix(10).enumerated() {
            let code = idx == 0 ? "D-1" : "D-\(idx + 1)"
            list.append((snap, code))
        }
        // weeklySnapshots: 3 most recent weeks
        for (idx, snap) in weekly.prefix(3).enumerated() {
            let code = idx == 0 ? "W-1" : "W-\(idx + 1)"
            list.append((snap, code))
        }
        // sessionSnapshots: 3 most recent sessions (1 Tokyo, 1 London, 1 New York)
        if let t = tokyo.first { list.append((t, "TYO")) }
        if let l = london.first { list.append((l, "LDN")) }
        if let n = ny.first { list.append((n, "NYC")) }
        return list
    }

    @ViewBuilder
    private static func sessionProfileSegment(
        bars: [MarketBar],
        symbol: String,
        snap: SessionProfileSnapshot,
        tag: String,
        plotWidth: CGFloat,
        plotHeight: CGFloat,
        stepX: CGFloat,
        minP: Double,
        span: Double,
        panOffset: CGFloat
    ) -> some View {
        let pocD = (snap.pocPrice as NSDecimalNumber).doubleValue
        if pocD >= (minP - span * 0.05) && pocD <= (minP + span * 1.05) {
            let y = plotHeight - CGFloat((pocD - minP) / span) * plotHeight
            let col = sessionColor(for: snap.sessionType)

            let startIdx = bars.firstIndex(where: { $0.date >= snap.startTime })
            let endIdx = bars.lastIndex(where: { $0.date <= snap.endTime })

            if let sI = startIdx ?? (bars.first.map { snap.endTime >= $0.date ? 0 : nil } ?? nil) {
                let eI = endIdx ?? min(bars.count - 1, sI)
                let x1 = CGFloat(sI) * stepX + (stepX / 2.0) + panOffset
                let x2 = CGFloat(eI) * stepX + (stepX / 2.0) + panOffset
                let segXEnd = max(x1 + stepX, x2)
                let isD1orW1 = snap.sessionType == .daily || snap.sessionType == .weekly
                let lineWidth: CGFloat = isD1orW1 ? 2.0 : 1.2

                let sessionBars: [MarketBar]
                if let sI = startIdx, let eI = endIdx, sI <= eI {
                    sessionBars = Array(bars[sI...eI])
                } else {
                    sessionBars = bars.filter { $0.date >= snap.startTime && $0.date <= snap.endTime }
                }
                if sessionBars.count >= 2 {
                    let steps = SessionFootprintEngine.computeStaircaseSteps(bars: sessionBars, symbol: symbol)
                    let staircase = buildStaircasePath(
                        bars: bars,
                        steps: steps,
                        stepX: stepX,
                        panOffset: panOffset,
                        minP: minP,
                        span: span,
                        plotHeight: plotHeight
                    )
                    staircase.stroke(col, lineWidth: lineWidth)
                } else if segXEnd >= 0 && x1 <= plotWidth {
                    Path { path in
                        path.move(to: CGPoint(x: max(0, x1), y: y))
                        path.addLine(to: CGPoint(x: min(plotWidth, segXEnd), y: y))
                    }
                    .stroke(col, lineWidth: lineWidth)
                }

                if snap.isNaked {
                    let rayEndIdx = findRayEndIndex(after: eI, for: snap.pocPrice, in: bars)
                    let rayXEnd = CGFloat(rayEndIdx) * stepX + (stepX / 2.0) + panOffset

                    if rayXEnd > segXEnd && segXEnd <= plotWidth {
                        Path { path in
                            path.move(to: CGPoint(x: max(0, segXEnd), y: y))
                            path.addLine(to: CGPoint(x: min(plotWidth, rayXEnd), y: y))
                        }
                        .stroke(col.opacity(0.65), style: StrokeStyle(lineWidth: 1.0, dash: [2, 3]))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private static func developingProfileSegment(
        bars: [MarketBar],
        symbol: String,
        dev: DevelopingProfile,
        plotWidth: CGFloat,
        plotHeight: CGFloat,
        stepX: CGFloat,
        minP: Double,
        span: Double,
        panOffset: CGFloat
    ) -> some View {
        if let curPoc = dev.currentPoc {
            let pocD = (curPoc as NSDecimalNumber).doubleValue
            if pocD >= (minP - span * 0.05) && pocD <= (minP + span * 1.05) {
                let y = plotHeight - CGFloat((pocD - minP) / span) * plotHeight
                let col = sessionColor(for: dev.sessionType)

                let sIdx = bars.firstIndex(where: { $0.date >= dev.startTime }) ?? max(0, bars.count - 12)
                let x1 = CGFloat(sIdx) * stepX + (stepX / 2.0) + panOffset
                let x2 = CGFloat(max(0, bars.count - 1)) * stepX + (stepX / 2.0) + panOffset
                let isD1orW1 = dev.sessionType == .daily || dev.sessionType == .weekly
                let lineWidth: CGFloat = isD1orW1 ? 2.0 : 1.4

                if x2 >= 0 && x1 <= plotWidth {
                    let devBars = bars.filter { $0.date >= dev.startTime }
                    if devBars.count >= 2 {
                        let steps = SessionFootprintEngine.computeStaircaseSteps(bars: devBars, symbol: symbol)
                        let staircase = buildStaircasePath(
                            bars: bars,
                            steps: steps,
                            stepX: stepX,
                            panOffset: panOffset,
                            minP: minP,
                            span: span,
                            plotHeight: plotHeight
                        )
                        staircase.stroke(col, lineWidth: lineWidth)
                    } else {
                        Path { path in
                            path.move(to: CGPoint(x: max(0, x1), y: y))
                            path.addLine(to: CGPoint(x: min(plotWidth, x2), y: y))
                        }
                        .stroke(col, lineWidth: lineWidth)
                    }

                    if x2 < plotWidth {
                        Path { path in
                            path.move(to: CGPoint(x: x2, y: y))
                            path.addLine(to: CGPoint(x: plotWidth, y: y))
                        }
                        .stroke(col.opacity(0.65), style: StrokeStyle(lineWidth: 1.0, dash: [2, 3]))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private static func intradayKeyLevels(
        bars: [MarketBar],
        keyLevels: [KeyLevel],
        plotWidth: CGFloat,
        plotHeight: CGFloat,
        stepX: CGFloat,
        minP: Double,
        span: Double,
        panOffset: CGFloat
    ) -> some View {
        let intradayLevels = keyLevels.filter { $0.type == .pdh || $0.type == .pdl || $0.type == .pdc }
        if !intradayLevels.isEmpty && !bars.isEmpty {
            let todayStartIdx = findTodayStartIndex(in: bars)
            let x1 = CGFloat(todayStartIdx) * stepX + (stepX / 2.0) + panOffset
            let x2 = CGFloat(bars.count - 1) * stepX + (stepX / 2.0) + panOffset

            ForEach(intradayLevels) { lvl in
                let priceD = (lvl.price as NSDecimalNumber).doubleValue
                if priceD >= minP && priceD <= (minP + span) {
                    let y = plotHeight - CGFloat((priceD - minP) / span) * plotHeight

                    Path { path in
                        path.move(to: CGPoint(x: max(0, x1), y: y))
                        path.addLine(to: CGPoint(x: min(plotWidth, x2), y: y))
                    }
                    .stroke(AppColors.secondaryText.opacity(0.4), style: StrokeStyle(lineWidth: 0.8, dash: [4, 4]))
                }
            }
        }
    }

    private static func buildStaircasePath(
        bars: [MarketBar],
        steps: [(timestamp: Int64, pocPrice: Decimal)],
        stepX: CGFloat,
        panOffset: CGFloat,
        minP: Double,
        span: Double,
        plotHeight: CGFloat
    ) -> Path {
        var path = Path()
        guard !steps.isEmpty else { return path }

        var barIndexMap: [Int64: Int] = [:]
        for (i, b) in bars.enumerated() {
            barIndexMap[b.timestamp] = i
        }

        var lastY: CGFloat? = nil
        var lastRightX: CGFloat? = nil

        for step in steps {
            guard let bIdx = barIndexMap[step.timestamp] else { continue }
            let xCenter = CGFloat(bIdx) * stepX + (stepX / 2.0) + panOffset
            let xLeft = xCenter - (stepX / 2.0)
            let xRight = xCenter + (stepX / 2.0)

            let stepPocD = (step.pocPrice as NSDecimalNumber).doubleValue
            let yStep = plotHeight - CGFloat((stepPocD - minP) / span) * plotHeight

            if let prevY = lastY, let prevRight = lastRightX {
                if abs(xLeft - prevRight) > 2.0 {
                    path.move(to: CGPoint(x: xLeft, y: yStep))
                    path.addLine(to: CGPoint(x: xRight, y: yStep))
                } else {
                    if abs(yStep - prevY) > 0.5 {
                        path.addLine(to: CGPoint(x: prevRight, y: yStep))
                    }
                    path.addLine(to: CGPoint(x: xRight, y: yStep))
                }
            } else {
                path.move(to: CGPoint(x: xLeft, y: yStep))
                path.addLine(to: CGPoint(x: xRight, y: yStep))
            }

            lastY = yStep
            lastRightX = xRight
        }

        return path
    }

    private static func findRayEndIndex(after endIndex: Int, for pocPrice: Decimal, in bars: [MarketBar]) -> Int {
        guard endIndex + 1 < bars.count else { return max(0, bars.count - 1) }
        for k in (endIndex + 1)..<bars.count {
            let b = bars[k]
            if b.low <= pocPrice && b.high >= pocPrice {
                return k
            }
        }
        return max(0, bars.count - 1)
    }

    private static func findTodayStartIndex(in bars: [MarketBar]) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = SessionFootprintEngine.sessionTimeZone
        return bars.firstIndex(where: { cal.isDateInToday($0.date) }) ?? max(0, bars.count - 24)
    }

    public static func sessionColor(for type: FootprintSessionType) -> Color {
        switch type {
        case .tokyo: return AppColors.sessionTokyo
        case .london: return AppColors.sessionLondon
        case .newYork: return AppColors.sessionNewYork
        case .daily: return AppColors.sessionDaily
        case .weekly: return AppColors.sessionWeekly
        case .monthly: return AppColors.sessionMonthly
        }
    }
}
