import SwiftUI

// MARK: - Standard 27: Unified Notification & Alerting Settings View
public struct NotificationSettingsView: View {
    @State private var notifyHighImpactNews: Bool = AppSettingsStore.shared.notifyHighImpactNews
    @State private var notifyNews15m: Bool = AppSettingsStore.shared.notifyNews15m
    @State private var notifyNews5m: Bool = AppSettingsStore.shared.notifyNews5m
    @State private var notifyNewsOnlyOpenTrades: Bool = AppSettingsStore.shared.notifyNewsOnlyOpenTrades
    @State private var notifyDisciplineTilt: Bool = AppSettingsStore.shared.notifyDisciplineTilt
    @State private var notifyMorningRoutine: Bool = AppSettingsStore.shared.notifyMorningRoutine
    @State private var notifyPreSessionLondon: Bool = AppSettingsStore.shared.notifyPreSessionLondon
    @State private var notifyPreSessionNewYork: Bool = AppSettingsStore.shared.notifyPreSessionNewYork
    @State private var notifyDailyJournalReview: Bool = AppSettingsStore.shared.notifyDailyJournalReview
    @State private var notifyFootprintPoc: Bool = AppSettingsStore.shared.notifyMarketStructure
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 16) {
            // MARK: - 1. Pillar 3: Economic News Radar (Forex Factory)
            SettingsCard(
                title: "Economic News Radar",
                footer: "Monitors Forex Factory high-impact events and warns before volatility surges."
            ) {
                VStack(spacing: 8) {
                    AppToggleRow(
                        "High-Impact News Alerts",
                        subtitle: "Schedules automated warnings before major releases",
                        icon: "newspaper",
                        isOn: $notifyHighImpactNews
                    ) { val in
                        AppSettingsStore.shared.notifyHighImpactNews = val
                    }
                    
                    if notifyHighImpactNews {
                        Divider().background(AppColors.border.opacity(0.4))
                        
                        AppToggleRow(
                            "15-Minute Warning",
                            subtitle: "Pre-release audit of open exposure and risk",
                            icon: "clock",
                            isOn: $notifyNews15m
                        ) { val in
                            AppSettingsStore.shared.notifyNews15m = val
                        }
                        
                        Divider().background(AppColors.border.opacity(0.4))
                        
                        AppToggleRow(
                            "5-Minute Imminent Volatility",
                            subtitle: "Warns of spread widening and slippage risk",
                            icon: "bolt.badge.clock",
                            isOn: $notifyNews5m
                        ) { val in
                            AppSettingsStore.shared.notifyNews5m = val
                        }
                        
                        Divider().background(AppColors.border.opacity(0.4))
                        
                        AppToggleRow(
                            "Filter by Open Trades & Watchlist",
                            subtitle: "Only alerts for currencies matching your active exposure",
                            icon: "line.3.horizontal.decrease.circle",
                            isOn: $notifyNewsOnlyOpenTrades
                        ) { val in
                            AppSettingsStore.shared.notifyNewsOnlyOpenTrades = val
                        }
                    }
                }
            }
            
            // MARK: - 2. Pillar 4: Psychology & Daily Routine
            SettingsCard(
                title: "Psychology & Session Routines",
                footer: "Enforces strict trading discipline and consistent journaling habits."
            ) {
                VStack(spacing: 8) {
                    AppToggleRow(
                        "Tilt & Revenge Trading Warning",
                        subtitle: "Alerts when 3 consecutive losses occur within 60 minutes",
                        icon: "exclamationmark.shield",
                        isOn: $notifyDisciplineTilt
                    ) { val in
                        AppSettingsStore.shared.notifyDisciplineTilt = val
                    }
                    
                    Divider().background(AppColors.border.opacity(0.4))
                    
                    AppToggleRow(
                        "Morning Routine Checklist (08:00)",
                        subtitle: "Prompts you to review calendar and risk limits before market opens",
                        icon: "sun.max",
                        isOn: $notifyMorningRoutine
                    ) { val in
                        AppSettingsStore.shared.notifyMorningRoutine = val
                    }
                    
                    Divider().background(AppColors.border.opacity(0.4))
                    
                    AppToggleRow(
                        "London Session Open (13:45)",
                        subtitle: "15 minutes before European liquidity opens",
                        icon: "sun.haze",
                        isOn: $notifyPreSessionLondon
                    ) { val in
                        AppSettingsStore.shared.notifyPreSessionLondon = val
                    }
                    
                    Divider().background(AppColors.border.opacity(0.4))
                    
                    AppToggleRow(
                        "New York Session Open (19:15)",
                        subtitle: "15 minutes before US equity and futures open",
                        icon: "building.2",
                        isOn: $notifyPreSessionNewYork
                    ) { val in
                        AppSettingsStore.shared.notifyPreSessionNewYork = val
                    }
                    
                    Divider().background(AppColors.border.opacity(0.4))
                    
                    AppToggleRow(
                        "End-of-Day Journal Review (22:30)",
                        subtitle: "Dispatched only if trades were executed today",
                        icon: "book.closed",
                        isOn: $notifyDailyJournalReview
                    ) { val in
                        AppSettingsStore.shared.notifyDailyJournalReview = val
                    }
                }
            }
            
            // MARK: - 3. Pillar 5: Footprint POC & Candlestick Pattern Alerts
            SettingsCard(
                title: "Footprint POC Reactions",
                footer: "Alerts when price tests or rejects Key Footprint POCs with candlestick pattern confirmation."
            ) {
                AppToggleRow(
                    "Footprint POC & Rejection Alerts",
                    subtitle: "Alerts on POC touches, Pinbars, and Engulfing patterns across any timeframe",
                    icon: "chart.bar.xaxis",
                    isOn: $notifyFootprintPoc
                ) { val in
                    AppSettingsStore.shared.notifyMarketStructure = val
                }
            }
        }
    }
}
