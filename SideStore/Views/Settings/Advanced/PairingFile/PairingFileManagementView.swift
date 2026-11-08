//
//  PairingFileManagementView.swift
//  SideStore
//
//  Created by Magesh K on 19/09/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers
import MinimuxerCommon

private extension Color {
    static let settingsRowBackground = Color.white.opacity(0.15)
    static let settingsDivider = Color.white.opacity(0.15)
}

struct PairingFileManagementView: View {
    @StateObject private var viewModel = PairingFileManagementViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                activeProtocolSection
                pairingFilesSection
                pairingMethodsSection
                managementSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color(uiColor: .settingsBackground).ignoresSafeArea())
        .navigationTitle("配对文件管理")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                SwiftUI.Button {
                    viewModel.toggleGlobalHide()
                } label: {
                    Image(systemName: viewModel.isGlobalHideActive ? "eye.slash" : "eye")
                }
                .accessibilityLabel("切换敏感信息显示")
            }
        }
        .onAppear {
            viewModel.refresh()
        }
        #if !os(tvOS)
        .fileImporter(
            isPresented: $viewModel.showFileImporter,
            allowedContentTypes: viewModel.allowedPairingTypes
        ) { result in
            viewModel.handleImportResult(result)
        }
        #endif
        .alert(item: $viewModel.activeAlert) { alert in
            switch alert {
            case .deleteConfirmation(let proto):
                return Alert(
                    title: Text("删除配对文件？"),
                    message: Text(LocalizedStringKey("确定要删除此配对文件吗？这会移除 **\(proto.rawValue)** 的配对凭据。")),
                    primaryButton: .destructive(Text("删除")) {
                        viewModel.deletePairingFile(for: proto)
                    },
                    secondaryButton: .cancel()
                )
            case .resetConfirmation:
                return Alert(
                    title: Text("重置配对文件？"),
                    message: Text(LocalizedStringKey("这将删除所有已存储的配对文件（**Lockdown** 和**远程配对**）。你需要重新配对或重新导入配对文件，并重启 SideStore。")),
                    primaryButton: .destructive(Text("删除并重置")) {
                        viewModel.resetAllPairingFiles()
                    },
                    secondaryButton: .cancel()
                )
            case .resetCompleted:
                return Alert(
                    title: Text("配对文件已重置"),
                    message: Text("所有配对文件均已重置。请重启 SideStore。"),
                    dismissButton: .default(Text("好"))
                )
            case .importError(let msg):
                return Alert(
                    title: Text("导入错误"),
                    message: Text(LocalizedStringKey(msg)),
                    dismissButton: .default(Text("好"))
                )
            }
        }
    }

    private var activeProtocolSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("当前协议")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.6))
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                HStack {
                    Text("当前协议")
                        .font(.system(size: 16))
                        .foregroundColor(.white)

                    Spacer()

                    HStack(spacing: 6) {
                        Circle()
                            .fill(ledColor(for: viewModel.activeProtocol))
                            .frame(width: 7, height: 7)
                            .shadow(color: ledColor(for: viewModel.activeProtocol).opacity(0.8), radius: 3)

                        Text(activeProtocolTagText(for: viewModel.activeProtocol))
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .padding(.horizontal, 16)
                .frame(height: 50)

                Divider()
                    .background(Color.settingsDivider)
                    .padding(.horizontal, 16)

                HStack {
                    Text("首选协议")
                        .font(.system(size: 16))
                        .foregroundColor(.white)

                    Spacer()

                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.preferredProtocol != nil ? ledColor(for: viewModel.preferredProtocol!) : Color.gray)
                            .frame(width: 7, height: 7)
                            .shadow(color: (viewModel.preferredProtocol != nil ? ledColor(for: viewModel.preferredProtocol!) : Color.gray).opacity(0.8), radius: 3)

                        Text(viewModel.preferredProtocol != nil ? activeProtocolTagText(for: viewModel.preferredProtocol!) : "无")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .contextMenu {
                    if viewModel.preferredProtocol != nil {
                        SwiftUI.Button(role: .destructive) {
                            viewModel.clearPreferred()
                        } label: {
                            Label("清除首选协议", systemImage: "star.slash")
                        }
                    }
                }
            }
            .background(Color.settingsRowBackground)
            .cornerRadius(14)
        }
    }

    private var pairingFilesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("配对文件")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.6))
                .padding(.horizontal, 4)

            VStack(spacing: 12) {
                ForEach(viewModel.supportedProtocols, id: \.rawValue) { proto in
                    pairingFileCard(for: proto)
                }
            }
        }
    }

    private func pairingFileCard(for proto: PairingProtocol) -> some View {
        let fileURL = PairingFileManager.shared.pairingFileURL(for: proto)
        let metadata = PairingFileManager.shared.metadata(for: proto)
        let isInstalled = metadata.exists
        let content = isInstalled ? PairingFileManager.shared.fetchPairingFile(for: proto) : nil

        let parsed = content != nil ? (try? PairingFileManager.shared.parse(content: content!, preferred: proto)) : nil
        let remoteRP = parsed as? RPPairingFile
        let lockdown = parsed as? LockdownPairingFile
        let isValid = parsed != nil

        let fileSize = metadata.size
        let creationDate = metadata.creationDate
        let modDate = metadata.modificationDate

        return VStack(alignment: .leading, spacing: 0) {
            if isInstalled {
                NavigationLink(destination: PairingFileDetailView(mode: proto)) {
                    installedCardHeader(for: proto, isValid: isValid)
                }
                .contextMenu {
                    if isValid {
                        if UserDefaults.standard.isMinimuxerBackendHotswapEnabled && proto != viewModel.activeProtocol {
                            SwiftUI.Button {
                                Task {
                                    await viewModel.activate(proto: proto)
                                }
                            } label: {
                                Label("激活", systemImage: "bolt.fill")
                            }
                        }

                        if proto != viewModel.preferredProtocol {
                            SwiftUI.Button {
                                viewModel.setPreferred(proto: proto)
                            } label: {
                                Label("设为首选", systemImage: "star.fill")
                            }
                        } else {
                            SwiftUI.Button {
                                viewModel.clearPreferred()
                            } label: {
                                Label("取消首选", systemImage: "star.slash")
                            }
                        }

                        if proto == viewModel.activeProtocol {
                            SwiftUI.Button { } label: {
                                Label("当前生效", systemImage: "checkmark.circle.fill")
                            }
                            .disabled(true)
                        }
                    }

                    SwiftUI.Button {
                        viewModel.promptImport(for: proto)
                    } label: {
                        Label("导入 / 替换文件", systemImage: "square.and.arrow.down")
                    }

                    SwiftUI.Button(role: .destructive) {
                        viewModel.confirmDelete(for: proto)
                    } label: {
                        Label("删除配对文件", systemImage: "trash")
                    }
                }

                divider

                VStack(spacing: 0) {
                    infoRow(label: "文件名", value: fileURL.lastPathComponent, isMonospaced: true)
                    divider
                    if proto == viewModel.activeProtocol || proto == viewModel.preferredProtocol {
                        protocolStatusRow(for: proto)
                        divider
                    }
                    if proto == .rppairing {
                        if let id = remoteRP?.identifier, !id.isEmpty {
                            identifierRow(label: "标识符", value: id, fieldKey: "rp_identifier")
                            divider
                        }
                        infoRow(label: "密钥材料", value: (remoteRP?.publicKey != nil && remoteRP?.privateKey != nil) ? "公钥与私钥正常" : "密钥不完整")
                        divider
                    } else {
                        if let sysBUID = lockdown?.systemBUID, !sysBUID.isEmpty {
                            identifierRow(label: "SystemBUID", value: sysBUID, fieldKey: "lockdown_sysbuid")
                            divider
                        }
                        if let hostID = lockdown?.hostID, !hostID.isEmpty {
                            identifierRow(label: "HostID", value: hostID, fieldKey: "lockdown_hostid")
                            divider
                        }
                        if let udid = lockdown?.udid, !udid.isEmpty {
                            identifierRow(label: "硬件 UDID", value: udid, fieldKey: "lockdown_udid")
                            divider
                        }
                        if let wifi = lockdown?.wifiMACAddress, !wifi.isEmpty {
                            identifierRow(label: "Wi-Fi MAC", value: wifi, fieldKey: "lockdown_wifi")
                            divider
                        }
                    }

                    infoRow(label: "文件大小", value: ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                    if let created = creationDate {
                        divider
                        infoRow(label: "创建日期", value: formatDate(created))
                    }
                    if let mod = modDate {
                        divider
                        infoRow(label: "修改日期", value: formatDate(mod))
                    }
                }
            } else {
                SwiftUI.Button {
                    viewModel.promptImport(for: proto)
                } label: {
                    VStack(spacing: 0) {
                        missingCardHeader(for: proto)
                        divider
                        infoRow(label: "文件名", value: fileURL.lastPathComponent, isMonospaced: true)
                    }
                }
                .buttonStyle(.plain)
                .contextMenu {
                    SwiftUI.Button {
                        viewModel.promptImport(for: proto)
                    } label: {
                        Label("导入配对文件", systemImage: "square.and.arrow.down")
                    }
                }
            }
        }
        .background(Color.settingsRowBackground)
        .cornerRadius(14)
    }

    private func installedCardHeader(for proto: PairingProtocol, isValid: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: proto == .rppairing ? "bolt.horizontal.circle.fill" : "lock.shield.fill")
                .font(.system(size: 22))
                .foregroundColor(proto == .rppairing ? .cyan : .green)

            Text(proto == .rppairing ? "远程配对文件" : "Lockdown 配对文件")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            if isValid {
                Text("已配置")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(6)
            } else {
                Text("无效")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(6)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
    }

    private func missingCardHeader(for proto: PairingProtocol) -> some View {
        HStack(spacing: 12) {
            Image(systemName: proto == .rppairing ? "bolt.horizontal.circle" : "lock.shield")
                .font(.system(size: 22))
                .foregroundColor(Color.white.opacity(0.3))

            Text(proto == .rppairing ? "远程配对文件" : "Lockdown 配对文件")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.white.opacity(0.8))

            Spacer()

            Text("缺失")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.red.opacity(0.15))
                .cornerRadius(6)

            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.accentColor)
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
    }

    private func identifierRow(label: String, value: String, fieldKey: String) -> some View {
        let isRevealed = !viewModel.isGlobalHideActive || viewModel.revealedFieldKeys.contains(fieldKey)
        let displayValue = isRevealed ? value : "••••••••••••••••"

        return SwiftUI.Button {
            viewModel.toggleReveal(for: fieldKey)
        } label: {
            HStack {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.6))
                Spacer()
                Text(displayValue)
                    .font(.system(size: 13, weight: .medium, design: isRevealed ? .monospaced : .default))
                    .foregroundColor(Color.white.opacity(0.9))
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
        }
        .buttonStyle(.plain)
    }

    private func infoRow(label: String, value: String, isMonospaced: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: isMonospaced ? .monospaced : .default))
                .foregroundColor(Color.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
    }

    @ViewBuilder
    private func protocolStatusRow(for proto: PairingProtocol) -> some View {
        HStack {
            Text("状态")
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.6))

            Spacer()

            HStack(spacing: 8) {
                if proto == viewModel.activeProtocol {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(ledColor(for: proto))
                            .frame(width: 7, height: 7)
                            .shadow(color: ledColor(for: proto).opacity(0.8), radius: 3)

                        Text("已激活")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                }

                if proto == viewModel.preferredProtocol {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 7, height: 7)
                            .shadow(color: Color.yellow.opacity(0.8), radius: 3)

                        Text("首选")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
    }

    private var pairingMethodsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("配对方式")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.6))
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                NavigationLink(destination: WirelessPairView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        Text("无线配对")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                }
            }
            .background(Color.settingsRowBackground)
            .cornerRadius(14)
        }
    }

    private var managementSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("管理")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.6))
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                SwiftUI.Button(action: {
                    viewModel.confirmReset()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.counterclockwise.circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.red)
                        Text("重置配对文件")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                }
            }
            .background(Color.settingsRowBackground)
            .cornerRadius(14)

            Text("重置配对文件会移除已存储的 Lockdown 和远程配对凭据。你需要重新配对或重新导入配对文件，并重启 SideStore。")
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(0.5))
                .padding(.horizontal, 4)
                .padding(.top, 4)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.settingsDivider)
            .frame(height: 1)
            .padding(.leading, 16)
    }

    private func ledColor(for proto: PairingProtocol) -> Color {
        switch proto {
        case .lockdown:
            return .green
        case .rppairing:
            return .cyan
        case .unknown:
            return .orange
        }
    }

    private func activeProtocolTagText(for proto: PairingProtocol) -> String {
        switch proto {
        case .lockdown:
            return "lockdown"
        case .rppairing:
            return "rppairing"
        case .unknown:
            return "unknown"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
