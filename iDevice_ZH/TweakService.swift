//
//  TweakService.swift
//  iDevice Toolkit
//
//  Created by GeoSn0w on 5/12/25.
//

import Foundation
import Combine

class TweaksService {
    static let shared = TweaksService()
    
    private init() {}
    
    private let githubUrl = "https://raw.githubusercontent.com/GeoSn0w/iDevice-Toolkit/refs/heads/main/TweakRepo/tweaks.json"
    
    func loadTweaks() -> AnyPublisher<[TweakPathForFile], Error> {
        return fetchTweaksFromGitHub()
            .handleEvents(receiveOutput: { tweaks in
                print("[+] 成功从GitHub获取并使用 \(tweaks.count) 个补丁")
            })
            .catch { [weak self] error -> AnyPublisher<[TweakPathForFile], Error> in
                print("[!] 从GitHub获取补丁失败: \(error.localizedDescription)")
                
                guard let self = self else {
                    return Fail(error: NSError(domain: "TweaksService", code: 1, userInfo: [NSLocalizedDescriptionKey: "服务已释放"])).eraseToAnyPublisher()
                }
                
                return self.loadDefaultTweaks()
                    .handleEvents(receiveOutput: { _ in
                        print("[+] 使用默认补丁作为备用")
                    })
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    private func fetchTweaksFromGitHub() -> AnyPublisher<[TweakPathForFile], Error> {
        guard let url = URL(string: githubUrl) else {
            return Fail(error: NSError(domain: "TweaksService", code: 2, userInfo: [NSLocalizedDescriptionKey: "无效的GitHub链接"])).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .tryMap { data in
                do {
                    let decoder = JSONDecoder()
                    let tweaks = try decoder.decode([TweakPathForFile].self, from: data)
                    print("[+] 成功从GitHub获取补丁")
                    return tweaks
                } catch {
                    print("[!] 补丁JSON解码错误: \(error.localizedDescription)")
                    throw error
                }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    private func loadDefaultTweaks() -> AnyPublisher<[TweakPathForFile], Error> {
        guard let path = Bundle.main.path(forResource: "default_tweaks", ofType: "json"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            
            return Just(DefaultTweaks.tweaks)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        return Just(data)
            .tryMap { data in
                let decoder = JSONDecoder()
                return try decoder.decode([TweakPathForFile].self, from: data)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

struct DefaultTweaks {
    static let tweaks: [TweakPathForFile] = {
        guard let jsonData = defaultTweaksJSON.data(using: .utf8),
              let tweaks = try? JSONDecoder().decode([TweakPathForFile].self, from: jsonData) else {
            print("[!] 解析硬编码补丁JSON失败")
            return []
        }
        return tweaks
    }()
    
    // 用户无网络等情况下的默认补丁JSON字符串
    
    static let defaultTweaksJSON = """
    [
      {
        "icon": "dock.rectangle",
        "name": "隐藏Dock栏",
        "paths": [
          "/System/Library/PrivateFrameworks/CoreMaterial.framework/dockDark.materialrecipe",
          "/System/Library/PrivateFrameworks/CoreMaterial.framework/dockLight.materialrecipe"
        ],
        "description": "完全移除主屏幕底部Dock栏的背景。补丁由@Skadz108开发。",
        "category": "外观"
      },
      {
        "icon": "line.3.horizontal",
        "name": "隐藏底部指示条",
        "paths": [
          "/System/Library/PrivateFrameworks/MaterialKit.framework/Assets.car"
        ],
        "description": "移除底部的主页指示条。补丁由@Skadz108开发。",
        "category": "外观"
      },
      {
        "icon": "folder",
        "name": "隐藏文件夹背景",
        "paths": [
          "/System/Library/PrivateFrameworks/SpringBoardHome.framework/folderDark.materialrecipe",
          "/System/Library/PrivateFrameworks/SpringBoardHome.framework/folderLight.materialrecipe"
        ],
        "description": "使应用文件夹完全透明。补丁由@Skadz108开发。",
        "category": "外观"
      },
      {
        "icon": "lock.iphone",
        "name": "隐藏解锁背景",
        "paths": [
          "/System/Library/PrivateFrameworks/CoverSheet.framework/dashBoardPasscodeBackground.materialrecipe"
        ],
        "description": "移除锁屏界面密码输入背景",
        "category": "外观"
      },
      {
        "icon": "bubble.left",
        "name": "简洁消息气泡",
        "paths": [
          "/System/Library/PrivateFrameworks/ChatKit.framework/bubbleDark.materialrecipe",
          "/System/Library/PrivateFrameworks/ChatKit.framework/bubbleLight.materialrecipe"
        ],
        "description": "简化信息应用中聊天气泡的外观",
        "category": "实验性"
      },
      {
        "icon": "square.stack.3d.forward.dottedline",
        "name": "透明播放器和通知",
        "paths": [
          "/System/Library/PrivateFrameworks/CoreMaterial.framework/platterStrokeLight.visualstyleset",
          "/System/Library/PrivateFrameworks/CoreMaterial.framework/platterStrokeDark.visualstyleset",
          "/System/Library/PrivateFrameworks/CoreMaterial.framework/plattersDark.materialrecipe",
          "/System/Library/PrivateFrameworks/SpringBoardHome.framework/folderLight.materialrecipe",
          "/System/Library/PrivateFrameworks/SpringBoardHome.framework/folderDark.materialrecipe",
          "/System/Library/PrivateFrameworks/CoreMaterial.framework/platters.materialrecipe"
        ],
        "description": "透明化媒体播放器和通知。补丁由@straight_tamago / mdc0开发",
        "category": "外观"
      },
      {
        "icon": "eye.slash.fill",
        "name": "关闭相机快门声",
        "paths": [
           "/System/Library/Audio/UISounds/photoShutter.caf",
                  "/System/Library/Audio/UISounds/begin_record.caf",
                  "/System/Library/Audio/UISounds/end_record.caf",
                  "/System/Library/Audio/UISounds/Modern/camera_shutter_burst.caf",
                  "/System/Library/Audio/UISounds/Modern/camera_shutter_burst_begin.caf",
                  "/System/Library/Audio/UISounds/Modern/camera_shutter_burst_end.caf"
          ],
        "description": "禁用相机快门声。关闭相机应用可能会重新启用它。补丁由@straight_tamago开发",
        "category": "隐私"
      },
       {
        "icon": "eye.slash.fill",
        "name": "关闭通话录音提示音",
        "paths": [
           "/var/mobile/Library/CallServices/Greetings/default/StartDisclosure.caf",
            "/var/mobile/Library/CallServices/Greetings/default/StartDisclosureWithTone.m4a",
            "/var/mobile/Library/CallServices/Greetings/default/StopDisclosure.caf",
            "/System/Library/PrivateFrameworks/ConversationKit.framework/call_recording_countdown.caf"
          ],
        "description": "在iOS 18+上禁用启用通话录音的通知声音。补丁由@straight_tamago开发",
        "category": "隐私"
      },
    ]
    """
}
