import SwiftUI
import Combine

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    private let accentColorKey = "accentColorKey"
    private let greenColorKey = "greenColorKey"
    
    @Published var accentColor: Color {
        didSet {
            saveColorToUserDefaults(accentColor, forKey: accentColorKey)
        }
    }
    
    @Published var greenColor: Color {
        didSet {
            saveColorToUserDefaults(greenColor, forKey: greenColorKey)
        }
    }
    
    var currentAccentColor: Color {
        return accentColor
    }
    
    var currentGreenColor: Color {
        return greenColor
    }
    
    private init() {
        // 从UserDefaults加载保存的颜色，如果没有则使用默认值
        self.accentColor = loadColorFromUserDefaults(forKey: accentColorKey) ?? ToolkitColors.accent
        self.greenColor = loadColorFromUserDefaults(forKey: greenColorKey) ?? ToolkitColors.green
    }
    
    func resetToDefaults() {
        accentColor = ToolkitColors.accent
        greenColor = ToolkitColors.green
        
        // 从UserDefaults中删除保存的颜色
        UserDefaults.standard.removeObject(forKey: accentColorKey)
        UserDefaults.standard.removeObject(forKey: greenColorKey)
    }
    
    private func saveColorToUserDefaults(_ color: Color, forKey key: String) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let colorData = [
            "red": red,
            "green": green,
            "blue": blue,
            "alpha": alpha
        ]
        
        UserDefaults.standard.set(colorData, forKey: key)
    }
    
    private func loadColorFromUserDefaults(forKey key: String) -> Color? {
        guard let colorData = UserDefaults.standard.dictionary(forKey: key) as? [String: CGFloat],
              let red = colorData["red"],
              let green = colorData["green"],
              let blue = colorData["blue"],
              let alpha = colorData["alpha"] else {
            return nil
        }
        
        return Color(.displayP3, red: red, green: green, blue: blue, opacity: alpha)
    }
}