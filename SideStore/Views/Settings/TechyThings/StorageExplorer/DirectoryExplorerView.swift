//
//  DirectoryExplorerView.swift
//  SideStore
//
//  Created by Magesh K on 3/8/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import Combine

// MARK: - Directory Explorer View

public struct DirectoryExplorerView: View {
    @StateObject private var viewModel: StorageExplorerViewModel
    @ObservedObject private var clipboard = StorageExplorerClipboard.shared
    public var onSelectFolder: ((URL) -> Void)?
    
    public init(url: URL, onSelectFolder: ((URL) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: StorageExplorerViewModel(url: url))
        self.onSelectFolder = onSelectFolder
    }
    
    private var folderSummaryString: String {
        let items = viewModel.filteredAndSortedItems
        if items.isEmpty {
            return "0 项（0 KB）"
        }
        let folders = items.filter { $0.isDirectory }
        let files = items.filter { !$0.isDirectory }
        let sizeStr = ByteCountFormatter.string(fromByteCount: viewModel.currentFolderSize, countStyle: .file)
        
        if !folders.isEmpty && !files.isEmpty {
            let folderLabel = folders.count == 1 ? "1 个文件夹" : "\(folders.count) 个文件夹"
            let fileLabel = files.count == 1 ? "1 个文件" : "\(files.count) 个文件"
            return "\(folderLabel)，\(fileLabel)（\(sizeStr)）"
        } else if !folders.isEmpty {
            let folderLabel = folders.count == 1 ? "1 个文件夹" : "\(folders.count) 个文件夹"
            return "\(folderLabel)（\(sizeStr)）"
        } else {
            let fileLabel = files.count == 1 ? "1 个文件" : "\(files.count) 个文件"
            return "\(fileLabel)（\(sizeStr)）"
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                Spacer()
                
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                    Text("正在加载目录内容…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Spacer()
            } else if viewModel.filteredAndSortedItems.isEmpty {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.minus")
                        .font(.system(size: 64, weight: .light))
                        .foregroundColor(.secondary.opacity(0.7))
                    
                    VStack(spacing: 4) {
                        Text("空目录")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        Text("此目录中没有文件或子文件夹。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .contextMenu {
                    EmptyAreaContextMenuView(viewModel: viewModel, clipboard: clipboard)
                }
                
                Spacer()
            } else {
                List {
                    DirectoryItemListSectionView(viewModel: viewModel, clipboard: clipboard, onSelectFolder: onSelectFolder)
                    EmptyPasteAreaSectionView(viewModel: viewModel, clipboard: clipboard)
                }
                #if !os(tvOS)
                .listStyle(.insetGrouped)
                #else
                .listStyle(.grouped)
                #endif
                .searchable(text: $viewModel.searchText, prompt: "搜索文件和文件夹")
            }
            
            // Bottom Status & Storage Information Bar + Selection Actions Bar
            VStack(spacing: 0) {
                Divider()
                
                if viewModel.isSelectionMode {
                    SelectionActionBarView(viewModel: viewModel)
                    Divider()
                }
                
                BottomInformationBarView(viewModel: viewModel, clipboard: clipboard, folderSummaryString: folderSummaryString)
            }
        }
        .navigationTitle(viewModel.currentURL.lastPathComponent)
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                TrailingToolbarMenuView(viewModel: viewModel)
            }
        }
        .sheet(item: Binding(get: {
            viewModel.shareURL.map { ShareItem(url: $0) }
        }, set: { newValue in
            viewModel.shareURL = newValue?.url
        })) { shareItem in
            ActivityViewController(activityItems: [shareItem.url])
        }
        .alert(item: $viewModel.activeAlert, content: makeAlert)
        .onAppear {
            verboseLog("[DirectoryExplorerView] onAppear for URL: \(viewModel.currentURL.path)")
        }
        .onDisappear {
            verboseLog("[DirectoryExplorerView] onDisappear for URL: \(viewModel.currentURL.path) - cancelling loadTask")
            viewModel.cancelLoading()
        }
    }
    
    private func makeAlert(for alertType: StorageExplorerViewModel.ActiveAlert) -> Alert {
        let vm = self.viewModel
        switch alertType {
        case .confirmSingleDelete(let item):
            return Alert(
                title: Text("删除“\(item.name)”？"),
                message: Text("此项目将被永久移除。"),
                primaryButton: .destructive(Text("删除")) {
                    vm.delete(item: item)
                },
                secondaryButton: .cancel()
            )
        case .confirmBulkDelete:
            let count = vm.selectedURLs.count
            return Alert(
                title: Text("删除所选的 \(count) 项？"),
                message: Text("确定要永久删除这 \(count) 项吗？"),
                primaryButton: .destructive(Text("全部删除")) {
                    vm.bulkDeleteSelected()
                },
                secondaryButton: .cancel()
            )
        case .rename(let item):
            return Alert(
                title: Text("重命名“\(item.name)”"),
                message: Text("请输入此项目的新名称："),
                primaryButton: .default(Text("重命名")) {
                    vm.rename(item: item, to: vm.renameInput)
                },
                secondaryButton: .cancel()
            )
        case .bulkRename:
            let count = vm.selectedURLs.count
            let input = vm.renameInput
            return Alert(
                title: Text(count == 1 ? "重命名项目" : "批量重命名 \(count) 项"),
                message: Text(count == 1 ? "请输入新名称：" : "请输入基础名称（项目将被重命名为 Name_1、Name_2……）："),
                primaryButton: .default(Text("重命名")) {
                    vm.bulkRenameSelected(to: input)
                },
                secondaryButton: .cancel()
            )
        case .pasteConflict(let conflict):
            return Alert(
                title: Text("文件已存在"),
                message: Text("此文件夹中已存在名为“\(conflict.existingName)”的项目。请输入新名称以拷贝："),
                primaryButton: .default(Text("以新名称拷贝")) {
                    vm.resolveConflictWithNewName()
                },
                secondaryButton: .cancel(Text("全部取消")) {
                    vm.cancelRemainingConflicts()
                }
            )
        case .error(let message):
            return Alert(
                title: Text("存储浏览器错误"),
                message: Text(message),
                dismissButton: .default(Text("好"))
            )
        }
    }
}

