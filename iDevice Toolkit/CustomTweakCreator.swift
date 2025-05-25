//
//  CustomTweakCreator.swift
//  iDevice Toolkit
//
//  Created by GeoSn0w on 5/14/25.
//  Copyright © 2025 GeoSn0w. All rights reserved.
//
import SwiftUI
import DeviceKit
import Combine
import Foundation
import UniformTypeIdentifiers

struct FileItem: Identifiable, Hashable {
let id = UUID()
let path: String
let isDirectory: Bool
let name: String

func hash(into hasher: inout Hasher) {
    hasher.combine(path)
}

static func == (lhs: FileItem, rhs: FileItem) -> Bool {
    return lhs.path == rhs.path
}
}

struct CustomTweakCreatorView: View {
@Environment(\.presentationMode) var presentationMode
@ObservedObject private var customTweakManager = CustomTweakManager.shared

@State private var tweakName: String = ""
@State private var tweakDescription: String = ""
@State private var tweakPaths: String = ""
@State private var selectedIcon: String = "wrench.fill"
@State private var showIconPicker: Bool = false
@State private var showSuccessAlert: Bool = false
@State private var showErrorAlert: Bool = false
@State private var errorMessage: String = ""
@State private var successMessage: String = ""
@State private var showDocumentPicker: Bool = false
@State private var showImportAlert: Bool = false
@State private var importAlertMessage: String = ""
@State private var showDocumentExporter: Bool = false
@State private var exportURL: URL? = nil
@State private var showExportPicker: Bool = false
@State private var exportErrorMessage: String = ""
@State private var showExportErrorAlert: Bool = false
@State private var showFolderPathInputAlert: Bool = false
@State private var folderPathInput: String = ""
@State private var showFileSelector: Bool = false
@State private var filesList: [FileItem] = []
@State private var selectedFiles: Set<String> = []
@State private var isLoading: Bool = false

private let commonIcons = [
    "wrench.fill", "gear", "hammer.fill", "bolt.fill", "wand.and.stars",
    "sparkles", "paintbrush.fill", "pencil", "highlighter", "theatermasks.fill",
    "waveform.path.ecg", "speedometer", "clock.fill", "timer", "gamecontroller.fill",
    "network", "antenna.radiowaves.left.and.right", "wifi", "dot.radiowaves.left.and.right",
    "lock.fill", "lock.open.fill", "lock.shield.fill", "eye.fill", "eye.slash.fill",
    "hand.raised.fill", "globe", "trash.fill", "folder.fill", "doc.fill",
    "terminal.fill", "command", "flag.fill", "bell.fill", "speaker.wave.3.fill",
    "music.note", "heart.fill", "star.fill", "bookmark.fill", "tag.fill"
]

var body: some View {
    NavigationView {
        ZStack {
            ToolkitColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(spacing: 20) {
                        formSection
                        
                        actionButtons
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert(isPresented: $showSuccessAlert) {
            Alert(
                title: Text("成功"),
                message: Text(successMessage),
                dismissButton: .default(Text("确定")) {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .alert("错误", isPresented: $showErrorAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("导出错误", isPresented: $showExportErrorAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(exportErrorMessage)
        }
        .alert("输入文件夹路径", isPresented: $showFolderPathInputAlert) {
            TextField("路径", text: $folderPathInput)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .foregroundColor(.black)
            
            Button("取消", role: .cancel) {
                folderPathInput = ""
            }
            
            Button("扫描") {
                if !folderPathInput.isEmpty {
                    scanFilesInDirectory(folderPathInput)
                }
                folderPathInput = ""
            }
        } message: {
            Text("输入要扫描文件的文件夹路径")
        }
        .sheet(isPresented: $showIconPicker) {
            iconPickerView
        }
        .sheet(isPresented: $showFileSelector) {
            FolderPathSelectorView(
                filesList: $filesList,
                selectedFiles: $selectedFiles,
                isLoading: $isLoading,
                initialPath: folderPathInput
            )
            .onDisappear {
                if !selectedFiles.isEmpty {
                    addSelectedPathsToTweakPaths()
                }
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView(
                onPick: { url in
                    let success = importTweak(from: url)
                    if success {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                },
                onError: { error in
                    errorMessage = "导入错误: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            )
        }
        .sheet(isPresented: $showExportPicker) {
            exportTweakPicker
        }
        .fileExporter(
            isPresented: $showDocumentExporter,
            document: exportURL != nil ? try? JSONFile(url: exportURL!) : nil,
            contentType: .json,
            defaultFilename: "custom_tweak.json"
        ) { result in
            switch result {
            case .success(let url):
                successMessage = "成功导出补丁到 \(url.lastPathComponent)"
                showSuccessAlert = true
                iDeviceLogger("[+] 成功导出补丁到: \(url.lastPathComponent)")
            case .failure(let error):
                exportErrorMessage = "导出失败: \(error.localizedDescription)"
                showExportErrorAlert = true
                iDeviceLogger("[!] 导出过程中出错: \(error.localizedDescription)")
            }
        }
    }
}

private var headerView: some View {
    HStack {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(ToolkitColors.accent.opacity(0.9))
        }
        .padding(.trailing, 8)
        
        Spacer()
        
        HStack(spacing: 8) {
            Image(systemName: selectedIcon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ToolkitColors.accent)
            
            Text("创建自定义补丁")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
        }
        
        Spacer()
        
        Image(systemName: "xmark.circle.fill")
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(.clear)
            .padding(.leading, 8)
    }
    .padding(.horizontal, 22)
    .padding(.vertical, 16)
    .background(
        Rectangle()
            .fill(ToolkitColors.headerBackground)
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    )
}

private var formSection: some View {
    VStack(spacing: 20) {
        // Name field
        VStack(alignment: .leading, spacing: 8) {
            Text("补丁名称")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            TextField("", text: $tweakName)
                .placeholder(when: tweakName.isEmpty) {
                    Text("输入补丁名称").foregroundColor(.gray.opacity(0.7))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ToolkitColors.darkBlue.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(ToolkitColors.accent.opacity(0.5), lineWidth: 1)
                        )
                )
                .foregroundColor(.white)
        }
        
        // Icon selector
        VStack(alignment: .leading, spacing: 8) {
            Text("图标")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            Button(action: {
                showIconPicker = true
            }) {
                HStack {
                    Image(systemName: selectedIcon)
                        .font(.system(size: 24))
                        .foregroundColor(ToolkitColors.accent)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(ToolkitColors.darkBlue.opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(ToolkitColors.accent.opacity(0.5), lineWidth: 1)
                                )
                        )
                    
                    Text("选择图标")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ToolkitColors.darkBlue.opacity(0.3))
                )
            }
        }
        
        // Description field
        VStack(alignment: .leading, spacing: 8) {
            Text("描述")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            ZStack(alignment: .topLeading) {
                if tweakDescription.isEmpty {
                    Text("输入补丁描述。这个补丁的功能是什么？")
                        .foregroundColor(.gray.opacity(0.7))
                        .padding(.top, 12)
                        .padding(.leading, 12)
                }
                
                TextEditor(text: $tweakDescription)
                    .padding(8)
                    .frame(minHeight: 80)
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(ToolkitColors.darkBlue.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(ToolkitColors.accent.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        
        // Paths field
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("目标路径（用逗号分隔）")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    openFolderPathSelector()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 14))
                        Text("浏览")
                            .font(.system(size: 14))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ToolkitColors.accent.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(ToolkitColors.accent.opacity(0.5), lineWidth: 1)
                            )
                    )
                }
                .foregroundColor(ToolkitColors.accent)
            }
            
            ZStack(alignment: .topLeading) {
                if tweakPaths.isEmpty {
                    Text("/路径/到/文件1,/路径/到/文件2")
                        .foregroundColor(.gray.opacity(0.7))
                        .padding(.top, 12)
                        .padding(.leading, 12)
                }
                
                TextEditor(text: $tweakPaths)
                    .padding(8)
                    .frame(minHeight: 80)
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(ToolkitColors.darkBlue.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(ToolkitColors.accent.opacity(0.5), lineWidth: 1)
                    )
            )
            
            Text("示例: /var/mobile/Library/Preferences/com.apple.springboard.plist")
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .padding(.horizontal, 4)
        }
    }
    .padding(16)
    .background(
        RoundedRectangle(cornerRadius: 16)
            .fill(ToolkitColors.darkBlue.opacity(0.2))
    )
}

private var actionButtons: some View {
    VStack(spacing: 16) {
        ToolkitButton(
            icon: "checkmark.circle.fill",
            text: "保存自定义补丁",
            disabled: tweakName.isEmpty || tweakPaths.isEmpty
        ) {
            saveCustomTweak()
        }
        
        ToolkitButton(
            icon: "arrow.down.doc.fill",
            text: "从文件导入",
            disabled: false
        ) {
            showDocumentPicker = true
        }
        
        if !customTweakManager.customTweaks.isEmpty {
            ToolkitButton(
                icon: "square.and.arrow.up",
                text: "导出补丁",
                disabled: false
            ) {
                showExportPicker = true
            }
        }
    }
}

private var iconPickerView: some View {
    ZStack {
        ToolkitColors.background
            .ignoresSafeArea()
        
        VStack(spacing: 0) {
            HStack {
                Text("选择图标")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    showIconPicker = false
                }) {
                    Text("完成")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ToolkitColors.accent)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .background(
                Rectangle()
                    .fill(ToolkitColors.headerBackground)
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            )
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
                    ForEach(commonIcons, id: \.self) { icon in
                        Button(action: {
                            selectedIcon = icon
                            showIconPicker = false
                        }) {
                            VStack {
                                Image(systemName: icon)
                                    .font(.system(size: 28))
                                    .foregroundColor(selectedIcon == icon ? ToolkitColors.green : ToolkitColors.accent)
                                    .frame(width: 60, height: 60)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(ToolkitColors.darkBlue.opacity(0.3))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(selectedIcon == icon ? ToolkitColors.green.opacity(0.7) : ToolkitColors.accent.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                    .shadow(color: selectedIcon == icon ? ToolkitColors.green.opacity(0.4) : .clear, radius: 4)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
    }
    .preferredColorScheme(.dark)
}

private var exportTweakPicker: some View {
    NavigationView {
        ZStack {
            ToolkitColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        showExportPicker = false
                    }) {
                        Text("取消")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ToolkitColors.accent)
                    }
                    
                    Spacer()
                    
                    Text("选择要导出的补丁")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("取消")
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Rectangle()
                        .fill(ToolkitColors.headerBackground)
                )
                
                List {
                    ForEach(customTweakManager.customTweaks) { tweak in
                        Button(action: {
                            exportTweak(tweak)
                            showExportPicker = false
                        }) {
                            HStack {
                                Image(systemName: tweak.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(ToolkitColors.accent)
                                    .frame(width: 24)
                                
                                Text(tweak.name)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(PlainListStyle())
                .background(ToolkitColors.background)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - File Selector View

struct FolderPathSelectorView: View {
    @Binding var filesList: [FileItem]
    @Binding var selectedFiles: Set<String>
    @Binding var isLoading: Bool
    @Environment(\.presentationMode) var presentationMode
    
    @State private var currentPath: String = ""
    @State private var navigationStack: [String] = []
    
    let initialPath: String
    
    init(filesList: Binding<[FileItem]>, selectedFiles: Binding<Set<String>>, isLoading: Binding<Bool>, initialPath: String = "") {
        self._filesList = filesList
        self._selectedFiles = selectedFiles
        self._isLoading = isLoading
        self.initialPath = initialPath
        self._currentPath = State(initialValue: initialPath)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ToolkitColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("取消")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(ToolkitColors.accent)
                        }
                        
                        Spacer()
                        
                        Text("选择文件")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("完成")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(ToolkitColors.accent)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(ToolkitColors.headerBackground)
                    
                    // Navigation path
                    if !navigationStack.isEmpty {
                        HStack {
                            Button(action: {
                                navigateBack()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 14))
                                    Text("返回")
                                        .font(.system(size: 14))
                                }
                                .foregroundColor(ToolkitColors.accent)
                            }
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 4) {
                                    ForEach(Array(currentPathComponents.enumerated()), id: \.offset) { index, component in
                                        if index > 0 {
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 10))
                                                .foregroundColor(.gray)
                                        }
                                        
                                        Text(component)
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 4)
                            }
                        }
                        .padding(.horizontal, 16)
                        .background(ToolkitColors.darkBlue.opacity(0.4))
                    }
                    
                    // Selector controls
                    HStack {
                        Button(action: {
                            selectAllFiles()
                        }) {
                            Text("全选")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(ToolkitColors.accent)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(ToolkitColors.darkBlue.opacity(0.3))
                        )
                        
                        Spacer()
                        
                        Button(action: {
                            selectedFiles.removeAll()
                        }) {
                            Text("取消全选")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(ToolkitColors.accent)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(ToolkitColors.darkBlue.opacity(0.3))
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ToolkitColors.accent))
                            .scaleEffect(1.5)
                        Text("正在扫描文件...")
                            .foregroundColor(.gray)
                            .padding(.top, 16)
                        Spacer()
                    } else if filesList.isEmpty {
                        Spacer()
                        Text("此目录中没有找到文件")
                            .foregroundColor(.gray)
                            .padding()
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(filesList) { file in
                                    fileCellView(file)
                                }
                            }
                            .padding(.bottom, 16)
                        }
                    }
                    
                    HStack {
                        Text("已选择 \(selectedFiles.count) 个文件")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Button(action: {
                            addSelectedPaths()
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("添加所选")
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedFiles.isEmpty ? Color.gray.opacity(0.5) : ToolkitColors.accent)
                            )
                        }
                        .disabled(selectedFiles.isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Rectangle()
                            .fill(ToolkitColors.darkBlue.opacity(0.5))
                    )
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
                if !initialPath.isEmpty && filesList.isEmpty {
                    isLoading = true
                    DispatchQueue.global(qos: .userInitiated).async {
                        let items = listDirectoryContents(at: initialPath)
                        
                        DispatchQueue.main.async {
                            filesList = items
                            isLoading = false
                        }
                    }
                }
            }
        }
    }
    
    private var currentPathComponents: [String] {
        let components = currentPath.split(separator: "/").map(String.init)
        return ["根目录"] + components
    }
    
    private func fileCellView(_ file: FileItem) -> some View {
        Button(action: {
            if file.isDirectory {
                navigateToDirectory(file.path)
            } else {
                toggleFileSelection(file)
            }
        }) {
            HStack {
                Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                    .font(.system(size: 16))
                    .foregroundColor(file.isDirectory ? ToolkitColors.accent : .gray)
                    .frame(width: 24)
                
                VStack(alignment: .leading) {
                    Text(file.name)
                        .lineLimit(1)
                        .foregroundColor(.white)
                    
                    if !file.isDirectory {
                        Text(file.path)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                if file.isDirectory {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                } else {
                    Image(systemName: selectedFiles.contains(file.path) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundColor(selectedFiles.contains(file.path) ? ToolkitColors.green : .gray)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                selectedFiles.contains(file.path) && !file.isDirectory
                    ? ToolkitColors.darkBlue.opacity(0.3)
                    : Color.clear
            )
        }
    }
    
    private func navigateToDirectory(_ path: String) {
        navigationStack.append(currentPath)
        currentPath = path
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let items = listDirectoryContents(at: path)
            DispatchQueue.main.async {
                filesList = items
                isLoading = false
            }
        }
    }
    
    private func navigateBack() {
        guard !navigationStack.isEmpty else { return }
        
        isLoading = true
        let previousPath = navigationStack.removeLast()
        currentPath = previousPath
        
        DispatchQueue.global(qos: .userInitiated).async {
            let items = listDirectoryContents(at: previousPath)
            DispatchQueue.main.async {
                filesList = items
                isLoading = false
            }
        }
    }
    
    private func listDirectoryContents(at path: String) -> [FileItem] {
        var result: [FileItem] = []
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            
            for itemName in contents {
                let fullPath = (path as NSString).appendingPathComponent(itemName)
                var isDirectory: ObjCBool = false
                
                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory) {
                    let item = FileItem(
                        path: fullPath,
                        isDirectory: isDirectory.boolValue,
                        name: itemName
                    )
                    result.append(item)
                }
            }
        
            return result.sorted { (a, b) -> Bool in
                if a.isDirectory && !b.isDirectory {
                    return true
                } else if !a.isDirectory && b.isDirectory {
                    return false
                } else {
                    return a.name < b.name
                }
            }
        } catch {
            iDeviceLogger("[!] 列出目录内容失败，路径 \(path): \(error.localizedDescription)")
            return []
        }
    }
    
    private func toggleFileSelection(_ file: FileItem) {
        if !file.isDirectory {
            if selectedFiles.contains(file.path) {
                selectedFiles.remove(file.path)
            } else {
                selectedFiles.insert(file.path)
            }
        }
    }
    
    private func selectAllFiles() {
        for file in filesList {
            if !file.isDirectory {
                selectedFiles.insert(file.path)
            }
        }
    }
    
    private func addSelectedPaths() {
        presentationMode.wrappedValue.dismiss()
    }
}
private func saveCustomTweak() {
    guard !tweakName.isEmpty, !tweakPaths.isEmpty else {
        errorMessage = "名称和路径为必填项"
        showErrorAlert = true
        return
    }
    
    let paths = tweakPaths
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    
    guard !paths.isEmpty else {
        errorMessage = "没有提供有效路径"
        showErrorAlert = true
        return
    }
    
    let newTweak = TweakPathForFile(
        icon: selectedIcon,
        name: tweakName,
        paths: paths,
        description: tweakDescription,
        category: .custom
    )
    
    let success = customTweakManager.addCustomTweak(newTweak)
    
    if success {
        successMessage = "自定义补丁 '\(tweakName)' 创建成功！"
        showSuccessAlert = true
    } else {
        errorMessage = "保存补丁失败。可能已存在同名补丁。"
        showErrorAlert = true
    }
}

private func importTweak(from url: URL) -> Bool {
    let success = customTweakManager.importTweak(from: url)
    if success {
        successMessage = "补丁导入成功！"
        showSuccessAlert = true
        return true
    } else {
        errorMessage = "导入补丁失败。文件可能已损坏或无法访问。"
        showErrorAlert = true
        return false
    }
}

private func exportTweak(_ tweak: TweakPathForFile) {
    exportURL = customTweakManager.exportTweak(tweak)
    if let _ = exportURL {
        showDocumentExporter = true
    } else {
        exportErrorMessage = "准备导出补丁失败。"
        showExportErrorAlert = true
    }
}

private func openFolderPathSelector() {
    showFolderPathInputAlert = true
}

private func scanFilesInDirectory(_ path: String) {
    isLoading = true
    filesList = []
    selectedFiles = []
    
    DispatchQueue.global(qos: .userInitiated).async {
        let items = listDirectoryContents(at: path)
        
        DispatchQueue.main.async {
            filesList = items
            isLoading = false
            showFileSelector = true
        }
    }
}

private func listDirectoryContents(at path: String) -> [FileItem] {
    var result: [FileItem] = []
    let fileManager = FileManager.default
    
    do {
        let contents = try fileManager.contentsOfDirectory(atPath: path)
        
        for itemName in contents {
            let fullPath = (path as NSString).appendingPathComponent(itemName)
            var isDirectory: ObjCBool = false
            
            if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory) {
                let item = FileItem(
                    path: fullPath,
                    isDirectory: isDirectory.boolValue,
                    name: itemName
                )
                result.append(item)
            }
        }
        
        return result.sorted { (a, b) -> Bool in
            if a.isDirectory && !b.isDirectory {
                return true
            } else if !a.isDirectory && b.isDirectory {
                return false
            } else {
                return a.name < b.name
            }
        }
    } catch {
        iDeviceLogger("[!] 列出目录内容失败，路径 \(path): \(error.localizedDescription)")
        return []
    }
}

private func addSelectedPathsToTweakPaths() {
    if selectedFiles.isEmpty {
        return
    }
    
    let newPaths = selectedFiles.joined(separator: ",")
    
    if tweakPaths.isEmpty {
        tweakPaths = newPaths
    } else {
        tweakPaths += "," + newPaths
    }
}

struct JSONFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var data: Data
    
    init(url: URL) throws {
        self.data = try Data(contentsOf: url)
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}
}
