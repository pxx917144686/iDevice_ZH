import SwiftUI
import UIKit

struct ColorPickerButton: UIViewRepresentable {
    @Binding var selectedColor: Color
    var onChange: (Color) -> Void
    
    func makeUIView(context: Context) -> UIColorWell {
        let colorWell = UIColorWell()
        colorWell.selectedColor = UIColor(selectedColor)
        colorWell.supportsAlpha = true
        colorWell.title = "选择颜色"
        colorWell.addTarget(context.coordinator, action: #selector(Coordinator.colorChanged(_:)), for: .valueChanged)
        return colorWell
    }
    
    func updateUIView(_ colorWell: UIColorWell, context: Context) {
        colorWell.selectedColor = UIColor(selectedColor)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: ColorPickerButton
        
        init(_ parent: ColorPickerButton) {
            self.parent = parent
        }
        
        @objc func colorChanged(_ sender: UIColorWell) {
            if let color = sender.selectedColor {
                let swiftUIColor = Color(color)
                parent.selectedColor = swiftUIColor
                parent.onChange(swiftUIColor)
            }
        }
    }
}