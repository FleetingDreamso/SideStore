//
//  UserCustomizationsView.swift
//  SideStore
//
//  Created by Magesh K on 8/2/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import Minimuxer

private extension Color {
    static let settingsRowBackground = Color.white.opacity(0.15)
    static let settingsDivider = Color.white.opacity(0.15)
}

struct UserCustomizationsView: View {
    @State private var selectedBackend: GatewayBackend = selectedGatewayBackendCache
    @State private var isBackgroundServiceEnabled: Bool = UserDefaults.standard.isBackgroundServiceEnabled
    @State private var selectedBackgroundServiceMode: BackgroundServiceMode = UserDefaults.standard.backgroundServiceMode
    @State private var useOnDeviceAnisette: Bool = UserDefaults.standard.useOnDeviceAnisette
    @State private var showAnisetteRestartConfirmation: Bool = false
    @State private var customizeInfoPlist: Bool = UserDefaults.standard.customizeInfoPlist
    @State private var preferSheetForInfoPlistCustomization: Bool = UserDefaults.standard.preferSheetForInfoPlistCustomization
    @State private var customizeEntitlements: Bool = UserDefaults.standard.customizeEntitlements
    @State private var preferSheetForEntitlementsCustomization: Bool = UserDefaults.standard.preferSheetForEntitlementsCustomization
    @State private var customizeAppId: Bool = UserDefaults.standard.customizeAppId
    @State private var customizeAppIcon: Bool = UserDefaults.standard.customizeAppIcon
    @State private var customizeProvisioningProfile: Bool = UserDefaults.standard.customizeProvisioningProfile
    @State private var customizeAppExtensions: AppExtensionCustomization = UserDefaults.standard.customizeAppExtensions
    @State private var appImportSourceMode: AppImportSourceMode = UserDefaults.standard.appImportSourceMode
    @State private var isInstallConfirmationEnabled: Bool = UserDefaults.standard.isInstallConfirmationEnabled
    @State private var isClearCustomizationsOnUninstallEnabled: Bool = UserDefaults.standard.isClearCustomizationsOnUninstallEnabled
    @State private var isAutoLaunchAppAfterInstallEnabled: Bool = UserDefaults.standard.isAutoLaunchAppAfterInstallEnabled
    @State private var autoFixAppGroupIDs: Bool = UserDefaults.standard.autoFixAppGroupIDs
    @State private var preferResignedIPA: Bool = UserDefaults.standard.preferResignedIPA
    @State private var pendingPreferIPAOngoing: Bool = false
    @State private var showPreferIPAToggleAlert: Bool = false
    @State private var isExportResignedAppEnabled: Bool = UserDefaults.standard.isExportResignedAppEnabled
    @State private var enableEMPforWireguard: Bool = UserDefaults.standard.enableEMPforWireguard
    @State private var pendingEMPOption: Bool = false
    @State private var showEMPRestartConfirmation: Bool = false
    @State private var pendingBackendOption: GatewayBackend? = nil
    @State private var showBackendRestartConfirmation: Bool = false
    @State private var skipNonCopyableFiles: Bool = UserDefaults.standard.skipNonCopyableBackupFiles
    @State private var appVerificationDisabled: Bool = UserDefaults.standard.appVerificationDisabled
    @State private var isBundleIDVerificationEnabled: Bool = UserDefaults.standard.isBundleIDVerificationEnabled
    @State private var isiOSVersionVerificationEnabled: Bool = UserDefaults.standard.isiOSVersionVerificationEnabled
    @State private var isAppVersionVerificationEnabled: Bool = UserDefaults.standard.isAppVersionVerificationEnabled
    @State private var isChecksumVerificationEnabled: Bool = UserDefaults.standard.isChecksumVerificationEnabled
    @State private var isFileSizeVerificationEnabled: Bool = UserDefaults.standard.isFileSizeVerificationEnabled
    @State private var permissionCheckingDisabled: Bool = UserDefaults.standard.permissionCheckingDisabled
    @State private var isCellularRefreshEnabled: Bool = UserDefaults.standard.isCellularRefreshEnabled
    @State private var turnOnDataShortcutName: String = UserDefaults.standard.turnOnDataShortcutName
    @State private var turnOffDataShortcutName: String = UserDefaults.standard.turnOffDataShortcutName
    @State private var turnOnBaseDelayText: String = {
        let delay = CellularRefreshManager.shared.turnOnDataBaseDelayOverride ?? AppConstants.Shortcuts.defaultTurnOnDataBaseDelay
        return String(delay)
    }()
    @State private var turnOffBaseDelayText: String = {
        let delay = CellularRefreshManager.shared.turnOffDataBaseDelayOverride ?? AppConstants.Shortcuts.defaultTurnOffDataBaseDelay
        return String(delay)
    }()
    @State private var wireGuardExportURL: URL? = nil

