//
//  CreateManualProfileView.swift
//  SideStore
//
//  Created by Magesh K on 8/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import SideSign

struct CreateManualProfileView: View {
    @ObservedObject var viewModel: DeveloperServicesViewModel
    weak var presentingViewController: UIViewController?
    @Environment(\.presentationMode) var presentationMode

    @State private var profileName: String = ""
    @State private var selectedProfileType: ALTProfileType = .iOS
    @State private var selectedAppIDIdentifier: String = ""
    @State private var isManualConfiguration: Bool = false
    @State private var selectedCertificateIDs: Set<String> = []
    @State private var selectedDeviceIDs: Set<String> = []

    private var availableProfileTypes: [ALTProfileType] {
        viewModel.isPaidAccount ? ALTProfileType.allCases : ALTProfileType.freeAccountCases
    }

    private var filteredDevices: [ALTDevice] {
        if selectedProfileType.acceptedDeviceTypes == .none {
            return []
        }
        return viewModel.devices.filter { selectedProfileType.acceptedDeviceTypes.contains($0.type) }
    }

    private var selectedAppID: ALTAppID? {
        viewModel.appIDs.first { $0.identifier == selectedAppIDIdentifier }
    }

    private var canSubmit: Bool {
        guard !profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              selectedAppID != nil,
              !viewModel.isActionLoading else {
            return false
        }
        if !isManualConfiguration {
            return true
        }
        guard !selectedCertificateIDs.isEmpty else { return false }
        if selectedProfileType.acceptedDeviceTypes != .none && selectedDeviceIDs.isEmpty {
            return false
        }
        return true
    }

