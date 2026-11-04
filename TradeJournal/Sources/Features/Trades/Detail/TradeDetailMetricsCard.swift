import SwiftUI

/// Financial and Execution Metrics Card for Trade Detail View
public struct TradeDetailMetricsCard: View {
    public let trade: Trade
    public let durationString: String?
    public let ticketDisplay: String?
    public let reportingCurrency: String
    public let timeZone: TimeZone
    
    public init(
        trade: Trade,
        durationString: String?,
        ticketDisplay: String?,
        reportingCurrency: String,
        timeZone: TimeZone
    ) {
        self.trade = trade
        self.durationString = durationString
        self.ticketDisplay = ticketDisplay
        self.reportingCurrency = reportingCurrency
        self.timeZone = timeZone
    }
    
    public var body: some View {
        TradeFormCardContainer {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                AppSectionHeader("Execution & financials")
                
                // 2x3 Grid of Clean Text Metrics
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 12) {
                    AppTextMetric(
                        title: "Gross P&L",
                        value: Formatters.formatPnL(trade.grossPnl, currency: reportingCurrency),
                        color: Formatters.pnlColor(trade.grossPnl)
                    )
                    
                    AppTextMetric(
                        title: "Fees & Commissions",
                        value: Formatters.formatCurrency(trade.fees, currency: reportingCurrency),
                        color: trade.fees > 0 ? AppColors.warning : AppColors.primaryText
                    )
                    
                    AppTextMetric(
                        title: "Net Realized P&L",
                        value: Formatters.formatPnL(trade.netPnl, currency: reportingCurrency),
                        color: Formatters.pnlColor(trade.netPnl)
                    )
                    
                    if trade.swapAmount != 0 {
                        AppTextMetric(
                            title: "Overnight Swap",
                            value: Formatters.formatPnL(trade.swapAmount, currency: reportingCurrency),
                            color: trade.swapAmount < 0 ? AppColors.warning : AppColors.profit
                        )
                    } else if let ticket = ticketDisplay {
                        AppTextMetric(
                            title: "Order Ticket",
                            value: "#\(ticket)"
                        )
                    } else {
                        AppTextMetric(
                            title: "Duration",
                            value: durationString ?? "–"
                        )
                    }
                    
                    AppTextMetric(
                        title: "Avg Entry Price",
                        value: Formatters.price(trade.avgEntry, symbol: trade.symbol),
                        subtitle: Formatters.formatDateTime(trade.openedAt, timeZone: timeZone)
                    )
                    
                    exitPriceMetric
                }
            }
        }
    }
    
    private var exitPriceMetric: some View {
        let title = "Avg Exit Price"
        if trade.status.isClosed {
            return AppTextMetric(
                title: title,
                value: trade.avgExit.map { Formatters.price($0, symbol: trade.symbol) } ?? "–",
                subtitle: trade.closedAt.map { Formatters.formatDateTime($0, timeZone: timeZone) }
            )
        } else if trade.isPartiallyClosed {
            return AppTextMetric(
                title: title,
                value: trade.avgExit.map { Formatters.price($0, symbol: trade.symbol) } ?? "Partial",
                subtitle: "\(Formatters.formatNumber(trade.closedQuantity)) lots closed"
            )
        } else {
            return AppTextMetric(
                title: title,
                value: "Open",
                subtitle: "Active position"
            )
        }
    }
}
