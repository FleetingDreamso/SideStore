//
//  CodeResourcesViewer.swift
//  SideStore
//
//  Created by Magesh K on 3/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import SideSign

struct CodeResourceEntry: Identifiable {
    let id = UUID()
    let path: String
    let hashHex: String?
    let hash2Hex: String?
    let isOptional: Bool
    let weight: Double?
}

struct CodeResourceRule: Identifiable {
    let id = UUID()
    let pattern: String
    let isOmitted: Bool
    let weight: Double?
}

struct CodeResourcesViewer: View {
    let url: URL

    @State private var entries: [CodeResourceEntry] = []
    @State private var rules: [CodeResourceRule] = []
    @State private var rawPlist: [String: any Sendable]? = nil
    @State private var rawXML: String = ""
    @State private var isLoaded: Bool = false
    @State private var parseError: String? = nil
    @State private var searchQuery: String = ""
    @State private var filterMode: FilterMode = .all
    @State private var selectedEntry: CodeResourceEntry? = nil
    @State private var isShowingToast: Bool = false
    @State private var toastMessage: String = ""

    enum FilterMode: String, CaseIterable {
        case all = "全部"
        case required = "必需"
        case optional = "可选"
        case rules = "规则"
    }

    private var filteredEntries: [CodeResourceEntry] {
        var list = entries
        switch filterMode {
        case .all:
            break
        case .required:
            list = list.filter { !$0.isOptional }
        case .optional:
            list = list.filter { $0.isOptional }
        case .rules:
            return []
        }
        guard !searchQuery.isEmpty else { return list }
        return list.filter { $0.path.localizedCaseInsensitiveContains(searchQuery) }
    }

    private var filteredRules: [CodeResourceRule] {
        guard !searchQuery.isEmpty else { return rules }
        return rules.filter { $0.pattern.localizedCaseInsensitiveContains(searchQuery) }
    }

