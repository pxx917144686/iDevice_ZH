import SwiftUI
import UIKit

struct ColorPickerButton: View {
    @Binding var selectedColor: Color
    var onColorChange: ((Color) -> Void)?
    @State private var showingColorPicker = false
    
    var body: some View {
        Button(action: {
            showingColorPicker = true
        }) {
            Image(systemName: "eyedropper")
                .font(.system(size: 18))
                .foregroundColor(.white)
                .padding(8)
                .background(
                    Circle()
                        .fill(ToolkitColors.accent)
                )
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerView(selectedColor: $selectedColor, onColorConfirm: { color in
                selectedColor = color
                if let onColorChange = onColorChange {
                    onColorChange(color)
                }
                showingColorPicker = false
            })
        }
    }
}

struct ColorPickerView: View {
    @Binding var selectedColor: Color
    var onColorConfirm: (Color) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var pickerColor = Color.blue
    
    // 转换Color为UIColor，然后提取RGB分量
    private var rgbComponents: (red: Double, green: Double, blue: Double) {
        let uiColor = UIColor(selectedColor)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ToolkitColors.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // 颜色预览
                    RoundedRectangle(cornerRadius: 16)
                        .fill(selectedColor)
                        .frame(height: 100)
                        .shadow(radius: 5)
                        .padding(.horizontal)
                    
                    // 颜色选择器
                    ColorPicker("选择颜色", selection: $selectedColor, supportsOpacity: false)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ToolkitColors.darkBlue.opacity(0.5))
                        )
                        .padding(.horizontal)
                    
                    // 预设颜色
                    VStack(alignment: .leading, spacing: 12) {
                        Text("预设颜色")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.leading)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                            ColorPresetButton(color: .blue, selectedColor: $selectedColor)
                            ColorPresetButton(color: .green, selectedColor: $selectedColor)
                            ColorPresetButton(color: .red, selectedColor: $selectedColor)
                            ColorPresetButton(color: .orange, selectedColor: $selectedColor)
                            ColorPresetButton(color: .purple, selectedColor: $selectedColor)
                            ColorPresetButton(color: .yellow, selectedColor: $selectedColor)
                            ColorPresetButton(color: .pink, selectedColor: $selectedColor)
                            ColorPresetButton(color: .teal, selectedColor: $selectedColor)
                            ColorPresetButton(color: .cyan, selectedColor: $selectedColor)
                            ColorPresetButton(color: .indigo, selectedColor: $selectedColor)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top)
                    
                    Spacer()
                }
                .navigationBarTitle("选择颜色", displayMode: .inline)
                .navigationBarItems(
                    leading: Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    },
                    trailing: Button("确定") {
                        onColorConfirm(selectedColor)
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }
}

struct ColorPresetButton: View {
    let color: Color
    @Binding var selectedColor: Color
    
    var body: some View {
        Button(action: {
            selectedColor = color
        }) {
            Circle()
                .fill(color)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.6), lineWidth: 2)
                        .scaleEffect(0.9)
                        .opacity(selectedColor == color ? 1 : 0)
                )
        }
    }
}