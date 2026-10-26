//
//  CertificatesView.swift
//  SideStore
//
//  Created by Magesh K on 2026-06-29.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import SideSign
import UniformTypeIdentifiers

struct CertificatesView: View {
    weak var presentingViewController: UIViewController?
    
    @StateObject private var viewModel = CertificatesViewModel()
    
    private var allowedImportTypes: [UTType] {
        ["p12", "pfx", "pkcs12", "der", "cer", "crt", "pem"].compactMap { UTType(filenameExtension: $0) }
    }
    private var allowedKeyImportTypes: [UTType] {
        ["key", "pem", "der"].compactMap { UTType(filenameExtension: $0) }
    }
    
    @State private var showCreateSheet            = false
    @State private var showFileImporter           = false
    @State private var showRevokeConfirmation     = false
    @State private var showDeactivateConfirmation = false
    @State private var showDeleteConfirmation     = false
    @State private var showExportPasswordPrompt   = false
    @State private var showClearKeyConfirmation   = false
    @State private var hasInitialLoaded           = false
    @State private var hasCopiedActiveSerial      = false
    
    @State private var exportPasswordInput   = ""
    @State private var fileImportMode: FileImportMode       = .certificate
    @State private var keyTextImportItem: KeyTextImportItem? = nil
    @State private var privateKeyTextInput   = ""
    
    @State private var deleteLocalOnRevoke: Bool = true
    
    @State private var certificateToRevoke:      ALTX509Certificate? = nil
    @State private var certificateToDelete:      ALTX509Certificate? = nil
    @State private var certificateToExport:      ALTX509Certificate? = nil
    @State private var certificateToAddKeyFor:   ALTX509Certificate? = nil
    @State private var certificateToClearKeyFor: ALTX509Certificate? = nil
    
