//
//  AppIDDetailView.swift
//  SideStore
//
//  Created by Magesh K on 2/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import SideSign

struct AppIDDetailView: View {
    let appID: ALTAppID
    @ObservedObject var viewModel: DeveloperServicesViewModel
    weak var presentingViewController: UIViewController?

    @State private var selectedGroupIDs: Set<String> = []
    @State private var hasModifiedGroups = false
    @State private var isSavingGroups = false

    init(appID: ALTAppID, viewModel: DeveloperServicesViewModel, presentingViewController: UIViewController? = nil) {
        self.appID = appID
        self.viewModel = viewModel
        self.presentingViewController = presentingViewController
    }

    private var currentAppID: ALTAppID {
        viewModel.appIDs.first(where: { $0.identifier == appID.identifier }) ?? appID
    }

    var body: some View {
        List {
            Section(header: Text("App ID 元数据")) {
                InfoRow(label: "名称", value: currentAppID.name)
                InfoRow(label: "Bundle ID", value: currentAppID.bundleIdentifier)
                InfoRow(label: "App ID（标识符）", value: currentAppID.identifier)
                if let expiration = currentAppID.expirationDate {
                    InfoRow(label: "到期日期", value: formatDate(expiration), valueColor: expiration < Date() ? .red : .primary)
                }
            }

            Section(header: Text("功能与特性（\(currentAppID.features.count)）")) {
                if currentAppID.features.isEmpty {
                    Text("此 App ID 未启用任何特殊功能。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    let sortedFeatures = currentAppID.features.sorted { $0.key.rawValue < $1.key.rawValue }
                    ForEach(sortedFeatures, id: \.key.rawValue) { feature, value in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(displayName(for: feature))
                                    .font(.subheadline)
                                Text(feature.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(value)
                                .font(.caption)
                                .foregroundColor(value == "true" ? .green : .secondary)
                        }
                    }
                }
            }

            Section(header: Text("关联的 App 组"), footer: Text("选择要与此 App ID 关联的 App 组，然后点按“保存”。")) {
                if viewModel.appGroups.isEmpty {
                    Text("此团队没有可用的 App 组。请先创建一个 App 组。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.appGroups, id: \.identifier) { group in
                        SwiftUI.Button {
                            if selectedGroupIDs.contains(group.identifier) {
                                selectedGroupIDs.remove(group.identifier)
                            } else {
                                selectedGroupIDs.insert(group.identifier)
                            }
                            hasModifiedGroups = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.name)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Text(group.identifier)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if selectedGroupIDs.contains(group.identifier) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                        .imageScale(.large)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.secondary)
                                        .imageScale(.large)
                                }
                            }
                        }
                    }

                    if hasModifiedGroups {
                        SwiftUI.Button {
                            let groupsToAssign = viewModel.appGroups.filter { selectedGroupIDs.contains($0.identifier) }
                            Task {
                                isSavingGroups = true
                                let success = await viewModel.updateAppGroups(for: currentAppID, to: groupsToAssign, presentingViewController: presentingViewController)
                                isSavingGroups = false
                                if success {
                                    hasModifiedGroups = false
                                }
                            }
                        } label: {
                            HStack {
                                Spacer()
                                if isSavingGroups {
                                    ProgressView()
                                        .padding(.trailing, 8)
                                }
                                Text("保存组关联")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .disabled(isSavingGroups)
                    }
                }
            }

            Section(header: Text("操作")) {
                SwiftUI.Button {
                    Task {
                        _ = await viewModel.downloadProfile(for: currentAppID, presentingViewController: presentingViewController)
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.doc")
                        Text("下载描述文件")
                    }
                }
            }
        }
        #if !os(tvOS)
        .listStyle(InsetGroupedListStyle())
        #else
        .listStyle(GroupedListStyle())
        #endif
        .navigationTitle(currentAppID.name.isEmpty ? "App ID 详情" : currentAppID.name)
        .onAppear {
            initializeSelectedGroups()
        }
        .refreshable {
            async let fetchIDs: () = viewModel.fetchAppIDs(presentingViewController: presentingViewController, isPullToRefresh: true)
            async let fetchGroups: () = viewModel.fetchAppGroups(presentingViewController: presentingViewController, isPullToRefresh: true)
            _ = await (fetchIDs, fetchGroups)
        }
        .developerServicesToast(viewModel: viewModel)
    }

    private func initializeSelectedGroups() {
        var initial = Set<String>()
        let appGroupFeatureKey = Feature.appGroups.rawValue
        if currentAppID.features.keys.contains(where: { $0.rawValue == appGroupFeatureKey }) {
            for group in viewModel.appGroups {
                initial.insert(group.identifier)
            }
        }
        self.selectedGroupIDs = initial
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func displayName(for feature: Feature) -> String {
        switch feature {
        case .appGroups: return "App 组"
        case .gameCenter: return "Game Center"
        case .inAppPurchase: return "App 内购买"
        case .pushNotifications: return "推送通知"
        case .interAppAudio: return "应用间音频"
        case .associatedDomains: return "关联域"
        case .dataProtection: return "数据保护"
        case .siri: return "Siri"
        case .applePay: return "Apple Pay"
        case .vpn: return "个人 VPN"
        case .networkExtensions: return "网络扩展"
        case .multipath: return "多路径"
        case .hotspot: return "热点"
        case .nfc: return "NFC 标签读取"
        case .classKit: return "ClassKit"
        case .autoFillCredentialProvider: return "自动填充凭据提供程序"
        case .accessWiFiInformation: return "访问 Wi-Fi 信息"
        case .wirelessAccessoryConfiguration: return "无线配件配置"
        case .increasedMemoryLimit: return "提高内存上限"
        case .extendedVirtualAddressing: return "扩展虚拟寻址"
        case .increasedDebuggingMemoryLimit: return "提高调试内存上限"
        default: return feature.rawValue
        }
    }
}
