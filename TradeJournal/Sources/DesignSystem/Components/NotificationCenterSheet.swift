import SwiftUI

// MARK: - Notification Center Filter Category
private enum NotificationFilterCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case news = "News"
    case discipline = "Discipline"
    case routines = "Routines"
    case footprint = "Footprint POC"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .all: return "tray.full"
        case .news: return "newspaper"
        case .discipline: return "exclamationmark.shield"
        case .routines: return "clock"
        case .footprint: return "chart.bar.xaxis"
        }
    }
}

// MARK: - Standard 27: Unified In-App Notification Center Sheet
public struct NotificationCenterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject private var coordinator = AppNotificationCoordinator.shared
    
    @State private var selectedFilter: NotificationFilterCategory = .all
    @State private var showClearAllConfirm: Bool = false
    
    public init() {}
    
    private var filteredNotifications: [NotificationItem] {
        switch selectedFilter {
        case .all:
            return coordinator.recentNotifications
        case .news:
            return coordinator.recentNotifications.filter { $0.category == .economicNews }
        case .discipline:
            return coordinator.recentNotifications.filter { $0.category == .disciplineTilt }
        case .routines:
            return coordinator.recentNotifications.filter { $0.category == .preSessionRoutine || $0.category == .dailyJournalReview }
        case .footprint:
            return coordinator.recentNotifications.filter { $0.category == .marketStructure }
        }
    }
    
    public var body: some View {
        AppSheetContainer("Alerts & Activity", onClose: { dismiss() }) {
            VStack(spacing: 0) {
                // Category Filter Segmented Bar
                filterSegmentBar
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                
                // Action Header
                actionHeader
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                
                Divider()
                    .background(AppColors.border.opacity(0.4))
                
                // Notifications List or Empty State
                if filteredNotifications.isEmpty {
                    emptyStateView
                } else {
                    notificationsList
                }
            }
        }
        .appConfirmationAlert(
            isPresented: $showClearAllConfirm,
            title: "Clear All Alerts",
            message: "Are you sure you want to remove all alerts from your history? This action cannot be undone.",
            confirmTitle: "Clear All",
            isDestructive: true,
            onConfirm: {
                NativeHaptics.mediumImpact()
                withAnimation(AppAnimations.springStandard) {
                    coordinator.clearAll()
                }
            }
        )
        .onAppear {
            coordinator.markAllAsRead()
        }
    }
    
    // MARK: - 1. Filter Segment Bar
    
    private var filterSegmentBar: some View {
        AppSegmentedBar(
            selection: $selectedFilter,
            items: NotificationFilterCategory.allCases,
            titleFor: { cat in
                let count = countForCategory(cat)
                return count > 0 ? "\(cat.rawValue) (\(count))" : cat.rawValue
            },
            iconFor: { $0.iconName },
            isScrollable: true,
            height: 32
        )
    }
    
    private func countForCategory(_ cat: NotificationFilterCategory) -> Int {
        switch cat {
        case .all: return coordinator.recentNotifications.count
        case .news: return coordinator.recentNotifications.filter { $0.category == .economicNews }.count
        case .discipline: return coordinator.recentNotifications.filter { $0.category == .disciplineTilt }.count
        case .routines: return coordinator.recentNotifications.filter { $0.category == .preSessionRoutine || $0.category == .dailyJournalReview }.count
        case .footprint: return coordinator.recentNotifications.filter { $0.category == .marketStructure }.count
        }
    }
    
    // MARK: - 2. Action Header
    
    private var actionHeader: some View {
        HStack {
            Text("\(filteredNotifications.count) Total")
                .font(AppTypography.captionBold)
                .foregroundColor(AppColors.secondaryText)
            
            Spacer()
            
            if coordinator.unreadCount > 0 {
                Button("Mark All Read") {
                    NativeHaptics.lightImpact()
                    coordinator.markAllAsRead()
                }
                .font(AppTypography.captionBold)
                .foregroundColor(AppColors.brand)
                .padding(.trailing, 10)
            }
            
            if !coordinator.recentNotifications.isEmpty {
                Button("Clear All") {
                    NativeHaptics.lightImpact()
                    showClearAllConfirm = true
                }
                .font(AppTypography.captionBold)
                .foregroundColor(AppColors.loss)
            }
        }
    }
    
    // MARK: - 3. Notifications List with Swipe to Delete
    
    private var notificationsList: some View {
        List {
            ForEach(filteredNotifications) { item in
                notificationRow(item)
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteItem(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .background(AppColors.background)
    }
    
    // MARK: - 4. Notification Row
    
    private func notificationRow(_ item: NotificationItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top Meta Bar: Category Badge + Time + Delete Icon
            HStack(spacing: 8) {
                AppBadge(item.category.label, style: badgeStyle(for: item.category))
                
                Spacer()
                
                Text(Formatters.formatTime(item.timestamp, timeZone: env.currentTimeZone))
                    .font(AppTypography.captionMicro)
                    .foregroundColor(AppColors.secondaryText)
                
                Button {
                    deleteItem(item)
                } label: {
                    Image(systemName: "xmark")
                        .font(AppTypography.captionMicro)
                        .foregroundColor(AppColors.secondaryText.opacity(0.7))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Title
            Text(item.title)
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.primaryText)
                .lineLimit(2)
            
            // Subtitle if available
            if let sub = item.subtitle, !sub.isEmpty {
                Text(sub)
                    .font(AppTypography.captionBold)
                    .foregroundColor(AppColors.brand)
            }
            
            // Formatted Body with line breaks
            Text(item.body)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .padding(12)
        .appCardStyle(cornerRadius: 12, padding: 0)
        .contentShape(Rectangle())
        .onTapGesture {
            NativeHaptics.selection()
            handleItemTap(item)
        }
    }
    
    // MARK: - 5. Empty State
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            AppEmptyState(
                icon: "bell.slash",
                title: selectedFilter == .all ? "No Alerts Yet" : "No \(selectedFilter.rawValue) Alerts",
                message: selectedFilter == .all
                    ? "High-impact news, discipline tilt warnings, session opens, and Footprint POC reactions will appear here."
                    : "No alerts recorded in this category. Swipe left on any alert to delete it from history."
            )
            Spacer()
        }
    }
    
    // MARK: - Helpers
    
    private func deleteItem(_ item: NotificationItem) {
        NativeHaptics.mediumImpact()
        withAnimation(AppAnimations.springQuick) {
            coordinator.deleteNotification(id: item.id)
        }
    }
    
    private func badgeStyle(for category: NotificationCategory) -> AppBadge.Variant {
        switch category {
        case .disciplineTilt:
            return .loss
        case .economicNews:
            return .brand
        case .marketStructure:
            return .neutral
        case .preSessionRoutine:
            return .brand
        case .dailyJournalReview:
            return .profit
        }
    }
    
    private func handleItemTap(_ item: NotificationItem) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            switch item.category {
            case .economicNews:
                env.selectedTab = .calendar
            case .dailyJournalReview:
                env.selectedTab = .journal
                env.requestOpenTodayJournal = true
            case .disciplineTilt:
                env.selectedTab = .dashboard
                env.requestAddTrade = true
            case .preSessionRoutine:
                if item.userInfo["type"] == "morning_routine" {
                    env.selectedTab = .progress
                } else {
                    env.selectedTab = .dashboard
                    env.requestAddTrade = true
                }
            case .marketStructure:
                env.selectedTab = .trades
            }
        }
    }
}
