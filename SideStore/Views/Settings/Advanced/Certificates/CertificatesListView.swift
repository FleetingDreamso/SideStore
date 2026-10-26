//
//  CertificatesListView.swift
//  SideStore
//
//  Created by Magesh K on 2026-07-03.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import SideSign

struct CertificatesListView: View {
    @ObservedObject var viewModel: CertificatesViewModel
    
    var onRowTap:     (ALTX509Certificate) -> Void
    var onRevoke:     (ALTX509Certificate) -> Void
    var onExportP12:  (ALTX509Certificate) -> Void
    var onClearKey:   (ALTX509Certificate) -> Void
    var onAddKeyBin:  (ALTX509Certificate) -> Void
    var onAddKeyText: (ALTX509Certificate) -> Void
    var onDelete:     (ALTX509Certificate) -> Void
    
    var body: some View {
        if viewModel.certificates.isEmpty {
            Section(header: Text("所有证书")) {
                if viewModel.isLoading {
                    Text("正在获取证书……").foregroundColor(.secondary)
                } else {
                    Text("未找到本地证书。").foregroundColor(.secondary)
                }
            }
        } else {
            ForEach(viewModel.groupedCertificatesList) { group in
                Section {
                    ForEach(group.certificates, id: \.serialNumber) { cert in
                        AdaptiveTappableRow {
                            onRowTap(cert)
                        } content: {
                            CertificateRowView(
                                cert:        cert,
                                viewModel:   viewModel,
                                onRevoke:    { onRevoke(cert) },
                                onExportP12: { onExportP12(cert) },
                                onClearKey:  { onClearKey(cert) },
                                onAddKeyBin: { onAddKeyBin(cert) },
                                onAddKeyText:{ onAddKeyText(cert) },
                                onDelete:    { onDelete(cert) }
                            )
                        }
                        #if !os(tvOS)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if viewModel.remoteSerials.contains(cert.serialNumber) {
                                SwiftUI.Button(role: .destructive) {
                                    onRevoke(cert)
                                } label: {
                                    Label("吊销", systemImage: "xmark.circle")
                                }
                            }
                            if viewModel.isCertificateLocallyCached(cert) {
                                SwiftUI.Button(role: .destructive) {
                                    onDelete(cert)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if cert.serialNumber == viewModel.activeSerialNumber {
                                SwiftUI.Button {
                                    viewModel.deactivateActiveCertificate()
                                } label: {
                                    Label("停用", systemImage: "xmark.seal")
                                }
                                .tint(.gray)
                            } else {
                                SwiftUI.Button {
                                    viewModel.makeCertificateActive(cert)
                                } label: {
                                    Label("激活", systemImage: "checkmark.seal")
                                }
                                .tint(.green)
                            }
                        }
                        #endif
                    }
                } header: {
                    CertGroupHeaderView(group: group, viewModel: viewModel)
                } footer: {
                    if group.id == viewModel.groupedCertificatesList.last?.id {
                        Text("后缀（R）表示该证书已在 Apple 开发者后台中远程注册。")
                    }
                }
            }
        }
    }
}

private struct CertGroupHeaderView: View {
    let group: GroupedCertificates
    @ObservedObject var viewModel: CertificatesViewModel
    #if os(tvOS)
    @State private var showSortDialog: Bool = false
    @State private var showGroupDialog: Bool = false
    #endif
    
    private var headerTitle: String {
        if group.name == "证书" {
            let localCount = viewModel.certificates.count
            if viewModel.hasFetchedRemote {
                let remoteCount = viewModel.remoteSerials.count
                return "证书 \(localCount)（\(remoteCount)R）"
            } else {
                return "证书 \(localCount)"
            }
        }
        return group.name
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(headerTitle)
            Spacer()
            #if !os(tvOS)
            Menu {
                ForEach(SortOption.allCases) { option in
                    SwiftUI.Button {
                        if viewModel.currentSort == option { viewModel.isAscending.toggle() }
                        else { viewModel.currentSort = option; viewModel.isAscending = (option == .name) }
                    } label: {
                        if viewModel.currentSort == option {
                            Label("\(option.rawValue) \(viewModel.isAscending ? "↑" : "↓")", systemImage: "checkmark")
                        } else {
                            Text(option.rawValue)
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down").font(.system(size: 13)).foregroundColor(.accentColor)
            }
            Menu {
                Picker("分组方式", selection: $viewModel.currentGroup) {
                    ForEach(GroupOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } label: {
                Image(systemName: "rectangle.3.group").font(.system(size: 13)).foregroundColor(.accentColor)
            }
            #else
            SwiftUI.Button {
                showSortDialog = true
            } label: {
                Image(systemName: "arrow.up.arrow.down").font(.system(size: 13)).foregroundColor(.accentColor)
            }
            .confirmationDialog("证书排序", isPresented: $showSortDialog) {
                ForEach(SortOption.allCases) { option in
                    SwiftUI.Button("\(option.rawValue) \(viewModel.currentSort == option && viewModel.isAscending ? "↑" : "↓")") {
                        if viewModel.currentSort == option { viewModel.isAscending.toggle() }
                        else { viewModel.currentSort = option; viewModel.isAscending = (option == .name) }
                    }
                }
            }
            SwiftUI.Button {
                showGroupDialog = true
            } label: {
                Image(systemName: "rectangle.3.group").font(.system(size: 13)).foregroundColor(.accentColor)
            }
            .confirmationDialog("证书分组", isPresented: $showGroupDialog) {
                ForEach(GroupOption.allCases) { option in
                    SwiftUI.Button(option.rawValue) {
                        viewModel.currentGroup = option
                    }
                }
            }
            #endif
            SwiftUI.Button {
                viewModel.isSectionHideActive.toggle()
            } label: {
                Image(systemName: viewModel.isSectionHideActive ? "eye.slash" : "eye")
                    .font(.subheadline)
                    .foregroundColor(viewModel.isGlobalHideActive ? .gray : .accentColor)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isGlobalHideActive)
        }
    }
}

private struct AdaptiveTappableRow<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        #if !os(tvOS)
        content()
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
        #else
        SwiftUI.Button(action: action) {
            content()
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        #endif
    }
}