    var body: some View {
        ZStack {
            List {
                ActiveCertSectionView(
                    viewModel: viewModel,
                    hasCopiedActiveSerial: $hasCopiedActiveSerial,
                    onDeactivate: { showDeactivateConfirmation = true }
                )
                CertificatesListView(
                    viewModel: viewModel,
                    onRowTap:     { pushDetailView(for: $0) },
                    onRevoke:     { presentRevokeAlert(for: $0) },
                    onExportP12:  { cert in
                        certificateToExport = cert
                        exportPasswordInput = ""
                        showExportPasswordPrompt = true
                    },
                    onClearKey:   { cert in
                        certificateToClearKeyFor = cert
                        showClearKeyConfirmation = true
                    },
                    onAddKeyBin:  { cert in
                        importPrivateKeyAction(for: cert)
                    },
                    onAddKeyText: { cert in
                        keyTextImportItem = KeyTextImportItem(id: cert.serialNumber, cert: cert)
                    },
                    onDelete: { certificateToDelete = $0; showDeleteConfirmation = true }
                )
            }
            .refreshable {
                await withCheckedContinuation { continuation in
                    viewModel.loadCertificates(presentingViewController: presentingViewController, isPullToRefresh: true) {
                        continuation.resume()
                    }
                }
            }
            .navigationTitle("证书")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    SwiftUI.Button {
                        viewModel.isGlobalHideActive.toggle()
                    } label: {
                        Image(systemName: viewModel.isGlobalHideActive ? "eye.slash" : "eye")
                    }
                    .accessibilityLabel("切换隐藏敏感信息")
                    
                    SwiftUI.Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("创建证书")
                    .disabled(viewModel.team == nil)
                    
                    SwiftUI.Button {
                        importCertificatesAction()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel("导入证书")
                }
            }
            .onAppear {
                guard !hasInitialLoaded else { return }
                hasInitialLoaded = true
                viewModel.loadCertificates(presentingViewController: nil)
            }
            
            if viewModel.isLoading { LoadingOverlay() }
        }
        .alert("错误", isPresented: $viewModel.showErrorAlert) {
            SwiftUI.Button("好", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "发生了未知错误。")
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateCertificateSheetView(
                viewModel: viewModel,
                presentingViewController: presentingViewController,
                isPresented: $showCreateSheet
            )
        }
        .alert("停用证书", isPresented: $showDeactivateConfirmation) {
            SwiftUI.Button("停用", role: .destructive) { viewModel.deactivateActiveCertificate() }
            SwiftUI.Button("取消", role: .cancel) {}
        } message: {
            Text("确定要在本地停用当前签名证书吗？")
        }
        .alert("删除证书", isPresented: $showDeleteConfirmation) {
            SwiftUI.Button("删除", role: .destructive) {
                if let cert = certificateToDelete { viewModel.deleteCertificate(cert) }
            }
            SwiftUI.Button("取消", role: .cancel) {}
        } message: {
            Text("确定要在本地删除此证书吗？这会将其从本地缓存中移除。")
        }
        .alert("输入导入证书的密码", isPresented: $viewModel.showPasswordPromptForImport) {
            SecureField("密码", text: $viewModel.importPasswordInput)
            SwiftUI.Button("导入") { viewModel.submitImportPassword() }
            SwiftUI.Button("取消", role: .cancel) { viewModel.cancelImport() }
        } message: {
            Text("输入用于解密所导入证书文件的密码。\n\n文件：\(viewModel.currentImportFilename)")
        }
        .alert("成功", isPresented: $viewModel.showAlert) {
            SwiftUI.Button("好", role: .cancel) { viewModel.alertMessage = nil }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .alert("导入摘要", isPresented: $viewModel.showImportSummary) {
            if viewModel.importFailedCount > 0 {
                SwiftUI.Button("显示失败项") {
                    DispatchQueue.main.async {
                        viewModel.showFailuresAlert = true
                    }
                }
                SwiftUI.Button("好", role: .cancel) {}
            } else {
                SwiftUI.Button("好", role: .cancel) {}
            }
        } message: {
            Text(viewModel.importSummaryMessage)
        }
        .sheet(isPresented: $viewModel.showFailuresAlert) {
            NavigationView {
                List {
                    ForEach(viewModel.failedImportsList, id: \.self) { failure in
                        Text(failure)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.red)
                    }
                }
                .navigationTitle("导入失败项")
                #if !os(tvOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        SwiftUI.Button("完成") {
                            viewModel.showFailuresAlert = false
                        }
                    }
                }
            }
        }
        .alert("导出证书密码", isPresented: $showExportPasswordPrompt) {
            SecureField("密码", text: $exportPasswordInput)
            SwiftUI.Button("导出") {
                if let cert = certificateToExport, let signable = viewModel.getSignableCertificate(for: cert.serialNumber) {
                    CertificateExporter.shareP12(signable, password: exportPasswordInput, onShare: { viewModel.shareURL = $0 }) { viewModel.errorMessage = $0 }
                }
            }
            SwiftUI.Button("取消", role: .cancel) {}
        } message: {
            Text("设置一个密码以加密导出的 .p12 证书文件。")
        }
        .alert("清除私钥", isPresented: $showClearKeyConfirmation) {
            if let cert = certificateToClearKeyFor {
                SwiftUI.Button("清除私钥", role: .destructive) {
                    viewModel.clearPrivateKey(for: cert)
                    certificateToClearKeyFor = nil
                }
            }
            SwiftUI.Button("取消", role: .cancel) { certificateToClearKeyFor = nil }
        } message: {
            if let cert = certificateToClearKeyFor {
                Text("这会清除此证书在本地存储的私钥。\n\n名称：\(cert.name)\n序列号：\(cert.serialNumber)")
            }
        }
        #if !os(tvOS)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: fileImportMode == .certificate ? allowedImportTypes : allowedKeyImportTypes,
            allowsMultipleSelection: fileImportMode == .certificate
        ) { result in
            switch result {
            case .success(let urls):
                switch fileImportMode {
                case .certificate:
                    viewModel.startBulkImport(urls: urls)
                case .privateKey:
                    if let url = urls.first, let cert = certificateToAddKeyFor {
                        _ = url.startAccessingSecurityScopedResource()
                        defer { url.stopAccessingSecurityScopedResource() }
                        do {
                            viewModel.importPrivateKey(data: try Data(contentsOf: url), for: cert)
                        } catch {
                            viewModel.errorMessage = "读取私钥失败：" + error.localizedDescription
                        }
                    }
                }
            case .failure(let error):
                let type = fileImportMode == .certificate ? "files" : "私钥"
                viewModel.errorMessage = "选择\(type)失败：" + error.localizedDescription
            }
        }
        #endif
        .sheet(item: $keyTextImportItem) { item in
            PrivateKeyTextInputView(
                text: $privateKeyTextInput,
                cert: item.cert,
                viewModel: viewModel,
                allowedKeyImportTypes: allowedKeyImportTypes,
                onCancel: {
                    keyTextImportItem = nil
                    privateKeyTextInput = ""
                }
            )
        }
        .sheet(isPresented: Binding<Bool>(
            get: { viewModel.shareURL != nil },
            set: { if !$0 { viewModel.shareURL = nil } }
        )) {
            if let url = viewModel.shareURL {
                ActivityViewController(activityItems: [url])
            }
        }
    }
    
    private func pushDetailView(for cert: ALTX509Certificate) {
        let metadata = DeveloperPortalMetadata(
            identifier: cert.identifier,
            machineName: cert.machineName,
            machineIdentifier: cert.machineIdentifier,
            requesterEmail: cert.requesterEmail,
            requesterFirstName: cert.requesterFirstName,
            requesterLastName: cert.requesterLastName,
            displayName: cert.displayName,
            certificateType: cert.certificateType,
            certificateTypeName: cert.certificateTypeName,
            certificateTypeId: cert.certificateTypeId,
            platform: cert.platform,
            platformName: cert.platformName,
            isManaged: cert.isManaged,
            status: cert.status,
            ownerName: cert.ownerName,
            ownerId: cert.ownerId,
            autoRotationEnabled: cert.autoRotationEnabled,
            requestedDate: cert.requestedDate,
            serialNumDecimal: cert.serialNumDecimal
        )
        let detailVC = UIHostingController(rootView: CertificateDetailView(certificate: cert, portalMetadata: metadata, viewModel: viewModel))
        #if !os(tvOS)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        detailVC.navigationItem.scrollEdgeAppearance = appearance
        detailVC.navigationItem.standardAppearance   = appearance
        #endif
        presentingViewController?.navigationController?.pushViewController(detailVC, animated: true)
    }
    
    private func presentRevokeAlert(for cert: ALTX509Certificate) {
        let contentVC = RevokeAlertViewController()
        
        let alertController = UIAlertController(
            title: NSLocalizedString("吊销证书", comment: ""),
            message: NSLocalizedString("确定要吊销此证书吗？这将在 Apple 的服务器上永久删除该证书。", comment: ""),
            preferredStyle: .alert
        )
        
        alertController.setValue(contentVC, forKey: "contentViewController")
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: nil)
        let revokeAction = UIAlertAction(title: NSLocalizedString("吊销", comment: ""), style: .destructive) { _ in
            let keepLocal = contentVC.isKeepLocalChecked
            viewModel.revokeCertificate(cert, keepLocal: keepLocal, presentingViewController: presentingViewController)
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(revokeAction)
        
        presentingViewController?.present(alertController, animated: true)
    }
    
    private func importPrivateKeyAction(for cert: ALTX509Certificate) {
        certificateToAddKeyFor = cert
        fileImportMode = .privateKey
        #if !os(tvOS)
        showFileImporter = true
        #else
        guard let topVC = presentingViewController ?? UIApplication.shared.topViewController() else { return }
        TVWebFileTransferManager.shared.startImport(
            acceptedExtensions: ["der", "key", "pem", "p12"],
            title: "导入私钥（.der/.pem）",
            presentingVC: topVC
        ) { fileURL in
            guard let fileURL = fileURL else { return }
            do {
                let data = try Data(contentsOf: fileURL)
                viewModel.importPrivateKey(data: data, for: cert)
            } catch {
                viewModel.errorMessage = "读取私钥失败：" + error.localizedDescription
            }
            certificateToAddKeyFor = nil
        }
        #endif
    }
    
    private func importCertificatesAction() {
        fileImportMode = .certificate
        #if !os(tvOS)
        showFileImporter = true
        #else
        guard let topVC = presentingViewController ?? UIApplication.shared.topViewController() else { return }
        TVWebFileTransferManager.shared.startImport(
            acceptedExtensions: ["p12", "der", "pem", "cer", "crt"],
            title: "导入证书",
            presentingVC: topVC
        ) { fileURL in
            guard let fileURL = fileURL else { return }
            viewModel.startBulkImport(urls: [fileURL])
        }
        #endif
    }
}

private struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
            ProgressView()
                .padding(20)
                #if !os(tvOS)
                .background(Color(.secondarySystemBackground))
                #else
                .background(Color.white.opacity(0.1))
                #endif
                .cornerRadius(10)
        }
    }
}

private struct CreateCertificateSheetView: View {
    @ObservedObject var viewModel: CertificatesViewModel
    var presentingViewController: UIViewController?
    @Binding var isPresented: Bool

    @State private var machineName: String = "SideStore - \(UIDevice.current.name)"
    @State private var selectedCertificateType: CertificateType = .development

    private var isPaidWarningVisible: Bool {
        selectedCertificateType.isPaidOnly && !viewModel.isPaidAccount
    }

    private var canCreate: Bool {
        !machineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                Section(
                    header: Text("证书信息"),
                    footer: Text(isPaidWarningVisible
                        ? "此证书类型需要付费的 Apple 开发者账号。"
                        : "选择证书类型和机器名称。这会在 Apple 的服务器上注册证书，并将私钥保存在本地。")
                ) {
                    Picker("证书类型", selection: $selectedCertificateType) {
                        ForEach(viewModel.availableCertificateTypes, id: \.rawValue) { certType in
                            Text(certType.displayName).tag(certType)
                        }
                    }

                    TextField("机器名称", text: $machineName)
                }
            }
            .navigationTitle("新证书")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SwiftUI.Button("取消") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    SwiftUI.Button("创建") {
                        let name = machineName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        isPresented = false
                        viewModel.createCertificate(
                            machineName: name,
                            type: selectedCertificateType,
                            presentingViewController: presentingViewController
                        )
                    }
                    .disabled(!canCreate)
                }
            }
        }
    }
}