    @State private var isFreeAccount: Bool = false

    struct EditDialogState: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let placeholder: String
        let keyboardType: UIKeyboardType
        let onSave: (String) -> Void
    }

    @State private var editDialog: EditDialogState? = nil
    @State private var editingValueText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Section 0: APPEARANCE & THEMES
                VStack(alignment: .leading, spacing: 8) {
                    Text("外观与主题")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 16)
                    
                    NavigationLink(destination: ThemePickerView()) {
                        HStack {
                            Text("主题管理器")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(uiColor: ThemeManager.shared.primaryColor))
                                    .frame(width: 14, height: 14)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.white.opacity(0.4))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .background(Color.settingsRowBackground)
                    .cornerRadius(14)
                }

                // Section 1: ANISETTE
                VStack(alignment: .leading, spacing: 8) {
                    Text("ANISETTE")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        toggleRow(
                            title: "设备端 Anisette",
                            subtitle: "直接在设备上运行 ADI 模拟，而无需使用远程服务器",
                            isOn: Binding(
                                get: { useOnDeviceAnisette },
                                set: { newValue in
                                    useOnDeviceAnisette = newValue
                                    showAnisetteRestartConfirmation = true
                                }
                            )
                        )
                        
                        divider
                        
                        NavigationLink(destination: AnisetteDataView()) {
                            HStack {
                                Text("Anisette 客户端配置")
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
                        
                        divider
                        
                        SwiftUI.Button(role: .destructive) {
                            presentResetAdiDialog()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("重置 adi.pb")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(.red)
                                    Text("从钥匙串清除本地 Anisette 配置数据")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(Color.white.opacity(0.6))
                                }
                                Spacer()
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .frame(minHeight: 50)
                        }
                    }
                    .background(Color.settingsRowBackground)
                    .cornerRadius(14)
                }

                // Section: SIDESIGN
                VStack(alignment: .leading, spacing: 8) {
                    Text("SIDESIGN")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        NavigationLink(destination: SideSignConfigurationView()) {
                            HStack {
                                Text("SideSign 客户端配置")
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

                // Section 2: GENERAL
                generalSection

                // Section 2: APP VERIFICATION
                VStack(alignment: .leading, spacing: 8) {
                    Text("应用校验")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        toggleRow(title: "禁用所有校验", isOn: Binding(
                            get: { appVerificationDisabled },
                            set: { newValue in
                                appVerificationDisabled = newValue
                                UserDefaults.standard.appVerificationDisabled = newValue
                            }
                        ))
                        
                        divider
                        
                        Group {
                            toggleRow(title: "Bundle ID 校验", isOn: Binding(
                                get: { isBundleIDVerificationEnabled },
                                set: { newValue in
                                    isBundleIDVerificationEnabled = newValue
                                    UserDefaults.standard.isBundleIDVerificationEnabled = newValue
                                }
                            ))
                            
                            divider
                            
                            toggleRow(title: "iOS 版本校验", isOn: Binding(
                                get: { isiOSVersionVerificationEnabled },
                                set: { newValue in
                                    isiOSVersionVerificationEnabled = newValue
                                    UserDefaults.standard.isiOSVersionVerificationEnabled = newValue
                                }
                            ))
                            
                            divider
                            
                            toggleRow(title: "应用版本校验", isOn: Binding(
                                get: { isAppVersionVerificationEnabled },
                                set: { newValue in
                                    isAppVersionVerificationEnabled = newValue
                                    UserDefaults.standard.isAppVersionVerificationEnabled = newValue
                                }
                            ))
                            
                            divider
                            
                            toggleRow(title: "SHA-256 校验和检查", isOn: Binding(
                                get: { isChecksumVerificationEnabled },
                                set: { newValue in
                                    isChecksumVerificationEnabled = newValue
                                    UserDefaults.standard.isChecksumVerificationEnabled = newValue
                                }
                            ))
                            
                            divider
                            
                            toggleRow(title: "应用文件大小校验", isOn: Binding(
                                get: { isFileSizeVerificationEnabled },
                                set: { newValue in
                                    isFileSizeVerificationEnabled = newValue
                                    UserDefaults.standard.isFileSizeVerificationEnabled = newValue
                                }
                            ))
                            
                            divider
                            
                            toggleRow(title: "权限校验", isOn: Binding(
                                get: { !permissionCheckingDisabled },
                                set: { newValue in
                                    permissionCheckingDisabled = !newValue
                                    UserDefaults.standard.permissionCheckingDisabled = !newValue
                                }
                            ))
                        }
                        .disabled(appVerificationDisabled)
                        .opacity(appVerificationDisabled ? 0.5 : 1.0)
                    }
                    .background(Color.settingsRowBackground)
                    .cornerRadius(14)
                }

                // Section 3: EMPROXY & WIREGUARD
                VStack(alignment: .leading, spacing: 8) {
                    Text("EMPROXY 与 WIREGUARD")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("导出 WireGuard 配置")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("导出 SideStore.conf，以便导入 WireGuard VPN 应用")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(Color.white.opacity(0.6))
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            SwiftUI.Button(action: { exportWireGuardConfig() }) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 55, alignment: .center)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(minHeight: 50)
                        
                        divider
                        
                        toggleRow(
                            title: "EMProxy（WireGuard）服务器",
                            subtitle: "需要重启才能应用更改",
                            isOn: Binding(
                                get: { enableEMPforWireguard },
                                set: { newValue in
                                    pendingEMPOption = newValue
                                    showEMPRestartConfirmation = true
                                }
                            )
                        )
                    }
                    .background(Color.settingsRowBackground)
                    .cornerRadius(14)
                }

                // Section 4: CELLULAR REFRESH
                cellularRefreshShortcutsSection

                // Section 5: MINIMUXER BACKEND
                VStack(alignment: .leading, spacing: 8) {
                    Text("MINIMUXER 后端")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        ForEach(GatewayBackend.allCases, id: \.self) { backend in
                            SwiftUI.Button(action: {
                                if selectedBackend != backend {
                                    if UserDefaults.standard.isMinimuxerBackendHotswapEnabled {
                                        applyBackendChange(backend, restartRequired: false)
                                    } else {
                                        pendingBackendOption = backend
                                        showBackendRestartConfirmation = true
                                    }
                                }
                            }) {
                                HStack {
                                    Text(backend.rawValue)
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(.white)
                                    Spacer()
                                    if selectedBackend == backend {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(Color(uiColor: ThemeManager.shared.primaryColor))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                            if backend != GatewayBackend.allCases.last {
                                divider
                            }
                        }
                    }
                    .background(Color.settingsRowBackground)
                    .cornerRadius(14)
                }

                // Section 6: BACKGROUND SERVICE
                VStack(alignment: .leading, spacing: 8) {
                    Text("后台服务")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        toggleRow(title: "启用后台保活", isOn: Binding(
                            get: { isBackgroundServiceEnabled },
                            set: { newValue in
                                isBackgroundServiceEnabled = newValue
                                BackgroundServiceManager.setEnabled(newValue)
                            }
                        ))
                        
                        divider
                        
                        ForEach(BackgroundServiceMode.allCases, id: \.self) { mode in
                            SwiftUI.Button(action: {
                                selectedBackgroundServiceMode = mode
                                BackgroundServiceManager.switchTo(mode: mode)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(mode.displayName)
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(isBackgroundServiceEnabled ? .white : Color.white.opacity(0.4))
                                        Text(mode.subtitle)
                                            .font(.system(size: 13))
                                            .foregroundColor(Color.white.opacity(isBackgroundServiceEnabled ? 0.6 : 0.3))
                                    }
                                    Spacer()
                                    if selectedBackgroundServiceMode == mode {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(isBackgroundServiceEnabled ? Color(uiColor: ThemeManager.shared.primaryColor) : Color.white.opacity(0.3))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .disabled(!isBackgroundServiceEnabled)
                            
                            if mode != BackgroundServiceMode.allCases.last {
                                divider
                            }
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
        .navigationTitle("用户自定义")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .alert("需要重启", isPresented: $showAnisetteRestartConfirmation) {
            SwiftUI.Button("立即重启", role: .destructive) {
                Task {
                    await AuthManager.shared.signOut(keepCertificate: true, keepAnisetteData: false)
                    UserDefaults.standard.useOnDeviceAnisette = useOnDeviceAnisette
                    exit(0)
                }
            }
            SwiftUI.Button("取消", role: .cancel) {
                useOnDeviceAnisette = UserDefaults.standard.useOnDeviceAnisette
            }
        } message: {
            Text("更改 Anisette 配置将使当前已配置的 Anisette 数据失效，并且你会被登出。\n\n此操作需要重启，是否继续？")
        }
        .alert("需要重启", isPresented: $showEMPRestartConfirmation) {
            SwiftUI.Button("立即重启", role: .destructive) {
                enableEMPforWireguard = pendingEMPOption
                UserDefaults.standard.enableEMPforWireguard = pendingEMPOption
                exit(0)
            }
            SwiftUI.Button("取消", role: .cancel) {}
        } message: {
            Text("更改 EMProxy 设置需要重启 SideStore。如果取消，更改将不会被保存。")
        }
        .alert("需要重启", isPresented: $showBackendRestartConfirmation) {
            SwiftUI.Button("立即重启", role: .destructive) {
                if let newBackend = pendingBackendOption {
                    applyBackendChange(newBackend, restartRequired: true)
                }
            }
            SwiftUI.Button("取消", role: .cancel) {
                pendingBackendOption = nil
            }
        } message: {
            Text("更改 Minimuxer 后端需要重启 SideStore。如果取消，更改将不会被保存。")
        }
        .alert(pendingPreferIPAOngoing ? "优先使用重签 IPA" : "优先使用应用包", isPresented: $showPreferIPAToggleAlert) {
            SwiftUI.Button("切换") {
                preferResignedIPA = pendingPreferIPAOngoing
                UserDefaults.standard.preferResignedIPA = pendingPreferIPAOngoing
            }
            SwiftUI.Button("取消", role: .cancel) {
                pendingPreferIPAOngoing = preferResignedIPA
            }
        } message: {
            if pendingPreferIPAOngoing {
                Text("切换到“重签 IPA”会通过打包未压缩的 IPA 实现快速传输，从而优先保证安装速度（约快 40%），但在打包期间会临时占用额外的磁盘空间。")
            } else {
                Text("切换到“应用包”会直接传输应用包而无需打包临时 IPA，从而优先保证存储效率，但传输速度会明显变慢。")
            }
        }
        .sheet(isPresented: Binding<Bool>(
            get: { wireGuardExportURL != nil },
            set: { if !$0 { wireGuardExportURL = nil } }
        )) {
            if let url = wireGuardExportURL {
                ActivityViewController(activityItems: [url])
            }
        }
        .alert(
            editDialog?.title ?? "",
            isPresented: Binding<Bool>(
                get: { editDialog != nil },
                set: { if !$0 { editDialog = nil } }
            )
        ) {
            TextField(editDialog?.placeholder ?? "", text: $editingValueText)
                #if !os(tvOS)
                .keyboardType(editDialog?.keyboardType ?? .default)
                #endif
            SwiftUI.Button("好") {
                if let dialog = editDialog {
                    dialog.onSave(editingValueText)
                }
                editDialog = nil
            }
            SwiftUI.Button("取消", role: .cancel) {
                editDialog = nil
            }
        } message: {
            Text(editDialog?.message ?? "")
        }
        .task {
            isFreeAccount = (try? await AuthManager.shared.getAuthenticatedTeam())?.type == .free
        }
    }

    private func toggleRow(title: String, subtitle: String? = nil, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 50)
    }

    private func textFieldRow(
        title: String,
        subtitle: String? = nil,
        placeholder: String,
        value: String,
        unit: String? = nil,
        onTap: @escaping () -> Void
    ) -> some View {
        SwiftUI.Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack {
                    Text(value.isEmpty ? placeholder : (unit != nil ? "\(value) \(unit!)" : value))
                        .font(.system(size: 15))
                        .foregroundColor(value.isEmpty ? Color.white.opacity(0.3) : .white)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var cellularRefreshShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("蜂窝网络刷新")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.6))
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                toggleRow(
                    title: "蜂窝网络刷新",
                    subtitle: "刷新时通过“快捷指令”自动切换蜂窝数据",
                    isOn: Binding(
                        get: { isCellularRefreshEnabled },
                        set: { newValue in
                            isCellularRefreshEnabled = newValue
                            CellularRefreshManager.shared.setEnabled(newValue)
                        }
                    )
                )

                divider

                textFieldRow(
                    title: "开启蜂窝数据快捷指令",
                    subtitle: "“快捷指令”应用中该快捷指令的名称",
                    placeholder: AppConstants.Shortcuts.defaultTurnOnDataShortcutName,
                    value: turnOnDataShortcutName,
                    onTap: openTurnOnShortcutDialog
                )

                divider

                textFieldRow(
                    title: "关闭蜂窝数据快捷指令",
                    subtitle: "“快捷指令”应用中该快捷指令的名称",
                    placeholder: AppConstants.Shortcuts.defaultTurnOffDataShortcutName,
                    value: turnOffDataShortcutName,
                    onTap: openTurnOffShortcutDialog
                )

                divider

                textFieldRow(
                    title: "开启基础延迟",
                    subtitle: "开启数据后的基础等待时间（秒，≥ 0）",
                    placeholder: String(AppConstants.Shortcuts.defaultTurnOnDataBaseDelay),
                    value: turnOnBaseDelayText,
                    unit: "s",
                    onTap: openTurnOnBaseDelayDialog
                )

                divider

                textFieldRow(
                    title: "关闭基础延迟",
                    subtitle: "关闭数据后的基础等待时间（秒，≥ 0）",
                    placeholder: String(AppConstants.Shortcuts.defaultTurnOffDataBaseDelay),
                    value: turnOffBaseDelayText,
                    unit: "s",
                    onTap: openTurnOffBaseDelayDialog
                )

                divider

                SwiftUI.Button(action: resetCellularDefaults) {
                    HStack {
                        Spacer()
                        Text("重置为默认值")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
            }
            .background(Color.settingsRowBackground)
            .cornerRadius(14)
        }
    }

    private func openTurnOnShortcutDialog() {
        editingValueText = turnOnDataShortcutName
        editDialog = EditDialogState(
            title: "开启蜂窝数据快捷指令",
            message: "“快捷指令”应用中该快捷指令的名称",
            placeholder: AppConstants.Shortcuts.defaultTurnOnDataShortcutName,
            keyboardType: .default,
            onSave: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let resolved = trimmed.isEmpty ? AppConstants.Shortcuts.defaultTurnOnDataShortcutName : trimmed
                let sanitized = CellularRefreshManager.sanitizeShortcutName(resolved, fallback: AppConstants.Shortcuts.defaultTurnOnDataShortcutName)
                turnOnDataShortcutName = sanitized
                CellularRefreshManager.shared.setTurnOnDataShortcutName(sanitized)
            }
        )
    }

    private func openTurnOffShortcutDialog() {
        editingValueText = turnOffDataShortcutName
        editDialog = EditDialogState(
            title: "关闭蜂窝数据快捷指令",
            message: "“快捷指令”应用中该快捷指令的名称",
            placeholder: AppConstants.Shortcuts.defaultTurnOffDataShortcutName,
            keyboardType: .default,
            onSave: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let resolved = trimmed.isEmpty ? AppConstants.Shortcuts.defaultTurnOffDataShortcutName : trimmed
                let sanitized = CellularRefreshManager.sanitizeShortcutName(resolved, fallback: AppConstants.Shortcuts.defaultTurnOffDataShortcutName)
                turnOffDataShortcutName = sanitized
                CellularRefreshManager.shared.setTurnOffDataShortcutName(sanitized)
            }
        )
    }

    private func openTurnOnBaseDelayDialog() {
        editingValueText = turnOnBaseDelayText
        editDialog = EditDialogState(
            title: "开启基础延迟",
            message: "开启数据后的基础等待时间（秒，≥ 0）",
            placeholder: String(AppConstants.Shortcuts.defaultTurnOnDataBaseDelay),
            keyboardType: .decimalPad,
            onSave: { newValue in
                let filtered = newValue.filter { "0123456789.".contains($0) }
                if let delay = Double(filtered), delay >= 0 {
                    turnOnBaseDelayText = String(delay)
                    CellularRefreshManager.shared.setTurnOnDataBaseDelayOverride(delay)
                } else {
                    turnOnBaseDelayText = String(AppConstants.Shortcuts.defaultTurnOnDataBaseDelay)
                    CellularRefreshManager.shared.setTurnOnDataBaseDelayOverride(nil)
                }
            }
        )
    }

    private func openTurnOffBaseDelayDialog() {
        editingValueText = turnOffBaseDelayText
        editDialog = EditDialogState(
            title: "关闭基础延迟",
            message: "关闭数据后的基础等待时间（秒，≥ 0）",
            placeholder: String(AppConstants.Shortcuts.defaultTurnOffDataBaseDelay),
            keyboardType: .decimalPad,
            onSave: { newValue in
                let filtered = newValue.filter { "0123456789.".contains($0) }
                if let delay = Double(filtered), delay >= 0 {
                    turnOffBaseDelayText = String(delay)
                    CellularRefreshManager.shared.setTurnOffDataBaseDelayOverride(delay)
                } else {
                    turnOffBaseDelayText = String(AppConstants.Shortcuts.defaultTurnOffDataBaseDelay)
                    CellularRefreshManager.shared.setTurnOffDataBaseDelayOverride(nil)
                }
            }
        )
    }

    private func resetCellularDefaults() {
        CellularRefreshManager.shared.resetToDefaults()
        turnOnDataShortcutName = AppConstants.Shortcuts.defaultTurnOnDataShortcutName
        turnOffDataShortcutName = AppConstants.Shortcuts.defaultTurnOffDataShortcutName
        turnOnBaseDelayText = String(AppConstants.Shortcuts.defaultTurnOnDataBaseDelay)
        turnOffBaseDelayText = String(AppConstants.Shortcuts.defaultTurnOffDataBaseDelay)
    }

    private var customizeAppExtensionsBinding: Binding<AppExtensionCustomization> {
        Binding<AppExtensionCustomization>(
            get: { customizeAppExtensions },
            set: { newValue in
                customizeAppExtensions = newValue
                UserDefaults.standard.customizeAppExtensions = newValue
            }
        )
    }

    private var appImportSourceModeBinding: Binding<AppImportSourceMode> {
        Binding<AppImportSourceMode>(
            get: { appImportSourceMode },
            set: { newValue in
                appImportSourceMode = newValue
                UserDefaults.standard.appImportSourceMode = newValue
            }
        )
    }

    @ViewBuilder
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("通用")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.6))
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                toggleRow(title: "自定义 Info.plist", isOn: Binding(
                    get: { customizeInfoPlist },
                    set: { newValue in
                        customizeInfoPlist = newValue
                        UserDefaults.standard.customizeInfoPlist = newValue
                    }
                ))
                
                divider
                
                toggleRow(title: "自定义 AppID", isOn: Binding(
                    get: { customizeInfoPlist ? true : customizeAppId },
                    set: { newValue in
                        customizeAppId = newValue
                        UserDefaults.standard.customizeAppId = newValue
                    }
                ))
                .disabled(customizeInfoPlist)
                .opacity(customizeInfoPlist ? 0.4 : 1.0)
                
                divider
                
                HStack {
                    Text("自定义扩展")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Picker("", selection: customizeAppExtensionsBinding) {
                        ForEach(AppExtensionCustomization.allCases) { (option: AppExtensionCustomization) in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.white.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minHeight: 50)
                
                divider
                
                HStack {
                    Text("默认导入模式")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Picker("", selection: appImportSourceModeBinding) {
                        ForEach(AppImportSourceMode.allCases) { (option: AppImportSourceMode) in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.white.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minHeight: 50)
                
                divider

                toggleRow(
                    title: "确认应用安装",
                    subtitle: "安装或导入应用前弹出确认提示",
                    isOn: Binding(
                        get: { isInstallConfirmationEnabled },
                        set: { newValue in
                            isInstallConfirmationEnabled = newValue
                            UserDefaults.standard.isInstallConfirmationEnabled = newValue
                        }
                    )
                )
                
                divider

                toggleRow(
                    title: "卸载时清除自定义设置",
                    subtitle: "删除应用时重置已分配的描述文件、自定义证书和元数据",
                    isOn: Binding(
                        get: { isClearCustomizationsOnUninstallEnabled },
                        set: { newValue in
                            isClearCustomizationsOnUninstallEnabled = newValue
                            UserDefaults.standard.isClearCustomizationsOnUninstallEnabled = newValue
                        }
                    )
                )
                
                divider

                toggleRow(
                    title: "安装后自动启动应用",
                    subtitle: "安装完成后自动打开应用",
                    isOn: Binding(
                        get: { isAutoLaunchAppAfterInstallEnabled },
                        set: { newValue in
                            isAutoLaunchAppAfterInstallEnabled = newValue
                            UserDefaults.standard.isAutoLaunchAppAfterInstallEnabled = newValue
                        }
                    )
                )
                
                divider
                
                toggleRow(title: "自定义权限", isOn: Binding(
                    get: { customizeEntitlements },
                    set: { newValue in
                        customizeEntitlements = newValue
                        UserDefaults.standard.customizeEntitlements = newValue
                    }
                ))
                
                divider
                
                toggleRow(
                    title: "自动修正 App 组 ID",
                    subtitle: isFreeAccount ? "免费开发者账号所必需" : "自动修正 App Group 大小写不一致",
                    isOn: Binding(
                        get: { isFreeAccount ? true : autoFixAppGroupIDs },
                        set: { newValue in
                            guard !isFreeAccount else { return }
                            autoFixAppGroupIDs = newValue
                            UserDefaults.standard.autoFixAppGroupIDs = newValue
                        }
                    )
                )
                .disabled(isFreeAccount)

                divider

                toggleRow(
                    title: "自定义应用图标",
                    subtitle: "安装前提示选择自定义图标",
                    isOn: Binding(
                        get: { customizeAppIcon },
                        set: { newValue in
                            customizeAppIcon = newValue
                            UserDefaults.standard.customizeAppIcon = newValue
                        }
                    )
                )

                divider

                toggleRow(
                    title: "自定义描述文件",
                    subtitle: "安装前提示选择描述文件",
                    isOn: Binding(
                        get: { customizeProvisioningProfile },
                        set: { newValue in
                            customizeProvisioningProfile = newValue
                            UserDefaults.standard.customizeProvisioningProfile = newValue
                        }
                    )
                )
                
                divider
                
                toggleRow(
                    title: "优先使用重签 IPA",
                    subtitle: "在 IPA（速度）与应用包（存储）之间取舍",
                    isOn: Binding(
                        get: { preferResignedIPA },
                        set: { newValue in
                            pendingPreferIPAOngoing = newValue
                            showPreferIPAToggleAlert = true
                        }
                    )
                )
                
                divider
                
                toggleRow(title: "导出重签 IPA", isOn: Binding(
                    get: { isExportResignedAppEnabled },
                    set: { newValue in
                        isExportResignedAppEnabled = newValue
                        UserDefaults.standard.isExportResignedAppEnabled = newValue
                    }
                ))
                
                divider
                
                toggleRow(title: "跳过无法拷贝的备份文件", isOn: Binding(
                    get: { skipNonCopyableFiles },
                    set: { newValue in
                        skipNonCopyableFiles = newValue
                        UserDefaults.standard.skipNonCopyableBackupFiles = newValue
                    }
                ))
                
                divider
                
                toggleRow(
                    title: "Info.plist 优先使用表单",
                    subtitle: "使用表单而非对话框",
                    isOn: Binding(
                        get: { preferSheetForInfoPlistCustomization },
                        set: { newValue in
                            preferSheetForInfoPlistCustomization = newValue
                            UserDefaults.standard.preferSheetForInfoPlistCustomization = newValue
                        }
                    )
                )
                .disabled(!customizeInfoPlist)
                .opacity(!customizeInfoPlist ? 0.4 : 1.0)
                
                divider
                
                toggleRow(
                    title: "权限优先使用表单",
                    subtitle: "使用表单而非对话框",
                    isOn: Binding(
                        get: { preferSheetForEntitlementsCustomization },
                        set: { newValue in
                            preferSheetForEntitlementsCustomization = newValue
                            UserDefaults.standard.preferSheetForEntitlementsCustomization = newValue
                        }
                    )
                )
                .disabled(!customizeEntitlements)
                .opacity(!customizeEntitlements ? 0.4 : 1.0)
            }
            .background(Color.settingsRowBackground)
            .cornerRadius(14)
        }
    }



    private var divider: some View {
        Rectangle()
            .fill(Color.settingsDivider)
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    private func exportWireGuardConfig() {
        guard let url = Bundle.main.url(forResource: "SideStore", withExtension: "conf") else {
            if let top = UIApplication.shared.topViewController() {
                let toastView = ToastView(text: NSLocalizedString("缺少 SideStore.conf！", comment: ""), detailText: "无法在应用包资源中找到 SideStore.conf。")
                toastView.show(in: top)
            }
            return
        }
        wireGuardExportURL = url
    }

    private func presentResetAdiDialog() {
        guard let top = UIApplication.shared.topViewController() else { return }
        let alertController = UIAlertController(
            title: NSLocalizedString("重置 adi.pb", comment: ""),
            message: NSLocalizedString("这将使你在 SideStore 中退出 Apple ID 登录，并从钥匙串中清除已配置的 adi.pb 数据。当前签名证书将被保留。", comment: ""),
            preferredStyle: .alert
        )
        let contentVC = ResetAdiAlertViewController()
        alertController.setValue(contentVC, forKey: "contentViewController")
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: nil)
        let resetAction = UIAlertAction(title: NSLocalizedString("重置并退出登录", comment: ""), style: .destructive) { _ in
            let keepHeaders = contentVC.isKeepHeadersChecked
            Task {
                await AuthManager.shared.signOut(keepCertificate: true, keepAnisetteData: false, keepAnisetteHeaders: keepHeaders)
                debugLog("Reset adi.pb (keepAnisetteHeaders: \(keepHeaders)) and signed out")
                if let topVC = UIApplication.shared.topViewController() {
                    let detail = keepHeaders
                        ? NSLocalizedString("已退出 Apple ID 登录。你现在可以使用全新的配置重新登录。", comment: "")
                        : NSLocalizedString("已退出 Apple ID 登录。adi.pb 和请求头配置已重置为默认值。", comment: "")
                    ToastView(
                        text: NSLocalizedString("已清除 adi.pb！", comment: ""),
                        detailText: detail
                    ).show(in: topVC)
                }
            }
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(resetAction)
        top.present(alertController, animated: true, completion: nil)
    }

    private func applyBackendChange(_ newBackend: GatewayBackend, restartRequired: Bool) {
        selectedBackend = newBackend
        selectedGatewayBackendCache = newBackend
        UserDefaults.standard.minimuxerGatewayBackend = newBackend.rawValue
        UserDefaults.standard.synchronize()
        if restartRequired {
            exit(0)
        } else {
            syncMinimuxerBackendFromUserDefaults()
        }
    }
}