// MARK: - Subview Components

private struct DirectoryItemListSectionView: View {
    let viewModel: StorageExplorerViewModel
    @ObservedObject var clipboard: StorageExplorerClipboard
    var onSelectFolder: ((URL) -> Void)?
    
    @State private var filteredAndSortedItems: [StorageExplorerItem] = []
    @State private var isSelectionMode: Bool = false
    @State private var selectedURLs: Set<URL> = []
    @State private var isTextWrapEnabled: Bool = true
    
    var body: some View {
        let folders = filteredAndSortedItems.filter { $0.isDirectory }
        let files = filteredAndSortedItems.filter { !$0.isDirectory }
        
        Group {
            if !folders.isEmpty && !files.isEmpty {
                Section("文件夹（\(folders.count)）") {
                    ForEach(folders) { item in
                        renderRow(item: item)
                    }
                }
                
                Section("文件（\(files.count)）") {
                    ForEach(files) { item in
                        renderRow(item: item)
                    }
                }
            } else if !folders.isEmpty {
                Section("文件夹（\(folders.count)）") {
                    ForEach(folders) { item in
                        renderRow(item: item)
                    }
                }
            } else {
                Section("文件（\(files.count)）") {
                    ForEach(files) { item in
                        renderRow(item: item)
                    }
                }
            }
        }
        .onAppear {
            updateState()
        }
        .onReceive(viewModel.objectWillChange.receive(on: DispatchQueue.main)) { _ in
            updateState()
        }
    }
    
    private func updateState() {
        self.filteredAndSortedItems = viewModel.filteredAndSortedItems
        self.isSelectionMode = viewModel.isSelectionMode
        self.selectedURLs = viewModel.selectedURLs
        self.isTextWrapEnabled = viewModel.isTextWrapEnabled
    }
    
