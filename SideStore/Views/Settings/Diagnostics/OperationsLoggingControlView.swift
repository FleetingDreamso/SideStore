//
//  OperationsLoggingControlView.swift
//  SideStore
//
//  Created by Magesh K on 14/01/25.
//  Copyright © 2025 SideStore. All rights reserved.
//

import SwiftUI

private extension Color {
    static let settingsRowBackground = Color.white.opacity(0.15)
    static let settingsDivider = Color.white.opacity(0.15)
}

private let pipelineStepToggles: [(name: String, step: PipelineStep)] = [
    ("备份应用数据",                         .backupAppData),
    ("缓存应用",                               .cacheApp),
    ("更改应用图标",                         .changeAppIcon),
    ("清理暂存应用",                        .cleanStagedApp),
    ("停用应用",                          .deactivateApp),
    ("下载应用",                            .downloadApp),
    ("导出重签 IPA",                     .exportResignedIPA),
    ("获取描述文件",             .fetchProvisioningProfiles),
    ("安装应用",                             .installApp),
    ("预检",                        .preflightChecks),
    ("准备应用扩展 Bundle ID",        .prepareAppExtensionBundleIDs),
    ("刷新应用",                             .refreshApp),
    ("移除应用",                              .removeApp),
    ("移除应用扩展",                   .removeAppExtensions),
    ("移除备份数据",                      .removeBackupData),
    ("重签应用",                              .resignApp),
    ("恢复应用数据",                        .restoreAppData),
    ("发送应用",                                .sendApp),
    ("暂存应用",                               .stageApp),
    ("暂存备份应用",                        .stageBackupApp),
    ("更新应用证书",                  .updateAppCertificate),
    ("用户自定义",                      .userCustomization),
    ("验证应用",                              .verifyApp),
    ("验证证书",                      .verifyCertificate),
    ("创建 IPA",                              .createIPA),
]

private let standaloneStepToggles: [(name: String, step: StandaloneStep)] = [
    ("登录",                                 .signIn),
    ("后台刷新应用",                 .backgroundRefreshApps),
    ("清除应用缓存",                         .clearAppCache),
    ("启用 JIT",                              .enableJIT),
    ("同步 App ID",                            .syncAppIDs),
    ("获取源",                            .fetchSource),
    ("安排到期警告",             .scheduleExpirationWarningNotification),
]

struct OperationsLoggingControlView: View {
    @ObservedObject private var viewModel = OperationsLoggingViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Standalone Steps
                VStack(alignment: .leading, spacing: 8) {
                    Text("独立步骤")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        ForEach(Array(standaloneStepToggles.enumerated()), id: \.element.name) { index, entry in
                            if index > 0 {
                                divider
                            }
                            stepToggle(entry.name, step: entry.step)
                        }
                    }
                    .background(Color.settingsRowBackground)
                    .cornerRadius(14)
                }
                
                // Pipeline Steps
                VStack(alignment: .leading, spacing: 8) {
                    Text("管道步骤")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 0) {
                        ForEach(Array(pipelineStepToggles.enumerated()), id: \.element.name) { index, entry in
                            if index > 0 {
                                divider
                            }
                            stepToggle(entry.name, step: entry.step)
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
        .navigationTitle("操作日志")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    private func stepToggle(_ title: String, step: some OperationStep) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Toggle("", isOn: Binding(
                get: { OperationsLoggingControl.isStepLoggingEnabled(for: step) },
                set: { value in
                    OperationsLoggingControl.setStepLoggingEnabled(for: step, value: value)
                    viewModel.refresh()
                }
            ))
            .labelsHidden()
            .tint(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 50)
    }
    
    private var divider: some View {
        Rectangle()
            .fill(Color.settingsDivider)
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }
}

private final class OperationsLoggingViewModel: ObservableObject {
    func refresh() {
        objectWillChange.send()
    }
}
