//
//  MachOResourceViewer.swift
//  SideStore
//
//  Created by Magesh K on 3/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import SideSign
import CodeSignKit

struct MachOResourceViewer: View {
    let url: URL

    @State private var parser: MachOParser? = nil
    @State private var dumpText: String = ""
    @State private var isLoaded = false
    @State private var showingShareSheet = false

    var body: some View {
        List {
            if let parser = parser {
                Section(header: Text("二进制摘要")) {
                    InfoRow(label: "名称", value: url.lastPathComponent)
                    InfoRow(label: "路径", value: url.path)
                    InfoRow(label: "大小", value: formatSize(url))

                    let archs = parser.architectures()
                    InfoRow(label: "架构", value: archs.isEmpty ? "未知" : archs.joined(separator: ", "))

                    if let platform = parser.platformType() {
                        InfoRow(label: "平台", value: platform)
                    }

                    if let minOS = parser.minimumOSVersion() {
                        InfoRow(label: "最低系统版本", value: minOS)
                    }

                    InfoRow(
                        label: "已加密（DRM）",
                        value: parser.isEncrypted() ? "是" : "否",
                        valueColor: parser.isEncrypted() ? .orange : .green
                    )

                    if let bundleID = parser.bundleIdentifier() {
                        InfoRow(label: "Bundle ID", value: bundleID)
                    }

                    if let teamID = parser.teamID() {
                        InfoRow(label: "团队 ID", value: teamID)
                    }

                    if let entryOff = parser.entryPoint() {
                        InfoRow(label: "入口点", value: String(format: "0x%llX", entryOff))
                    }

                    let cdHashes = parser.getCDHashes()
                    if !cdHashes.isEmpty {
                        InfoRow(label: "CDHash", value: cdHashes.joined(separator: "\n"))
                    }
                }

                let x509Certs = parser.x509Certificates()
                if !x509Certs.isEmpty {
                    Section(header: Text("签名与证书（\(x509Certs.count)）")) {
                        ForEach(Array(x509Certs.enumerated()), id: \.offset) { index, cert in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(cert.name)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text("序列号：\(cert.serialNumber)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if cert.expiryDate != Date.distantPast {
                                    Text("到期时间：\(formatDate(cert.expiryDate))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                if let ent = try? parser.entitlements(), !ent.isEmpty {
                    Section(header: Text("权限")) {
                        NavigationLink(destination: ResourceTextViewer(title: "权限", explicitContent: ent)) {
                            HStack {
                                Image(systemName: "lock.doc.fill")
                                    .foregroundColor(.green)
                                Text("内嵌权限")
                                    .font(.subheadline)
                                Spacer()
                                Text("XML")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                let libs = parser.linkedLibraries()
                if !libs.isEmpty {
                    Section(header: Text("链接的库（\(libs.count)）")) {
                        ForEach(libs, id: \.self) { lib in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "cpu")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 2)
                                Text(lib)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                let segs = parser.segments()
                if !segs.isEmpty {
                    Section(header: Text("段（\(segs.count)）")) {
                        ForEach(segs, id: \.name) { seg in
                            HStack {
                                Text(seg.name)
                                    .font(.system(size: 13, design: .monospaced))
                                    .fontWeight(.medium)
                                Spacer()
                                Text("偏移：\(String(format: "0x%llX", seg.offset))  大小：\(ByteCountFormatter.string(fromByteCount: Int64(seg.size), countStyle: .file))")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section(header: Text("原始转储")) {
                    NavigationLink(destination: ResourceTextViewer(title: "Mach-O 转储", explicitContent: dumpText)) {
                        HStack {
                            Image(systemName: "doc.plaintext.fill")
                                .foregroundColor(.blue)
                            Text("查看完整 Mach-O 转储")
                                .font(.subheadline)
                        }
                    }
                }
            } else if isLoaded {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 44))
                        .foregroundColor(.orange)
                    Text("Mach-O 二进制文件无效")
                        .font(.headline)
                    Text("无法将 \(url.lastPathComponent) 解析为有效的 Mach-O 二进制文件。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView("正在解析 Mach-O……")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        #if !os(tvOS)
        .listStyle(InsetGroupedListStyle())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !dumpText.isEmpty {
                    SwiftUI.Button {
                        showingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivityViewController(items: [dumpText])
        }
        #else
        .listStyle(GroupedListStyle())
        #endif
        .navigationTitle(url.lastPathComponent)
        .onAppear {
            guard !isLoaded else { return }
            isLoaded = true
            loadMachO()
        }
    }

    private func loadMachO() {
        guard let p = try? MachOParser(url: url) else { return }
        self.parser = p
        self.dumpText = generateDumpText(p)
    }

    private func generateDumpText(_ p: MachOParser) -> String {
        var info = "--- Mach-O 二进制信息：\(url.lastPathComponent) ---\n"
        info += "路径：\(url.path)\n"
        info += "大小：\(formatSize(url))\n"
        info += "架构：\(p.architectures().joined(separator: ", "))\n"
        if let platform = p.platformType() {
            info += "平台：\(platform)\n"
        }
        if let minOS = p.minimumOSVersion() {
            info += "最低系统版本：\(minOS)\n"
        }
        info += "已加密（DRM）：\(p.isEncrypted() ? "是" : "否")\n"
        if let bundleID = p.bundleIdentifier() {
            info += "Bundle ID：\(bundleID)\n"
        }
        if let teamID = p.teamID() {
            info += "团队 ID：\(teamID)\n"
        }
        if let entry = p.entryPoint() {
            info += "入口点：\(String(format: "0x%llX", entry))\n"
        }
        let cdHashes = p.getCDHashes()
        if !cdHashes.isEmpty {
            info += "CDHashes:\n"
            for hash in cdHashes {
                info += "  \(hash)\n"
            }
        }

        let certs = p.certificates()
        if !certs.isEmpty {
            info += "证书（\(certs.count)）：\n"
            for (index, cert) in certs.enumerated() {
                let subject = X509Certificate(der: cert)?.name ?? "证书 \(index + 1)（\(cert.count) 字节）"
                info += "  [\(index)] \(subject)\n"
            }
        }

        let libs = p.linkedLibraries()
        if !libs.isEmpty {
            info += "链接的库（\(libs.count)）：\n"
            for lib in libs {
                info += "  - \(lib)\n"
            }
        }

        let segs = p.segments()
        if !segs.isEmpty {
            info += "段（\(segs.count)）：\n"
            for seg in segs {
                info += "  - \(seg.name)（偏移：\(String(format: "0x%llX", seg.offset))，大小：\(ByteCountFormatter.string(fromByteCount: Int64(seg.size), countStyle: .file))）\n"
            }
        }

        if let ent = try? p.entitlements(), !ent.isEmpty {
            info += "\n--- 内嵌权限 ---\n"
            info += ent
            info += "\n"
        }

        info += "----------------------------------------"
        return info
    }

    private func formatSize(_ url: URL) -> String {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