    @ViewBuilder
    private func renderRow(item: StorageExplorerItem) -> some View {
        let isSelected = selectedURLs.contains(item.url)
        if isSelectionMode {
            AdaptiveTappableRow {
                if viewModel.selectedURLs.contains(item.url) {
                    viewModel.selectedURLs.remove(item.url)
                } else {
                    viewModel.selectedURLs.insert(item.url)
                }
            } content: {
                ItemRow(item: item, isSelected: isSelected, isSelectionMode: true, isTextWrapEnabled: isTextWrapEnabled)
            }
        } else if item.isDirectory {
            AdaptiveTappableRow {
                verboseLog("[DirectoryExplorerView] Tapped child folder: \(item.name) (\(item.url.path))")
                onSelectFolder?(item.url)
            } content: {
                ItemRow(item: item, isSelected: false, isSelectionMode: false, isTextWrapEnabled: isTextWrapEnabled)
            }
            .contextMenu {
                ItemContextMenuView(viewModel: viewModel, item: item)
            }
        } else {
            AdaptiveTappableRow {
                verboseLog("[DirectoryExplorerView] Tapped file item: \(item.name) (\(item.url.path))")
            } content: {
                ItemRow(item: item, isSelected: false, isSelectionMode: false, isTextWrapEnabled: isTextWrapEnabled)
            }
            .contextMenu {
                ItemContextMenuView(viewModel: viewModel, item: item)
            }
        }
    }
}

private struct EmptyPasteAreaSectionView: View {
    let viewModel: StorageExplorerViewModel
    let clipboard: StorageExplorerClipboard
    
    var body: some View {
        Section {
            Color.clear
                .frame(height: 100)
                .listRowBackground(Color.clear)
                .contextMenu {
                    EmptyAreaContextMenuView(viewModel: viewModel, clipboard: clipboard)
                }
        }
    }
}

private struct SelectionActionBarView: View {
    let viewModel: StorageExplorerViewModel
    
    @State private var selectedURLs: Set<URL> = []
    @State private var filteredCount: Int = 0
    @State private var allFilteredURLs: Set<URL> = []
    
