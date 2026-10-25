//
//  SideSignConfigurationView.swift
//  SideStore
//
//  Created by Magesh K on 11/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers
import SideSign

private extension Color {
    static let settingsRowBackground = Color.white.opacity(0.15)
    static let settingsDivider = Color.white.opacity(0.15)
}

@MainActor
class SideSignConfigurationViewModel: ObservableObject {
    @Published var grandSlamService: String = ""
    @Published var grandSlamHeaderVersion: String = ""
    @Published var grandSlamAuthApp: String = ""
    @Published var grandSlamUserAgent: String = ""

    @Published var appleAuthAppIDKey: String = ""
    @Published var appleAuthUserAgent: String = ""

    @Published var developerServicesClientID: String = ""
    @Published var developerServicesProtocolVersion: String = ""
    @Published var developerServicesServicesProtocolVersion: String = ""
    @Published var developerServicesUserAgent: String = ""

    @Published var isLoading: Bool = false
    @Published var viewMode: Int = 0 // 0 = Interactive, 1 = Raw JSON
    @Published var rawEditableJSON: String = ""

    init() {
        Task {
            await loadData()
        }
    }

    func loadData() async {
        let headers = await SideSignConfigManager.shared.loadConfig()
        applyHeadersToState(headers)
        updateRawEditableJSON()
    }

    private func applyHeadersToState(_ headers: SideSignHeaders) {
        grandSlamService = headers.grandSlam.service
        grandSlamHeaderVersion = headers.grandSlam.headerVersion
        grandSlamAuthApp = headers.grandSlam.authApp
        grandSlamUserAgent = headers.grandSlam.userAgent

        appleAuthAppIDKey = headers.appleAuth.appIDKey
        appleAuthUserAgent = headers.appleAuth.userAgent

        developerServicesClientID = headers.developerServices.clientID
        developerServicesProtocolVersion = headers.developerServices.protocolVersion
        developerServicesServicesProtocolVersion = headers.developerServices.servicesProtocolVersion
        developerServicesUserAgent = headers.developerServices.userAgent
    }

    private func buildHeadersFromState() -> SideSignHeaders {
        SideSignHeaders(
            grandSlam: SideSignHeaders.GrandSlam(
                service: grandSlamService.isEmpty ? Constants.GrandSlam.service : grandSlamService,
                headerVersion: grandSlamHeaderVersion.isEmpty ? Constants.GrandSlam.headerVersion : grandSlamHeaderVersion,
                authApp: grandSlamAuthApp.isEmpty ? Constants.GrandSlam.authApp : grandSlamAuthApp,
                userAgent: grandSlamUserAgent.isEmpty ? Constants.GrandSlam.userAgent : grandSlamUserAgent
            ),
            appleAuth: SideSignHeaders.AppleAuth(
                appIDKey: appleAuthAppIDKey.isEmpty ? Constants.AppleAuth.appIDKey : appleAuthAppIDKey,
                userAgent: appleAuthUserAgent.isEmpty ? Constants.AppleAuth.userAgent : appleAuthUserAgent
            ),
            developerServices: SideSignHeaders.DeveloperServices(
                clientID: developerServicesClientID.isEmpty ? Constants.DeveloperServices.clientID : developerServicesClientID,
                protocolVersion: developerServicesProtocolVersion.isEmpty ? Constants.DeveloperServices.protocolVersion : developerServicesProtocolVersion,
                servicesProtocolVersion: developerServicesServicesProtocolVersion.isEmpty ? Constants.DeveloperServices.servicesProtocolVersion : developerServicesServicesProtocolVersion,
                userAgent: developerServicesUserAgent.isEmpty ? Constants.DeveloperServices.userAgent : developerServicesUserAgent
            )
        )
    }

    func updateRawEditableJSON() {
        let headers = buildHeadersFromState()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        if let data = try? encoder.encode(headers),
           let str = String(data: data, encoding: .utf8) {
            rawEditableJSON = str
        }
    }

    func save() async {
        let headers = buildHeadersFromState()
        await SideSignConfigManager.shared.saveConfig(headers)
        updateRawEditableJSON()
        showToast(text: "已成功保存 SideSign 请求头。")
    }

    func saveRawJSON() async {
        guard let data = rawEditableJSON.data(using: .utf8) else {
            showToast(text: "编码失败", detailText: "无法将 JSON 编码为 UTF-8。")
            return
        }

        do {
            let headers = try JSONDecoder().decode(SideSignHeaders.self, from: data)
            applyHeadersToState(headers)
            await SideSignConfigManager.shared.saveConfig(headers)
            showToast(text: "SideSign JSON 配置已成功保存！")
        } catch {
            showToast(text: "JSON 结构无效", error: error)
        }
    }

