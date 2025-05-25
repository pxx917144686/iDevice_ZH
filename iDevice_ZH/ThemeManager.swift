import SwiftUI
import Combine

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var accentColor: Color {
        didSet {
            UserDefaults.standard.set(UIColor(accentColor).cgColor.components, forKey: "accentColor")
        }
    }
    
    @Published var greenColor: Color {
        didSet {
            UserDefaults.standard.set(UIColor(greenColor).cgColor.components, forKey: "greenColor")
        }
    }
    
    @Published var showColorPicker: Bool = false
    
    private init() {
        // 从UserDefaults加载保存的颜色，如果没有则使用默认颜色
        if let components = UserDefaults.standard.array(forKey: "accentColor") as? [CGFloat],
           components.count >= 4 {
            self.accentColor = Color(.sRGB, red: components[0], 
                                    green: components[1], 
                                    blue: components[2], 
                                    opacity: components[3])
        } else {
            self.accentColor = ToolkitColors.accent
        }
        
        if let components = UserDefaults.standard.array(forKey: "greenColor") as? [CGFloat],
           components.count >= 4 {
            self.greenColor = Color(.sRGB, red: components[0], 
                                   green: components[1], 
                                   blue: components[2], 
                                   opacity: components[3])
        } else {
            self.greenColor = ToolkitColors.green
        }
    }
    
    func resetToDefaults() {
        accentColor = ToolkitColors.accent
        greenColor = ToolkitColors.green
        UserDefaults.standard.removeObject(forKey: "accentColor")
        UserDefaults.standard.removeObject(forKey: "greenColor")
    }
    
    // 用于替换应用中使用的颜色
    var currentAccentColor: Color {
        return accentColor
    }
    
    var currentGreenColor: Color {
        return greenColor
    }
}