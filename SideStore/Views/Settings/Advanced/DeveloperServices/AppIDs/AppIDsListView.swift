//
//  AppIDsListView.swift
//  SideStore
//
//  Created by Magesh K on 2/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import SideSign

struct AppIDsListView: View {
    @ObservedObject var viewModel: DeveloperServicesViewModel
    weak var presentingViewController: UIViewController?

    @State private var searchText = ""
    @State private var showRegisterSheet = false
    @State private var newAppIDName = ""
    @State private var newAppIDBundleID = ""

    @State private var appIDToDelete: ALTAppID? = nil
    @State private var showDeleteConfirmation = false

    private var filteredAppIDs: [ALTAppID] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return viewModel.appIDs
        }
        return viewModel.appIDs.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText) ||
            $0.identifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            Section(header: Text("已注册的 App ID（\(viewModel.appIDs.count)）")) {
                if filteredAppIDs.isEmpty {
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else {
                        Text(searchText.isEmpty ? "开发者后台中没有已注册的 App ID。" : "未找到匹配的 App ID。")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                } else {
                    ForEach(filteredAppIDs, id: \.identifier) { appID in
                        NavigationLink(destination: AppIDDetailView(appID: appID, viewModel: viewModel, presentingViewController: presentingViewController)) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(appID.name.isEmpty ? "App ID" : appID.name)
                                        .font(.headline)
                                    Spacer()
                                    if !appID.features.isEmpty {
                                        Text("\(appID.features.count) 项功能")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.accentColor.opacity(0.15))
                                            .foregroundColor(.accentColor)
                                            .cornerRadius(6)
                                    }
                                }
                                Text(appID.bundleIdentifier)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                HStack {
                                    Text("ID：\(appID.identifier)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if let expiration = appID.expirationDate {
                                        Text("到期时间：\(formatDate(expiration))")
                                            .font(.caption)
                                            .foregroundColor(expiration < Date() ? .red : .secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        #if !os(tvOS)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            SwiftUI.Button(role: .destructive) {
                                appIDToDelete = appID
                                showDeleteConfirmation = true
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        #endif
                        .contextMenu {
                            SwiftUI.Button(role: .destructive) {
                                appIDToDelete = appID
                                showDeleteConfirmation = true
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        #if !os(tvOS)
        .listStyle(InsetGroupedListStyle())
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "搜索 App ID")
        #else
        .listStyle(GroupedListStyle())
        #endif
        .navigationTitle("App ID")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                SwiftUI.Button {
                    showRegisterSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable {
            await viewModel.fetchAppIDs(presentingViewController: presentingViewController, isPullToRefresh: true)
        }
        .sheet(isPresented: $showRegisterSheet) {
            NavigationView {
                Form {
                    Section(header: Text("App ID 信息"), footer: Text("Bundle ID 必须符合反向 DNS 格式（例如 com.example.myapp）。")) {
                        TextField("名称（例如 My App）", text: $newAppIDName)
                        TextField("Bundle ID", text: $newAppIDBundleID)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                .navigationTitle("注册 App ID")
                .navigationBarItems(
                    leading: SwiftUI.Button("取消") {
                        newAppIDName = ""
                        newAppIDBundleID = ""
                        showRegisterSheet = false
                    },
                    trailing: SwiftUI.Button("注册") {
                        let name = newAppIDName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let bundleID = newAppIDBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty, !bundleID.isEmpty else { return }
                        Task {
                            let success = await viewModel.createAppID(name: name, bundleIdentifier: bundleID, presentingViewController: presentingViewController)
                            if success {
                                newAppIDName = ""
                                newAppIDBundleID = ""
                                showRegisterSheet = false
                            }
                        }
                    }
                    .disabled(newAppIDName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              newAppIDBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              viewModel.isActionLoading)
                )
            }
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text(viewModel.isPaidAccount ? "删除 App ID？" : "警告：删除 App ID？"),
                message: Text(deleteAlertMessage),
                primaryButton: .destructive(Text("删除")) {
                    if let target = appIDToDelete {
                        Task {
                            _ = await viewModel.deleteAppID(target, presentingViewController: presentingViewController)
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .developerServicesToast(viewModel: viewModel)
    }

    private var deleteAlertMessage: String {
        guard let appID = appIDToDelete else { return "" }
        let name = appID.name.isEmpty ? "此 App ID" : "'\(appID.name)'"
        let bundleID = appID.bundleIdentifier.isEmpty ? "" : " (\(appID.bundleIdentifier))"

        if viewModel.isPaidAccount {
            return "确定要删除 \(name)\(bundleID) 吗？这还会移除所有关联的描述文件。"
        }

        var expiryNotice = "在其通常 7 天有效期的剩余天数过后自动过期。"
        if let expiration = appID.expirationDate {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.day], from: Date(), to: expiration)
            if let days = components.day, days > 0 {
                expiryNotice = "在其通常 7 天有效期的剩余 \(days) 天后自动过期。"
            }
        }

        return "警告：删除 \(name)\(bundleID) 不会释放 App ID 名额。\n\n此 App ID 将被保留，并\(expiryNotice)\n\n确定要删除它吗？"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