    func reset() async {
        let headers = SideSignConfigManager.shared.resetToDefaults()
        applyHeadersToState(headers)
        updateRawEditableJSON()
        showToast(text: "已重置为默认的 SideSign 配置。")
    }

    func importJSON(url: URL) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let gotAccess = url.startAccessingSecurityScopedResource()
            defer {
                if gotAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let headers = try await SideSignConfigManager.shared.importFromFile(url: url)
            applyHeadersToState(headers)
            updateRawEditableJSON()
            showToast(text: "导入成功", detailText: url.lastPathComponent)
        } catch {
            showToast(text: "导入失败", error: error)
        }
    }

    func exportJSON() async -> URL? {
        guard let data = await SideSignConfigManager.shared.exportConfigData() else { return nil }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("sidesign-config.json")
        do {
            try data.write(to: tempURL, options: .atomic)
            return tempURL
        } catch {
            showToast(text: "导出失败", error: error)
            return nil
        }
    }

    func showToast(text: String, detailText: String? = nil, error: Error? = nil) {
        let toast: ToastView
        if let error = error {
            toast = ToastView(error: error, opensLog: true)
        } else {
            toast = ToastView(text: text, detailText: detailText)
        }

        let keyWindow = UIApplication.shared.alt_keyWindow
        if let rootVC = keyWindow?.rootViewController {
            let presentingVC = rootVC.presentedViewController ?? rootVC
            toast.show(in: presentingVC)
        }
    }
}

struct SideSignConfigurationView: View {
    @StateObject private var viewModel = SideSignConfigurationViewModel()
    @State private var showingResetAlert = false
    @State private var showingFileImporter = false
    @State private var exportURL: URL? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Picker("查看模式", selection: $viewModel.viewMode) {
                    Text("交互式").tag(0)
                    Text("原始 JSON").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 4)

                if viewModel.viewMode == 0 {
                    // SECTION 1: GRANDSLAM AUTH (gsa.apple.com)
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("GRANDSLAM 认证（GSA）")

                        VStack(spacing: 0) {
                            headerFieldRow(
                                title: "服务",
                                headerKey: "svct",
                                text: $viewModel.grandSlamService,
                                placeholder: Constants.GrandSlam.service
                            )

                            divider

                            headerFieldRow(
                                title: "请求头版本",
                                headerKey: "Header: Version",
                                text: $viewModel.grandSlamHeaderVersion,
                                placeholder: Constants.GrandSlam.headerVersion
                            )

                            divider

                            headerFieldRow(
                                title: "认证应用",
                                headerKey: "X-Apple-App-Info",
                                text: $viewModel.grandSlamAuthApp,
                                placeholder: Constants.GrandSlam.authApp
                            )

                            divider

                            headerFieldRow(
                                title: "用户代理",
                                headerKey: "User-Agent",
                                text: $viewModel.grandSlamUserAgent,
                                placeholder: Constants.GrandSlam.userAgent,
                                isMultiline: true
                            )
                        }
                        .background(Color.settingsRowBackground)
                        .cornerRadius(14)
                    }

                    // SECTION 2: APPLE AUTH (idmsa.apple.com)
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("APPLE 认证（IDMSA）")

