//
//  TerminalLogger.swift
//  iDevice Toolkit
//
//  Created by GeoSn0w on 5/13/25.
//  Copyright © 2025 GeoSn0w. All rights reserved.
//

import Foundation
import SwiftUI

class TerminalLogger: ObservableObject {
    static let shared = TerminalLogger()
    
    @Published var entries: [String] = []
    
    private init() {
        entries.append("iDevice Central 终端已初始化！")
        entries.append("iDevice 工具箱 by GeoSn0w (@FCE365)")
    }
    
    func log(_ message: String) {
        DispatchQueue.main.async {
            self.entries.append(message)
        }
    }
    
    func clear() {
        DispatchQueue.main.async {
            self.entries = ["终端已清除"]
        }
    }
}

func iDeviceLogger(_ message: String) {
    TerminalLogger.shared.log(message)
}