    var body: some View {
        let count = selectedURLs.count
        let copyTitle = count > 0 ? "拷贝（\(count)）" : "拷贝"
        let renameTitle = count > 0 ? "重命名（\(count)）" : "重命名"
        let deleteTitle = count > 0 ? "删除（\(count)）" : "删除"
        let isAllSelected = count > 0 && count == filteredCount
        let selectTitle = isAllSelected ? "取消全选" : "全选"
        
        HStack(spacing: 6) {
            SwiftUI.Button {
                if isAllSelected {
                    viewModel.selectedURLs.removeAll()
                } else {
                    viewModel.selectedURLs = allFilteredURLs
                }
            } label: {
                Text(selectTitle)
                    .font(.caption.bold())
                    .lineLimit(1)
            }
            
            Spacer(minLength: 2)
            
            SwiftUI.Button {
                if !selectedURLs.isEmpty {
                    viewModel.copySelectedToClipboard()
                }
            } label: {
                Label(copyTitle, systemImage: "doc.on.doc")
                    .font(.caption.bold())
                    .lineLimit(1)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .fixedSize(horizontal: true, vertical: false)
            .disabled(selectedURLs.isEmpty)
            
            SwiftUI.Button {
                if !selectedURLs.isEmpty {
                    if count == 1, let firstURL = selectedURLs.first, let item = viewModel.items.first(where: { $0.url == firstURL }) {
                        viewModel.renameInput = item.name
                    } else {
                        viewModel.renameInput = ""
                    }
                    viewModel.activeAlert = .bulkRename
                }
            } label: {
                Label(renameTitle, systemImage: "pencil")
                    .font(.caption.bold())
                    .lineLimit(1)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .fixedSize(horizontal: true, vertical: false)
            .disabled(selectedURLs.isEmpty)
            
            SwiftUI.Button(role: .destructive) {
                if !selectedURLs.isEmpty {
                    viewModel.activeAlert = .confirmBulkDelete
                }
            } label: {
                Label(deleteTitle, systemImage: "trash")
                    .font(.caption.bold())
                    .lineLimit(1)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.small)
            .fixedSize(horizontal: true, vertical: false)
            .disabled(selectedURLs.isEmpty)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        #if !os(tvOS)
        .background(Color(UIColor.tertiarySystemBackground))
        #else
        .background(Color.white.opacity(0.08))
        #endif
        .onAppear {
            updateState()
        }
        .onReceive(viewModel.objectWillChange.receive(on: DispatchQueue.main)) { _ in
            updateState()
        }
    }
    
    private func updateState() {
        self.selectedURLs = viewModel.selectedURLs
        let filtered = viewModel.filteredAndSortedItems
        self.filteredCount = filtered.count
        self.allFilteredURLs = Set(filtered.map { $0.url })
    }
}

private struct BottomInformationBarView: View {
    let viewModel: StorageExplorerViewModel
    let clipboard: StorageExplorerClipboard
    let folderSummaryString: String
    
    @State private var freeDiskSpaceString: String = ""
    @State private var isSelectionMode: Bool = false
    @State private var hasCopiedItems: Bool = false
    @State private var pasteLabelText: String = "粘贴"
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(folderSummaryString)
                    .font(.caption)
                    .foregroundColor(.primary)
                Text("可用空间：\(freeDiskSpaceString)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            
            if hasCopiedItems && !isSelectionMode {
                SwiftUI.Button {
                    viewModel.pasteCopiedItems()
                } label: {
                    Label(pasteLabelText, systemImage: "doc.on.clipboard")
                        .font(.caption.bold())
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        #if !os(tvOS)
        .background(Color(UIColor.secondarySystemBackground))
        #else
        .background(Color.white.opacity(0.1))
        #endif
        .onAppear {
            updateState()
        }
        .onReceive(viewModel.objectWillChange.receive(on: DispatchQueue.main)) { _ in
            updateState()
        }
        .onReceive(clipboard.objectWillChange.receive(on: DispatchQueue.main)) { _ in
            updateState()
        }
    }
    
    private func updateState() {
        self.freeDiskSpaceString = viewModel.freeDiskSpaceString
        self.isSelectionMode = viewModel.isSelectionMode
        self.hasCopiedItems = clipboard.hasCopiedItems
        self.pasteLabelText = clipboard.pasteLabelText
    }
}

private struct TrailingToolbarMenuView: View {
    let viewModel: StorageExplorerViewModel
    
    @State private var isSelectionMode: Bool = false
    @State private var sortOption: StorageSortOption = .name
    @State private var sortAscending: Bool = true
    @State private var groupFoldersFirst: Bool = true
    @State private var isTextWrapEnabled: Bool = true
    #if os(tvOS)
    @State private var showTvMenu: Bool = false
    #endif
    
    var body: some View {
        #if !os(tvOS)
        Menu {
            SwiftUI.Button {
                viewModel.isSelectionMode.toggle()
                if !viewModel.isSelectionMode { viewModel.selectedURLs.removeAll() }
            } label: {
                Label(isSelectionMode ? "完成选择" : "选择", systemImage: "checkmark.circle")
            }
            
            Divider()
            
            Menu("排序方式") {
                ForEach(StorageSortOption.allCases) { option in
                    SwiftUI.Button {
                        if viewModel.sortOption == option {
                            viewModel.sortAscending.toggle()
                        } else {
                            viewModel.sortOption = option
                            viewModel.sortAscending = true
                        }
                    } label: {
                        if sortOption == option {
                            Label("\(option.rawValue)（\(sortAscending ? "升序" : "降序")）", systemImage: sortAscending ? "arrow.up" : "arrow.down")
                        } else {
                            Text(option.rawValue)
                        }
                    }
                }
            }
            
            Toggle(isOn: Binding(get: { groupFoldersFirst }, set: { viewModel.groupFoldersFirst = $0 })) {
                Text("文件夹优先")
            }
            
            Toggle(isOn: Binding(get: { isTextWrapEnabled }, set: { viewModel.isTextWrapEnabled = $0 })) {
                Text("文件名换行")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .onAppear {
            updateState()
        }
        .onReceive(viewModel.objectWillChange.receive(on: DispatchQueue.main)) { _ in
            updateState()
        }
        #else
        SwiftUI.Button {
            showTvMenu = true
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .confirmationDialog("选项", isPresented: $showTvMenu) {
            SwiftUI.Button(isSelectionMode ? "完成选择" : "选择") {
                viewModel.isSelectionMode.toggle()
                if !viewModel.isSelectionMode { viewModel.selectedURLs.removeAll() }
            }
            ForEach(StorageSortOption.allCases) { option in
                SwiftUI.Button("排序：\(option.rawValue)") {
                    if viewModel.sortOption == option {
                        viewModel.sortAscending.toggle()
                    } else {
                        viewModel.sortOption = option
                        viewModel.sortAscending = true
                    }
                }
            }
            SwiftUI.Button(groupFoldersFirst ? "不将文件夹分组在前" : "将文件夹分组在前") {
                viewModel.groupFoldersFirst.toggle()
            }
            SwiftUI.Button(isTextWrapEnabled ? "禁用文本换行" : "启用文本换行") {
                viewModel.isTextWrapEnabled.toggle()
            }
        }
        .onAppear {
            updateState()
        }
        .onReceive(viewModel.objectWillChange.receive(on: DispatchQueue.main)) { _ in
            updateState()
        }
        #endif
    }
    
    private func updateState() {
        self.isSelectionMode = viewModel.isSelectionMode
        self.sortOption = viewModel.sortOption
        self.sortAscending = viewModel.sortAscending
        self.groupFoldersFirst = viewModel.groupFoldersFirst
        self.isTextWrapEnabled = viewModel.isTextWrapEnabled
    }
}

private struct ItemContextMenuView: View {
    let viewModel: StorageExplorerViewModel
    let item: StorageExplorerItem
    
    @State private var isSelectionMode: Bool = false
    
    var body: some View {
        if !isSelectionMode {
            SwiftUI.Button {
                viewModel.copyToClipboard(item: item)
            } label: {
                Label("拷贝", systemImage: "doc.on.doc")
            }
            
            SwiftUI.Button {
                viewModel.renameInput = item.name
                viewModel.itemToRename = item
                viewModel.activeAlert = .rename(item)
            } label: {
                Label("重命名", systemImage: "pencil")
            }
            
            if !item.isDirectory {
                SwiftUI.Button {
                    viewModel.shareURL = item.url
                } label: {
                    Label("分享", systemImage: "square.and.arrow.up")
                }
            }
            
            SwiftUI.Button(role: .destructive) {
                viewModel.activeAlert = .confirmSingleDelete(item)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

private struct EmptyAreaContextMenuView: View {
    let viewModel: StorageExplorerViewModel
    let clipboard: StorageExplorerClipboard
    
    @State private var hasCopiedItems: Bool = false
    @State private var pasteLabelText: String = "粘贴"
    
    var body: some View {
        if hasCopiedItems {
            SwiftUI.Button {
                viewModel.pasteCopiedItems()
            } label: {
                Label(pasteLabelText, systemImage: "doc.on.clipboard")
            }
        }
    }
}

// MARK: - Item Row Component

private struct ItemRow: View {
    let item: StorageExplorerItem
    let isSelected: Bool
    let isSelectionMode: Bool
    let isTextWrapEnabled: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .imageScale(.large)
            }
            
            Image(systemName: item.isDirectory ? "folder.fill" : fileIcon(for: item.url))
                .font(.title2)
                .foregroundColor(item.isDirectory ? .blue : .secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                if isTextWrapEnabled {
                    Text(item.name)
                        .font(.body)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(item.name)
                        .font(.body)
                        .lineLimit(1)
                }
                
                HStack(spacing: 6) {
                    if item.isDirectory {
                        Text("\(item.itemCount) 项")
                        Text("•")
                        Text(item.formattedSize)
                    } else {
                        Text(item.formattedSize)
                        Text("•")
                        Text(item.formattedDate)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
    }
    
    private func fileIcon(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "ipa", "zip", "tar", "gz", "7z", "rar", "deb": return "doc.zipper"
        case "png", "jpg", "jpeg", "heic", "gif", "svg", "webp": return "photo"
        case "mp4", "mov", "m4v", "avi": return "film"
        case "mp3", "m4a", "wav", "aac", "flac": return "music.note"
        case "plist", "json", "xml", "txt", "log", "yaml", "yml": return "doc.text"
        case "dylib", "so", "dll", "exe", "bin", "a", "sys", "framework", "bundle": return "gearshape.2"
        case "db", "sqlite", "sqlite3", "storedata": return "cylinder.split.1x2"
        case "p12", "pem", "cer", "crt", "key", "mobileprovision", "provisionprofile": return "lock.doc"
        case "swift", "c", "cpp", "h", "m", "mm", "js", "ts", "py", "sh": return "chevron.left.forwardslash.chevron.right"
        case "pdf", "doc", "docx": return "doc.richtext"
        default: return "doc"
        }
    }
}

// MARK: - UIActivityViewController Wrapper

private struct ShareItem: Identifiable {
    var id: String { url.path }
    let url: URL
}

private struct AdaptiveTappableRow<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        #if !os(tvOS)
        content()
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
        #else
        SwiftUI.Button(action: action) {
            content()
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        #endif
    }
}