                        VStack(spacing: 0) {
                            headerFieldRow(
                                title: "App ID 键",
                                headerKey: "appIdKey",
                                text: $viewModel.appleAuthAppIDKey,
                                placeholder: Constants.AppleAuth.appIDKey,
                                isMultiline: true
                            )

                            divider

                            headerFieldRow(
                                title: "用户代理",
                                headerKey: "User-Agent",
                                text: $viewModel.appleAuthUserAgent,
                                placeholder: Constants.AppleAuth.userAgent,
                                isMultiline: true
                            )
                        }
                        .background(Color.settingsRowBackground)
                        .cornerRadius(14)
                    }

                    // SECTION 3: DEVELOPER SERVICES (developerservices2.apple.com)
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("开发者服务")

                        VStack(spacing: 0) {
                            headerFieldRow(
                                title: "客户端 ID",
                                headerKey: "clientId",
                                text: $viewModel.developerServicesClientID,
                                placeholder: Constants.DeveloperServices.clientID
                            )

                            divider

                            headerFieldRow(
                                title: "协议版本",
                                headerKey: "protocolVersion",
                                text: $viewModel.developerServicesProtocolVersion,
                                placeholder: Constants.DeveloperServices.protocolVersion
                            )

                            divider

                            headerFieldRow(
                                title: "服务版本",
                                headerKey: "servicesProtocolVersion",
                                text: $viewModel.developerServicesServicesProtocolVersion,
                                placeholder: Constants.DeveloperServices.servicesProtocolVersion
                            )

                            divider

                            headerFieldRow(
                                title: "用户代理",
                                headerKey: "User-Agent",
                                text: $viewModel.developerServicesUserAgent,
                                placeholder: Constants.DeveloperServices.userAgent
                            )
                        }
                        .background(Color.settingsRowBackground)
                        .cornerRadius(14)
                    }

                    // SAVE OVERRIDES BUTTON
                    SwiftUI.Button {
                        Task {
                            await viewModel.save()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label("保存覆盖值", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .frame(height: 50)
                        .background(Color.accentColor)
                        .cornerRadius(14)
                    }
                } else {
                    // RAW JSON VIEW
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("原始配置 JSON")

                        VStack(spacing: 12) {
                            TextEditor(text: $viewModel.rawEditableJSON)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(minHeight: 320)
                                .padding(8)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(10)

                            SwiftUI.Button {
                                Task {
                                    await viewModel.saveRawJSON()
                                }
                            } label: {
                                HStack {
                                    Spacer()
                                    Label("保存原始 JSON", systemImage: "square.and.arrow.down.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .frame(height: 48)
                                .background(Color.accentColor)
                                .cornerRadius(12)
                            }
                            .disabled(viewModel.rawEditableJSON.isEmpty)
                        }
                        .padding(16)
                        .background(Color.settingsRowBackground)
                        .cornerRadius(14)
                    }
                }

                // SECTION: ACTIONS
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("操作")

                    VStack(spacing: 0) {
                        SwiftUI.Button {
                            #if !os(tvOS)
                            showingFileImporter = true
                            #else
                            if let topVC = UIApplication.shared.topViewController() {
                                TVWebFileTransferManager.shared.startImport(
                                    acceptedExtensions: ["json"],
                                    title: "导入 SideSign 配置 JSON",
                                    presentingVC: topVC
                                ) { fileURL in
                                    guard let fileURL = fileURL else { return }
                                    Task {
                                        await viewModel.importJSON(url: fileURL)
                                    }
                                }
                            }
                            #endif
                        } label: {
                            HStack {
                                Label("导入配置 JSON", systemImage: "square.and.arrow.down")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.white.opacity(0.4))
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }

                        divider

                        SwiftUI.Button {
                            Task {
                                if let url = await viewModel.exportJSON() {
                                    exportURL = url
                                }
                            }
                        } label: {
                            HStack {
                                Label("导出配置 JSON", systemImage: "square.and.arrow.up")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.white.opacity(0.4))
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }

                        divider

                        SwiftUI.Button(role: .destructive) {
                            showingResetAlert = true
                        } label: {
                            HStack {
                                Label("重置为默认值", systemImage: "arrow.circlepath")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.red)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }
                        .alert("重置为默认值？", isPresented: $showingResetAlert) {
                            SwiftUI.Button("重置", role: .destructive) {
                                Task {
                                    await viewModel.reset()
                                }
                            }
                            SwiftUI.Button("取消", role: .cancel) {}
                        } message: {
                            Text("这会将 SideSign 请求头恢复为默认的推荐值。")
                        }
                    }
                    .background(Color.settingsRowBackground)
                    .cornerRadius(14)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color(uiColor: .settingsBackground).ignoresSafeArea())
        .navigationTitle("SideSign 配置")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .overlay(
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.settingsRowBackground))
                        .shadow(radius: 10)
                }
            }
        )
        #if !os(tvOS)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await viewModel.importJSON(url: url)
                    }
                }
            case .failure(let error):
                viewModel.showToast(text: "文件选择失败", error: error)
            }
        }
        #endif
        .sheet(isPresented: Binding<Bool>(
            get: { exportURL != nil },
            set: { if !$0 { exportURL = nil } }
        )) {
            if let url = exportURL {
                ActivityViewController(activityItems: [url])
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color.white.opacity(0.6))
            .padding(.horizontal, 16)
    }

    private func headerFieldRow(
        title: String,
        headerKey: String,
        text: Binding<String>,
        placeholder: String,
        isMultiline: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(headerKey)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.45))
            }

            if isMultiline {
                #if !os(tvOS)
                TextEditor(text: text)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(minHeight: 64)
                    .padding(6)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                #else
                TextField(placeholder, text: text)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                #endif
            } else {
                TextField(placeholder, text: text)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.settingsDivider)
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }
}
