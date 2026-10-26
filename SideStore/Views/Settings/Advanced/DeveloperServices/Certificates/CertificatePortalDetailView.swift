//
//  CertificatePortalDetailView.swift
//  SideStore
//
//  Created by Magesh K on 8/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import SideSign

struct CertificatePortalDetailView: View {
    let certificate: ALTX509Certificate
    @ObservedObject var viewModel: DeveloperServicesViewModel
    weak var presentingViewController: UIViewController?
    @Environment(\.presentationMode) var presentationMode

    @State private var showRevokeAlert = false

    private var isExpired: Bool {
        certificate.expiryDate < Date()
    }

    var body: some View {
        List {
            Section(header: Text("证书详情")) {
                InfoRow(label: "名称", value: certificate.name)
                InfoRow(label: "序列号", value: certificate.serialNumber)
                if let identifier = certificate.identifier {
                    InfoRow(label: "证书 ID", value: identifier)
                }
                if let certType = certificate.certificateType {
                    InfoRow(label: "证书类型", value: certType)
                }
                if let typeName = certificate.certificateTypeName {
                    InfoRow(label: "类型名称", value: typeName)
                }
                if let managed = certificate.isManaged {
                    InfoRow(label: "受管理", value: managed ? "是（Xcode Cloud）" : "否")
                }
                if let platform = certificate.platform {
                    InfoRow(label: "平台", value: platform)
                }
                if let machineName = certificate.machineName {
                    InfoRow(label: "机器名称", value: machineName)
                }
                if let machineIdentifier = certificate.machineIdentifier {
                    InfoRow(label: "机器标识符", value: machineIdentifier)
                }
                if let createdBy = certificate.requesterFirstName {
                    InfoRow(label: "创建者", value: createdBy)
                }
                if let email = certificate.requesterEmail {
                    InfoRow(label: "请求者邮箱", value: email)
                }
                if let teamName = viewModel.team?.name {
                    InfoRow(label: "团队名称", value: teamName)
                }
                if let teamID = viewModel.team?.identifier {
                    InfoRow(label: "团队标识符", value: teamID)
                }
                InfoRow(label: "创建日期", value: formatDate(certificate.creationDate))
                InfoRow(label: "到期日期", value: formatDate(certificate.expiryDate), valueColor: isExpired ? .red : .primary)
                InfoRow(label: "状态", value: isExpired ? "已过期" : "已激活", valueColor: isExpired ? .red : .green)
            }

            Section(footer: Text("吊销证书会在 Apple 的服务器上永久使其失效。仅绑定该证书的描述文件可能需要重新生成。")) {
                SwiftUI.Button(role: .destructive) {
                    showRevokeAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "trash")
                        Text("在开发者后台中吊销证书")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }
        }
        #if !os(tvOS)
        .listStyle(InsetGroupedListStyle())
        #else
        .listStyle(GroupedListStyle())
        #endif
        .navigationTitle(certificate.name)
        .refreshable {
            await viewModel.fetchCertificates(presentingViewController: presentingViewController, isPullToRefresh: true)
        }
        .alert(isPresented: $showRevokeAlert) {
            Alert(
                title: Text("吊销证书？"),
                message: Text("确定要在 Apple 开发者后台中吊销“\(certificate.name)”吗？此操作无法撤销。"),
                primaryButton: .destructive(Text("吊销")) {
                    Task {
                        let success = await viewModel.revokeCertificate(certificate, presentingViewController: presentingViewController)
                        if success {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
