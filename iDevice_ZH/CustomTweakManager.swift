//
//  CustomTweakManager.swift
//  iDevice Toolkit
//
//  Created by GeoSn0w on 5/14/25.
//  Copyright © 2025 GeoSn0w. All rights reserved.
//
import SwiftUI
import DeviceKit
import Combine
import Foundation

class CustomTweakManager: ObservableObject {
    static let shared = CustomTweakManager()
    @Published var customTweaks: [TweakPathForFile] = []
    
    private let fileManager = FileManager.default
    
    init() {
        loadCustomTweaks()
    }
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var customTweaksFile: URL {
        documentsDirectory.appendingPathComponent("custom_tweaks.json")
    }
    
    func loadCustomTweaks() {
        guard fileManager.fileExists(atPath: customTweaksFile.path) else { return }
        
        do {
            let data = try Data(contentsOf: customTweaksFile)
            let decoder = JSONDecoder()
            customTweaks = try decoder.decode([TweakPathForFile].self, from: data)
            print("[*] 成功加载 \(customTweaks.count) 个自定义补丁")
        } catch {
            print("[!] 加载自定义补丁失败: \(error.localizedDescription)")
        }
    }
    
    func saveCustomTweaks() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(customTweaks)
            try data.write(to: customTweaksFile)
            print("[+] 成功保存 \(customTweaks.count) 个自定义补丁")
        } catch {
            print("[!] 保存自定义补丁失败: \(error.localizedDescription)")
        }
    }
    
    func deleteTweak(withID id: String) {
        if let index = customTweaks.firstIndex(where: { $0.id == id }) {
            let tweakName = customTweaks[index].name
            customTweaks.remove(at: index)
            saveCustomTweaks()
            iDeviceLogger("[+] 已删除自定义补丁: \(tweakName)")
        }
    }
    
    func addCustomTweak(_ tweak: TweakPathForFile) -> Bool {
        do {
            if customTweaks.contains(where: { $0.name == tweak.name }) {
                return false
            }
            
            customTweaks.append(tweak)
            saveCustomTweaks()
            iDeviceLogger("[+] 已添加新的自定义补丁: \(tweak.name)")
            return true
        } catch {
            iDeviceLogger("[!] 添加自定义补丁时出错: \(error.localizedDescription)")
            return false
        }
    }

    func removeTweak(withID id: String) {
        customTweaks.removeAll { $0.id == id }
        saveCustomTweaks()
    }
    
    func exportTweak(_ tweak: TweakPathForFile) -> URL? {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(tweak)
                
                let fileName = tweak.name.replacingOccurrences(of: " ", with: "_")
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "\\", with: "_")
                    .replacingOccurrences(of: ":", with: "_")
                
                let tempDir = FileManager.default.temporaryDirectory
                let exportURL = tempDir.appendingPathComponent("\(fileName).json")
                
                try data.write(to: exportURL)
                iDeviceLogger("[+] 已导出补丁: \(tweak.name) 到 \(exportURL.lastPathComponent)")
                return exportURL
            } catch {
                print("[!] 导出补丁失败: \(error.localizedDescription)")
                iDeviceLogger("[!] 导出补丁时出错: \(error.localizedDescription)")
                return nil
            }
        }
    
    func importTweak(from url: URL) -> Bool {
        do {
            let tempDir = FileManager.default.temporaryDirectory
            let tempURL = tempDir.appendingPathComponent(UUID().uuidString + ".json")
            
            do {
                let data = try Data(contentsOf: url)
                try data.write(to: tempURL)
                
                let decoder = JSONDecoder()
                let tweak = try decoder.decode(TweakPathForFile.self, from: data)
                
                if let existingIndex = customTweaks.firstIndex(where: { $0.name == tweak.name }) {
                    var newName = tweak.name
                    var counter = 1
                    while customTweaks.contains(where: { $0.name == newName }) {
                        newName = "\(tweak.name) (\(counter))"
                        counter += 1
                    }
                    
                    var uniqueTweak = tweak
                    uniqueTweak.name = newName
                    customTweaks.append(uniqueTweak)
                } else {
                    customTweaks.append(tweak)
                }
                
                saveCustomTweaks()
                iDeviceLogger("[+] 成功导入补丁: \(tweak.name)")
                
                try? FileManager.default.removeItem(at: tempURL)
                
                return true
            } catch {
                iDeviceLogger("[!] 读取文件错误: \(error.localizedDescription)")
                return false
            }
        } catch {
            print("[!] 导入补丁失败: \(error.localizedDescription)")
            iDeviceLogger("[!] 导入补丁时出错: \(error.localizedDescription)")
            return false
        }
    }
}