    var body: some View {
        List {
            if isLoaded && parseError == nil {
                Section(header: Text("代码签名封条")) {
                    InfoRow(label: "文件", value: url.lastPathComponent)
                    InfoRow(label: "已封存文件总数", value: "\(entries.count)")
                    InfoRow(label: "签名规则", value: "\(rules.count)")
                    let hasV2 = rawPlist?["files2"] != nil
                    InfoRow(label: "格式版本", value: hasV2 ? "版本 2（SHA-256）" : "版本 1（SHA-1）")
                }

                Section {
                    Picker("显示模式", selection: $filterMode) {
                        ForEach(FilterMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                if filterMode == .rules {
                    Section(header: Text("签名规则（\(filteredRules.count)）")) {
                        if filteredRules.isEmpty {
                            Text("没有匹配“\(searchQuery)”的规则")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(filteredRules) { rule in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(rule.pattern)
                                            .font(.system(size: 13, design: .monospaced))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if rule.isOmitted {
                                            Text("忽略")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.red.opacity(0.1))
                                                .cornerRadius(6)
                                        } else {
                                            Text("封存")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.green.opacity(0.1))
                                                .cornerRadius(6)
                                        }
                                    }
                                    if let w = rule.weight {
                                        Text("权重：\(String(format: "%.1f", w))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                } else {
                    Section(header: Text("已封存文件（\(filteredEntries.count)）")) {
                        if filteredEntries.isEmpty {
                            Text(entries.isEmpty ? "未找到已封存的文件" : "没有匹配“\(searchQuery)”的文件")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(filteredEntries) { entry in
                                SwiftUI.Button(action: {
                                    copyEntryInfo(entry)
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: fileIcon(for: entry.path))
                                            .font(.system(size: 16))
                                            .foregroundColor(.secondary)
                                            .frame(width: 20)

                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack {
                                                Text(entry.path)
                                                    .font(.system(size: 13, design: .monospaced))
                                                    .foregroundColor(.primary)
                                                Spacer()
                                                if entry.isOptional {
                                                    Text("可选")
                                                        .font(.caption2)
                                                        .foregroundColor(.orange)
                                                        .padding(.horizontal, 5)
                                                        .padding(.vertical, 1)
                                                        .background(Color.orange.opacity(0.12))
                                                        .cornerRadius(4)
                                                }
                                            }
                                            if let h2 = entry.hash2Hex {
                                                Text("SHA-256：\(h2)")
                                                    .font(.system(size: 10, design: .monospaced))
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                                    .truncationMode(.middle)
                                            } else if let h1 = entry.hashHex {
                                                Text("SHA-1：\(h1)")
                                                    .font(.system(size: 10, design: .monospaced))
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                                    .truncationMode(.middle)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                }

                if let plist = rawPlist {
                    Section(header: Text("原始检查")) {
                        NavigationLink(destination: InfoPlistContainerView(plist: plist, title: "CodeResources")) {
                            HStack {
                                Image(systemName: "list.bullet.rectangle")
                                    .foregroundColor(.green)
                                Text("浏览结构（\(plist.count) 个键）")
                                    .font(.subheadline)
                            }
                        }

                        if !rawXML.isEmpty {
                            NavigationLink(destination: ResourceTextViewer(title: "CodeResources XML", explicitContent: rawXML)) {
                                HStack {
                                    Image(systemName: "doc.plaintext")
                                        .foregroundColor(.blue)
                                    Text("查看原始 XML")
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                }
            } else if let err = parseError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 44))
                        .foregroundColor(.orange)
                    Text("解析错误")
                        .font(.headline)
                    Text(err)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView("正在读取 CodeResources...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        #if !os(tvOS)
        .listStyle(InsetGroupedListStyle())
        .navigationBarTitleDisplayMode(.inline)
        #else
        .listStyle(GroupedListStyle())
        #endif
        .navigationTitle(url.lastPathComponent)
        .searchable(text: $searchQuery, prompt: "搜索已封存的文件或规则")
        .overlay(
            AppInfoToastView(isShowing: $isShowingToast, message: toastMessage)
        )
        .onAppear {
            guard !isLoaded else { return }
            loadCodeResources()
        }
    }

    private func loadCodeResources() {
        guard let data = try? Data(contentsOf: url) else {
            self.parseError = "无法读取 \(url.path) 处的文件内容。"
            self.isLoaded = true
            return
        }

        if let str = String(data: data, encoding: .utf8) {
            self.rawXML = str
        }

        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: any Sendable] else {
            self.parseError = "无法将文件解码为属性列表。"
            self.isLoaded = true
            return
        }

        self.rawPlist = plist

        var parsedEntries: [CodeResourceEntry] = []
        if let files2 = (plist["files2"] as? [String: any Sendable]) ?? (plist["files2"] as? [String: Any]) {
            for (path, val) in files2 {
                if let dict = (val as? [String: any Sendable]) ?? (val as? [String: Any]) {
                    let hashData = dict["hash"] as? Data
                    let hash2Data = dict["hash2"] as? Data
                    let opt = dict["optional"] as? Bool ?? false
                    let weight = dict["weight"] as? Double
                    parsedEntries.append(CodeResourceEntry(
                        path: path,
                        hashHex: hashData?.map { String(format: "%02x", $0) }.joined(),
                        hash2Hex: hash2Data?.map { String(format: "%02x", $0) }.joined(),
                        isOptional: opt,
                        weight: weight
                    ))
                } else if let hashData = val as? Data {
                    parsedEntries.append(CodeResourceEntry(
                        path: path,
                        hashHex: hashData.map { String(format: "%02x", $0) }.joined(),
                        hash2Hex: nil,
                        isOptional: false,
                        weight: nil
                    ))
                }
            }
        } else if let files = (plist["files"] as? [String: any Sendable]) ?? (plist["files"] as? [String: Any]) {
            for (path, val) in files {
                if let dict = (val as? [String: any Sendable]) ?? (val as? [String: Any]) {
                    let hashData = dict["hash"] as? Data
                    let opt = dict["optional"] as? Bool ?? false
                    parsedEntries.append(CodeResourceEntry(
                        path: path,
                        hashHex: hashData?.map { String(format: "%02x", $0) }.joined(),
                        hash2Hex: nil,
                        isOptional: opt,
                        weight: nil
                    ))
                } else if let hashData = val as? Data {
                    parsedEntries.append(CodeResourceEntry(
                        path: path,
                        hashHex: hashData.map { String(format: "%02x", $0) }.joined(),
                        hash2Hex: nil,
                        isOptional: false,
                        weight: nil
                    ))
                }
            }
        }

        self.entries = parsedEntries.sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }

        var parsedRules: [CodeResourceRule] = []
        let rulesDict = (plist["rules2"] as? [String: any Sendable]) ?? (plist["rules"] as? [String: any Sendable]) ?? (plist["rules2"] as? [String: Any]) ?? (plist["rules"] as? [String: Any]) ?? [:]
        for (pattern, val) in rulesDict {
            if let dict = (val as? [String: any Sendable]) ?? (val as? [String: Any]) {
                let omit = dict["omit"] as? Bool ?? false
                let weight = dict["weight"] as? Double
                parsedRules.append(CodeResourceRule(pattern: pattern, isOmitted: omit, weight: weight))
            } else if let boolVal = val as? Bool {
                parsedRules.append(CodeResourceRule(pattern: pattern, isOmitted: !boolVal, weight: nil))
            } else if let weight = val as? Double {
                parsedRules.append(CodeResourceRule(pattern: pattern, isOmitted: false, weight: weight))
            }
        }
        self.rules = parsedRules.sorted { ($0.weight ?? 0) > ($1.weight ?? 0) }
        self.isLoaded = true
    }

    private func copyEntryInfo(_ entry: CodeResourceEntry) {
        let textToCopy = entry.hash2Hex ?? entry.hashHex ?? entry.path
        #if !os(tvOS)
        UIPasteboard.general.string = textToCopy
        #endif
        self.toastMessage = "已将 \(entry.path.components(separatedBy: "/").last ?? entry.path) 拷贝到剪贴板"
        withAnimation {
            self.isShowingToast = true
        }
    }

    private func fileIcon(for path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "gif", "webp", "tiff", "heic", "bmp", "ico": return "photo"
        case "plist": return "list.bullet.rectangle"
        case "dylib", "so", "a": return "cpu"
        case "nib", "xib", "storyboard": return "rectangle.on.rectangle"
        case "strings", "stringsdict": return "textformat"
        case "car": return "paintpalette"
        default: return "doc"
        }
    }
}
