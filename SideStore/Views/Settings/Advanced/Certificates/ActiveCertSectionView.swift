//
//  ActiveCertSectionView.swift
//  SideStore
//
//  Created by Magesh K on 2026-07-03.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import SideSign

struct ActiveCertSectionView: View {
    @ObservedObject var viewModel: CertificatesViewModel
    @Binding var hasCopiedActiveSerial: Bool
    var onDeactivate: () -> Void
    
    var body: some View {
        Section("当前本地证书") {
            if let activeSerial = viewModel.activeSerialNumber {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        HStack(spacing: 6) {
                            Text("当前签名证书").font(.headline)
                            
                            #if !os(tvOS)
                            SwiftUI.Button {
                                UIPasteboard.general.string = activeSerial
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                hasCopiedActiveSerial = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { hasCopiedActiveSerial = false }
                            } label: {
                                Image(systemName: hasCopiedActiveSerial ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 13))
                                    .foregroundColor(hasCopiedActiveSerial ? .green : .secondary)
                            }
                            .buttonStyle(.plain)
                            #endif
                        }
                        
                        let displaySerial = viewModel.displayActiveSerial(activeSerial)
                        (
                            Text("序列号：").font(.footnote)
                            + Text(displaySerial).font(.system(size: 13, design: .monospaced))
                        )
                        .foregroundColor(.secondary)
                        #if !os(tvOS)
                        .onTapGesture {
                            let key = "active_" + activeSerial
                            if viewModel.revealedSerials.contains(key) { viewModel.revealedSerials.remove(key) }
                            else { viewModel.revealedSerials.insert(key) }
                        }
                        #endif
                        
                        if viewModel.isActiveCertThirdParty {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.footnote)
                                Text("自定义第三方证书（其他团队）")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(.top, 2)
                        }
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .contextMenu {
                    let key      = "active_" + activeSerial
                    let isMasked = viewModel.isActiveSerialMasked(activeSerial)
                    SwiftUI.Button {
                        if viewModel.revealedSerials.contains(key) { viewModel.revealedSerials.remove(key) }
                        else { viewModel.revealedSerials.insert(key) }
                    } label: {
                        Label(isMasked ? "显示详情" : "隐藏详情",
                              systemImage: isMasked ? "eye" : "eye.slash")
                    }
                    #if !os(tvOS)
                    SwiftUI.Button { UIPasteboard.general.string = activeSerial } label: {
                        Label("拷贝序列号", systemImage: "doc.on.doc")
                    }
                    #endif
                }
                
                HStack {
                    Image(systemName: "checkmark.seal.fill").font(.title2).opacity(0)
                    SwiftUI.Button(role: .destructive) { onDeactivate() } label: {
                        Text("在本地停用").fontWeight(.medium)
                    }
                }
            } else {
                Text(viewModel.team == nil
                     ? "未找到当前本地证书。请导入 .p12 文件来为应用签名。"
                     : "未找到当前本地证书。请创建新证书或导入 .p12 文件来为应用签名。")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
    }
}
