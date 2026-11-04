import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 3 Canonical Grouped Settings Sections
public enum SettingsSection: String, CaseIterable, Identifiable {
    case preferences = "preferences"
    case connections = "connections"
    case aiAndData = "ai-data"
    
    public var id: String { rawValue }
    
    public var label: String {
        switch self {
        case .preferences: return "Preferences"
        case .connections: return "Connections"
        case .aiAndData: return "AI & Data"
        }
    }
    
    public var iconName: String {
        switch self {
        case .preferences: return "slider.horizontal.3"
        case .connections: return "antenna.radiowaves.left.and.right"
        case .aiAndData: return "sparkles"
        }
    }
    
    public var description: String {
        switch self {
        case .preferences:
            return "Theme appearance, timezones, economic news radar, and discipline routines."
        case .connections:
            return "Broker accounts, The5ers prop firm sync, and OANDA market data feeds."
        case .aiAndData:
            return "AI trading coach configuration, Supabase cloud sync, backups, and storage."
        }
    }
}

public struct SettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var dataStore = TradeDataStore.shared
    
    private var activeSection: SettingsSection { env.settingsActiveSection }
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switch activeSection {
                case .preferences:
                    GeneralSettingsView()
                    NotificationSettingsView()
                case .connections:
                    ConnectionsSettingsView()
                    MarketDataSettingsView()
                case .aiAndData:
                    AiSettingsView()
                    YourDataSettingsView()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 88)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.background)
    }
}