    var body: some View {
        NavigationView {
            Form {
                Section(footer: Text(isManualConfiguration
                    ? "手动选择哪些签名证书和测试设备获得授权。"
                    : "Apple 会为此 App ID 和平台自动配置活跃的证书和设备。")) {

                    if viewModel.appIDs.isEmpty {
                        if viewModel.isLoading {
                            HStack {
                                Text("App ID")
                                Spacer()
                                ProgressView()
                            }
                        } else {
                            Text("未找到 App ID。请先创建一个 App ID。")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Picker("App ID", selection: $selectedAppIDIdentifier) {
                            ForEach(viewModel.appIDs, id: \.identifier) { appID in
                                Text(appID.name.isEmpty ? appID.bundleIdentifier : "\(appID.name)（\(appID.bundleIdentifier)）")
                                    .tag(appID.identifier)
                            }
                        }
                        .onChange(of: selectedAppIDIdentifier) { _ in
                            updateDefaultProfileName()
                        }
                    }

                    Picker("描述文件类型", selection: $selectedProfileType) {
                        ForEach(availableProfileTypes, id: \.rawValue) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .onChange(of: selectedProfileType) { newType in
                        updateDefaultProfileName()
                        if newType.acceptedDeviceTypes == .none {
                            selectedDeviceIDs.removeAll()
                        } else {
                            let validIDs = Set(viewModel.devices.filter { newType.acceptedDeviceTypes.contains($0.type) }.compactMap { $0.deviceID })
                            selectedDeviceIDs = selectedDeviceIDs.intersection(validIDs)
                            if selectedDeviceIDs.isEmpty {
                                selectedDeviceIDs = validIDs
                            }
                        }
                    }

                    TextField("描述文件名称", text: $profileName)

                    Toggle("手动配置", isOn: $isManualConfiguration.animation())
                }

                if isManualConfiguration {
                    Section(header: HStack {
                        Text("证书（\(selectedCertificateIDs.count)/\(viewModel.certificates.count)）")
                        Spacer()
                        if !viewModel.certificates.isEmpty {
                            SwiftUI.Button(selectedCertificateIDs.count == viewModel.certificates.count ? "取消全选" : "全选") {
                                if selectedCertificateIDs.count == viewModel.certificates.count {
                                    selectedCertificateIDs.removeAll()
                                } else {
                                    selectedCertificateIDs = Set(viewModel.certificates.compactMap { $0.identifier ?? $0.serialNumber })
                                }
                            }
                            .font(.caption)
                        }
                    }, footer: Text("选择允许使用此描述文件为应用签名的证书。")) {
                        if viewModel.certificates.isEmpty {
                            if viewModel.isLoading {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                            } else {
                                Text("此团队未找到证书。")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                            }
                        } else {
                            ForEach(viewModel.certificates, id: \.serialNumber) { cert in
                                let certID = cert.identifier ?? cert.serialNumber
                                SwiftUI.Button {
                                    if selectedCertificateIDs.contains(certID) {
                                        selectedCertificateIDs.remove(certID)
                                    } else {
                                        selectedCertificateIDs.insert(certID)
                                    }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(cert.commonName ?? cert.name)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            Text("序列号：\(cert.serialNumber)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            let hasKey = ProfileManager.shared.hasPrivateKey(for: cert)
                                            HStack(spacing: 4) {
                                                Text("类型：\(hasKey ? "公钥 + 私钥" : "仅公钥")")
                                                    .font(.caption2)
                                                    .foregroundColor(hasKey ? .green : .secondary)
                                                if hasKey {
                                                    Image(systemName: "key.fill")
                                                        .font(.system(size: 9))
                                                        .foregroundColor(.green)
                                                }
                                            }
                                        }
                                        Spacer()
                                        if selectedCertificateIDs.contains(certID) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if selectedProfileType.acceptedDeviceTypes != .none {
                        Section(header: HStack {
                            Text("设备（\(selectedDeviceIDs.count)/\(filteredDevices.count)）")
                            Spacer()
                            if !filteredDevices.isEmpty {
                                SwiftUI.Button(selectedDeviceIDs.count == filteredDevices.count ? "取消全选" : "全选") {
                                    if selectedDeviceIDs.count == filteredDevices.count {
                                        selectedDeviceIDs.removeAll()
                                    } else {
                                        selectedDeviceIDs = Set(filteredDevices.compactMap { $0.deviceID })
                                    }
                                }
                                .font(.caption)
                            }
                        }, footer: Text("选择可安装使用此描述文件签名的应用的已注册测试设备。")) {
                            if filteredDevices.isEmpty {
                                if viewModel.isLoading {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                        Spacer()
                                    }
                                } else {
                                    Text("此团队未找到已注册的 \(selectedProfileType.displayName) 设备。")
                                        .foregroundColor(.secondary)
                                        .font(.subheadline)
                                }
                            } else {
                                ForEach(filteredDevices, id: \.identifier) { device in
                                    let devID = device.deviceID ?? device.identifier
                                    SwiftUI.Button {
                                        if selectedDeviceIDs.contains(devID) {
                                            selectedDeviceIDs.remove(devID)
                                        } else {
                                            selectedDeviceIDs.insert(devID)
                                        }
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(device.name)
                                                    .font(.subheadline)
                                                Text(device.identifier)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            if selectedDeviceIDs.contains(devID) {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.accentColor)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("新描述文件")
            .navigationBarItems(
                leading: SwiftUI.Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: SwiftUI.Button {
                    guard let appID = selectedAppID else { return }
                    Task {
                        let success: Bool
                        if !isManualConfiguration {
                            success = await viewModel.downloadProfile(for: appID, type: selectedProfileType, presentingViewController: presentingViewController)
                        } else {
                            success = await viewModel.createManualProfile(
                                name: profileName.trimmingCharacters(in: .whitespacesAndNewlines),
                                appID: appID,
                                certificateIDs: Array(selectedCertificateIDs),
                                deviceIDs: Array(selectedDeviceIDs),
                                type: selectedProfileType,
                                presentingViewController: presentingViewController
                            )
                        }
                        if success {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                } label: {
                    if viewModel.isActionLoading {
                        ProgressView()
                    } else {
                        Text("生成")
                            .bold()
                    }
                }
                .disabled(!canSubmit)
            )
            .task {
                if viewModel.appIDs.isEmpty {
                    await viewModel.fetchAppIDs(presentingViewController: presentingViewController)
                }
                if viewModel.certificates.isEmpty {
                    await viewModel.fetchCertificates(presentingViewController: presentingViewController)
                }
                if viewModel.devices.isEmpty {
                    await viewModel.fetchDevices(presentingViewController: presentingViewController)
                }
                if selectedAppIDIdentifier.isEmpty, let firstAppID = viewModel.appIDs.first {
                    selectedAppIDIdentifier = firstAppID.identifier
                }
                updateDefaultProfileName()
                if selectedCertificateIDs.isEmpty {
                    selectedCertificateIDs = Set(viewModel.certificates.compactMap { $0.identifier ?? $0.serialNumber })
                }
                if selectedDeviceIDs.isEmpty {
                    selectedDeviceIDs = Set(filteredDevices.compactMap { $0.deviceID })
                }
            }
        }
    }

    private func updateDefaultProfileName() {
        if let appID = selectedAppID {
            profileName = "\(appID.name) \(selectedProfileType.displayName)"
        } else if profileName.isEmpty {
            profileName = selectedProfileType.displayName
        }
    }
}
