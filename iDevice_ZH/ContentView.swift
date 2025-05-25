import SwiftUI
import DeviceKit
import Combine
import UIKit
import UniformTypeIdentifiers

struct TweakPathForFile: Identifiable, Codable {
    var id: String { name }
    var icon: String
    var name: String
    var paths: [String]
    var description: String
    var category: TweakCategory
    
    enum CodingKeys: String, CodingKey {
        case icon, name, paths, description, category
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        icon = try container.decode(String.self, forKey: .icon)
        name = try container.decode(String.self, forKey: .name)
        paths = try container.decode([String].self, forKey: .paths)
        description = try container.decode(String.self, forKey: .description)
        
        let categoryString = try container.decode(String.self, forKey: .category)
        if let decodedCategory = TweakCategory(rawValue: categoryString) {
            category = decodedCategory
        } else {
            category = .experimental
        }
    }
}

extension TweakPathForFile {
    init(icon: String, name: String, paths: [String], description: String, category: TweakCategory) {
        self.icon = icon
        self.name = name
        self.paths = paths
        self.description = description
        self.category = category
    }
}

enum TweakCategory: String, Codable, CaseIterable {
    case aesthetics = "美化"
    case performance = "性能"
    case privacy = "隐私"
    case experimental = "调整"
    case custom = "自定义"
}

// Helper extensions
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// File document type for the custom tweaks
struct TweakDocument: FileDocument {
    static var readableContentTypes: [UTType] { [UTType.json] }
    
    var tweak: TweakPathForFile
    
    init(tweak: TweakPathForFile) {
        self.tweak = tweak
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let decodedTweak = try? JSONDecoder().decode(TweakPathForFile.self, from: data)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        self.tweak = decodedTweak
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(tweak)
        return FileWrapper(regularFileWithContents: data)
    }
}

// Share sheet for exporting tweaks
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct CustomTweaksCategoryButton: View {
    @Binding var showCustomTweakCreator: Bool
    
    var body: some View {
        Button(action: {
            withAnimation {
                showCustomTweakCreator = true
            }
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ToolkitColors.green)
                    .frame(width: 26)
                
                Text("创建自定义调整")
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
                    .padding(.leading, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ToolkitColors.categoryHeaderBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

extension Array: @retroactive RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else {
            return nil
        }
        self = result
    }
    
    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}

enum ToolkitColors {
    struct ColorComponents {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
        
        var color: Color {
            Color(.sRGB, red: red/255, green: green/255, blue: blue/255, opacity: alpha/255)
        }
    }
    
    private static let palette = (
        midnight: ColorComponents(red: 15, green: 26, blue: 42, alpha: 255),
        azure: ColorComponents(red: 23, green: 46, blue: 76, alpha: 255),
        cobalt: ColorComponents(red: 31, green: 64, blue: 104, alpha: 255),
        slate: ColorComponents(red: 37, green: 58, blue: 80, alpha: 255),
        
        navyBlue: ColorComponents(red: 30, green: 58, blue: 95, alpha: 255),
        slateGray: ColorComponents(red: 37, green: 58, blue: 80, alpha: 255),
        electric: ColorComponents(red: 97, green: 218, blue: 251, alpha: 255),
        neon: ColorComponents(red: 0, green: 255, blue: 157, alpha: 255),
        glow: ColorComponents(red: 37, green: 255, blue: 113, alpha: 255),
        moss: ColorComponents(red: 29, green: 59, blue: 44, alpha: 255)
    )
    
    static var background: Color { palette.midnight.color }
    static var darkBlue: Color { palette.azure.color }
    static var mediumBlue: Color { palette.cobalt.color }
    static var headerBackground: Color { palette.cobalt.color }
    static var categoryBackground: Color { palette.slate.color }
    static var accent: Color { palette.electric.color }
    static var green: Color { palette.neon.color }
    static var glowGreen: Color { palette.glow.color }
    static var darkGreen: Color { palette.moss.color }
    static var capsuleBackground: Color { palette.navyBlue.color }
    static var categoryHeaderBackground: Color { palette.slateGray.color }
}

struct NeonBorder: ViewModifier {
    var isActive: Bool
    var color: Color = ToolkitColors.accent
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? color : Color.clear, lineWidth: 1.5)
                    .blur(radius: isActive ? 2.5 : 0)
            )
    }
}

struct GlowText: View {
    var text: String
    var color: Color = ToolkitColors.green
    
    var body: some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(color)
            .shadow(color: color.opacity(0.8), radius: 2, x: 0, y: 0)
    }
}

struct StepProgressView: View {
    var currentStep: Int
    var totalSteps: Int
    var stepText: String
    var hasError: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 0) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    stepItem(step: step)
                    
                    if step < totalSteps - 1 {
                        connectingLine(fromStep: step)
                    }
                }
            }
            .padding(.horizontal, 24)
            
            GlowText(text: stepText, color: hasError ? Color.red : ToolkitColors.green)
                .frame(height: 30)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ToolkitColors.darkBlue.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(ToolkitColors.accent.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private func stepItem(step: Int) -> some View {
        VStack(spacing: 8) {
            Circle()
                .fill(getStepColor(step))
                .frame(width: 18, height: 18)
                .shadow(color: getStepShadowColor(step), radius: 4)
                .zIndex(1)
            
            Text(getStepName(step))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(step <= currentStep ? .white : .gray)
        }
    }
    
    @ViewBuilder
    private func connectingLine(fromStep step: Int) -> some View {
        Rectangle()
            .fill(LinearGradient(
                gradient: Gradient(colors: [
                    getConnectionColor(step: step, isStart: true),
                    getConnectionColor(step: step, isStart: false)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            ))
            .frame(height: 2)
            .offset(y: -13)
    }
    
    private func getStepName(_ step: Int) -> String {
        switch step {
        case 0: return "开始"
        case 1: return "漏洞利用"
        case 2: return "Tweak"
        case 3: return "完成"
        default: return "步骤 \(step + 1)"
        }
    }
    
    private func getStepColor(_ step: Int) -> Color {
        if hasError && step == currentStep {
            return Color.red
        } else if step < currentStep {
            return ToolkitColors.green
        } else if step == currentStep {
            if step == 3 && !hasError {
                return ToolkitColors.green
            }
            return ToolkitColors.accent
        } else {
            return ToolkitColors.darkBlue
        }
    }
    
    private func getStepShadowColor(_ step: Int) -> Color {
        if hasError && step == currentStep {
            return Color.red.opacity(0.6)
        } else if step < currentStep {
            return ToolkitColors.green.opacity(0.6)
        } else if step == currentStep {
            return ToolkitColors.accent.opacity(0.6)
        } else {
            return Color.clear
        }
    }
    
    private func getConnectionColor(step: Int, isStart: Bool) -> Color {
        if isStart {
            if hasError && step + 1 == currentStep {
                return step < currentStep ? ToolkitColors.green : ToolkitColors.darkBlue
            } else {
                return step < currentStep ? ToolkitColors.green : (step == currentStep ? ToolkitColors.accent : ToolkitColors.darkBlue)
            }
        }
        else {
            if hasError && step + 1 == currentStep {
                return Color.red
            } else {
                return step + 1 < currentStep ? ToolkitColors.green : (step + 1 == currentStep ? ToolkitColors.accent : ToolkitColors.darkBlue)
            }
        }
    }
}

struct ToolkitButton: View {
    var icon: String
    var text: String
    var disabled: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(text)
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(disabled ? ToolkitColors.darkBlue.opacity(0.3) : ToolkitColors.mediumBlue)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(disabled ? Color.gray.opacity(0.2) : ToolkitColors.accent.opacity(0.5), lineWidth: 1)
                    )
            )
            .foregroundColor(disabled ? .gray : .white)
            .opacity(disabled ? 0.7 : 1)
        }
        .disabled(disabled)
    }
}

struct TweakCategoryView: View {
    var category: TweakCategory
    var tweaks: [TweakPathForFile]
    @Binding var isExpanded: Bool
    @Binding var enabledTweakIds: [String]
    @Binding var hasEnabledTweaks: Bool
    @ObservedObject var customTweakManager = CustomTweakManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            categoryHeader
            
            if isExpanded {
                tweaksList
            }
        }
    }
    
    private var categoryHeader: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        }) {
            HStack {
                Image(systemName: getCategoryIcon(category))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ToolkitColors.accent)
                    .frame(width: 26)
                
                Text(category.rawValue)
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Text("\(tweaks.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(ToolkitColors.capsuleBackground)
                    )
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
                    .padding(.leading, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ToolkitColors.categoryHeaderBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private var tweaksList: some View {
        VStack(spacing: 8) {
            ForEach(tweaks) { tweak in
                TweakRowView(
                    tweak: tweak,
                    isEnabled: enabledTweakIds.contains(tweak.id),
                    toggleAction: { toggleTweak(tweak) },
                    deleteAction: category == .custom ? { deleteTweak(tweak) } : nil,
                    isCustomTweak: category == .custom
                )
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 8)
        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
    }
    
    private func deleteTweak(_ tweak: TweakPathForFile) {
        if enabledTweakIds.contains(tweak.id) {
                enabledTweakIds.removeAll { $0 == tweak.id }
                hasEnabledTweaks = !enabledTweakIds.isEmpty
        }
            
        customTweakManager.deleteTweak(withID: tweak.id)
    }
    
    private func getCategoryIcon(_ category: TweakCategory) -> String {
        switch category {
        case .aesthetics: return "paintbrush.fill"
        case .performance: return "bolt.fill"
        case .privacy: return "lock.shield.fill"
        case .experimental: return "atom"
        case .custom: return "slider.horizontal.3"
        }
    }
    
    private func toggleTweak(_ tweak: TweakPathForFile) {
        if enabledTweakIds.contains(tweak.id) {
            enabledTweakIds.removeAll { $0 == tweak.id }
        } else {
            enabledTweakIds.append(tweak.id)
        }
        
        hasEnabledTweaks = !enabledTweakIds.isEmpty
    }
}

struct TweakRowView: View {
    var tweak: TweakPathForFile
    var isEnabled: Bool
    var toggleAction: () -> Void
    var deleteAction: (() -> Void)? = nil
    var isCustomTweak: Bool = false
    
    @State private var showDetails: Bool = false
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            tweakButton
            
            if showDetails {
                detailsView
            }
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("删除自定义调整"),
                message: Text("您确定要删除\"\(tweak.name)\"吗？此操作无法撤销。"),
                primaryButton: .destructive(Text("删除")) {
                    if let delete = deleteAction {
                        delete()
                    }
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }
    
    private var tweakButton: some View {
        Button(action: toggleAction) {
            HStack(spacing: 12) {
                // Tweak icon
                Image(systemName: tweak.icon)
                    .font(.system(size: 15))
                    .frame(width: 18)
                    .foregroundColor(isEnabled ? ToolkitColors.green : .white.opacity(0.7))
                
                // Tweak name
                Text(tweak.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 16) { // Increase spacing between buttons
                    // Delete button - only for custom tweaks
                    if isCustomTweak {
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundColor(Color.red.opacity(0.8))
                        }
                    }
                    
                    // Info button
                    Button(action: {
                        withAnimation {
                            showDetails.toggle()
                        }
                    }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundColor(ToolkitColors.accent.opacity(0.7))
                    }
                }
                .padding(.trailing, 8)
                
                // Toggle indicator
                ZStack {
                    Circle()
                        .stroke(isEnabled ? ToolkitColors.green.opacity(0.9) : Color.gray.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    
                    if isEnabled {
                        Circle()
                            .fill(ToolkitColors.green)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(ToolkitColors.darkBlue.opacity(0.3))
                    .modifier(NeonBorder(isActive: isEnabled, color: ToolkitColors.green.opacity(0.5)))
            )
        }
    }
    
    private var detailsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tweak.description)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.top, 6)
            
            Text("目标路径:")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(ToolkitColors.accent.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.top, 4)
            
            ForEach(tweak.paths, id: \.self) { path in
                Text(path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 12)
            }
        }
        .padding(.bottom, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

private class CancellableStore {
    var cancellables = Set<AnyCancellable>()
}

struct ContentView: View {
    let device = Device.current
    @AppStorage("enabledTweaks") private var enabledTweakIds: [String] = []
    @State private var progressStep: Int = 0
    @State private var progressText: String = "准备就绪"
    @State private var showLogs: Bool = false
    @State private var hasError: Bool = false
    @State private var categoryExpanded: [TweakCategory: Bool] = Dictionary(uniqueKeysWithValues: TweakCategory.allCases.map { ($0, false) })
    @State private var isVersionCompatible: Bool = true
    @State private var showAbout: Bool = false
    @State private var showRespringInstructions: Bool = false
    @State private var tweaksAppliedSuccessfully: Bool = false
    
    @State private var tweaks: [TweakPathForFile] = []
    @State private var isLoadingTweaks: Bool = false
    @State private var tweakLoadError: String? = nil
    @State private var hasEnabledTweaks: Bool = false
    @State private var showTerminalLog: Bool = false
    @State public var showFileManager: Bool = false
    
    @StateObject private var customTweakManager = CustomTweakManager.shared
    @State private var showCustomTweakCreator: Bool = false
    @State private var cancellableStore = CancellableStore()
    
    private var enabledTweaks: [TweakPathForFile] {
        let builtInTweaks = tweaks.filter { tweak in enabledTweakIds.contains(tweak.id) }
        let enabledCustomTweaks = customTweakManager.customTweaks.filter { tweak in
                enabledTweakIds.contains(tweak.id)
        }
        return builtInTweaks + enabledCustomTweaks
    }
    
    private var tweaksByCategory: [TweakCategory: [TweakPathForFile]] {
        var categories = Dictionary(grouping: loadedTweaks) { $0.category }
        categories[.custom] = customTweakManager.customTweaks
        return categories
    }
    
    // MARK: 正文
    var body: some View {
        mainView
            .onAppear {
                print("iDevice 工具包\n[*] 检测到设备  \(device.systemName!) \(device.systemVersion!), \(device.description)")
                checkVersionCompatibility()
                iDeviceLogger("[i] iDevice Central: 终端会话已启动")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    loadTweaks()
                    customTweakManager.loadCustomTweaks()
                }
                
            }
            .sheet(isPresented: $showTerminalLog) {
                iDeviceCentralTerminal()
            }
            .sheet(isPresented: $showCustomTweakCreator) {
                CustomTweakCreatorView()
            }
            .sheet(isPresented: $showFileManager) {
                SystemFileManagerView()
            }
    }
    
    private func checkVersionCompatibility() {
        let version = device.systemVersion ?? ""
        let versionComponents = version.split(separator: ".").map { Int($0) ?? 0 }
        
        if versionComponents.count >= 2 {
            let majorVersion = versionComponents[0]
            let minorVersion = versionComponents[1]
            let patchVersion = versionComponents.count >= 3 ? versionComponents[2] : 0
            
            isVersionCompatible = false
            
            // iOS 16.0 - iOS 16.7.10 Supported
            if majorVersion == 16 && minorVersion >= 0 {
                isVersionCompatible = true
            }
            // iOS 17.0 - iOS 17.7.5 Supported
            else if majorVersion == 17 && (minorVersion < 7 || (minorVersion == 7 && patchVersion <= 5)) {
                isVersionCompatible = true
            }
            // iOS 18.0 - iOS 18.3.2 Supported
            else if majorVersion == 18 && (minorVersion < 4) {
                isVersionCompatible = true
            }
            // iOS 15 and lower, iOS 17.7.6+, iOS 18.4+ Not Supported
            else {
                isVersionCompatible = false
            }
            
            if !isVersionCompatible {
                progressText = "不兼容的iOS版本"
                hasError = true
                print("[!] 检测到不兼容的iOS版本: \(version)")
                iDeviceLogger("[i] 检测到不兼容的iOS版本")
            }
        }
    }
    
    private func loadTweaks() {
            isLoadingTweaks = true
            tweakLoadError = nil
            
            DispatchQueue.global(qos: .userInitiated).async {
                TweaksService.shared.loadTweaks()
                    .sink(
                        receiveCompletion: { completion in
                            DispatchQueue.main.async {
                                self.isLoadingTweaks = false
                                
                                if case .failure(let error) = completion {
                                    iDeviceLogger("[!] 加载调整失败: \(error.localizedDescription)")
                                    self.tweakLoadError = error.localizedDescription
                                    print("[!] 加载调整失败: \(error.localizedDescription)")
                                    self.tweakLoadError = error.localizedDescription
                                }
                            }
                        },
                        receiveValue: { loadedTweaks in
                            DispatchQueue.main.async {
                                self.tweaks = loadedTweaks
                                print("[+] 成功加载 \(loadedTweaks.count) tweaks")
                                if !loadedTweaks.isEmpty {
                                    let categories = Dictionary(grouping: loadedTweaks) { $0.category }
                                    for (category, tweaks) in categories {
                                        iDeviceLogger("   • \(category.rawValue): \(tweaks.count) tweaks")
                                }
                            }
                        }
                    }
                )
            .store(in: &self.cancellableStore.cancellables)
        }
    }
    
    private var mainView: some View {
        ZStack {
            ToolkitColors.background
                .ignoresSafeArea()
            
            if isLoadingTweaks && tweaks.isEmpty {
                loadingView
            } else {
                ScrollViewReader { scrollProxy in
                    VStack(spacing: 0) {
                        headerView
                        
                        if let error = tweakLoadError {
                            errorView(message: error)
                        } else {
                            ScrollView {
                                contentStack
                            }
                            
                            applyButtonView(scrollProxy: scrollProxy)
                        }
                    }
                }
            }
            
            if showAbout {
                aboutOverlay
            }
            if showRespringInstructions {
                respringInstructionsOverlay
            }
        }
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            Text("正在加载调整...")
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .medium))
            Text("可能需要一点时间")
                .foregroundColor(.gray)
                .font(.system(size: 14))
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ToolkitColors.background)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.yellow)
            
            Text("加载调整失败")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(message)
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: loadTweaks) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("重试")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(ToolkitColors.accent)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var headerView: some View {
        HStack {
            Button(action: {
                withAnimation {
                    showAbout.toggle()
                }
            }) {
                Image(systemName: "info.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ToolkitColors.accent.opacity(0.9))
            }
            .padding(.trailing, 8)
            
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ToolkitColors.accent)
                
                Text("iDevice Toolkit")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            Spacer()
            
            Button(action: {
                iDeviceLogger("打开终端窗口")
                withAnimation {
                    showTerminalLog.toggle()
                }
            }) {
                Image(systemName: "terminal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ToolkitColors.accent.opacity(0.9))
            }
            .padding(.trailing, 8)
            
            Button(action: {
                withAnimation {
                    showFileManager.toggle()
                }
            }) {
                Image(systemName: "folder")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ToolkitColors.accent.opacity(0.9))
            }
            .padding(.trailing, 8)
            
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(ToolkitColors.headerBackground)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                .edgesIgnoringSafeArea(.top)
        )
        .preferredColorScheme(.dark)
    }
    
    private var contentStack: some View {
        VStack(spacing: 22) {
            deviceInfoView
            
            tweaksSection
        }
    }
    
    private var deviceInfoView: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.description)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("\(device.systemName!) \(device.systemVersion!)")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(ToolkitColors.darkGreen)
                        .frame(width: 14, height: 14)
                    
                    Circle()
                        .fill(!isVersionCompatible ? Color.red : ToolkitColors.green)
                        .frame(width: 8, height: 8)
                        .opacity(progressStep > 0 || !isVersionCompatible ? 1.0 : 0.0)
                }
                
                Text(!isVersionCompatible ? "不兼容" : (progressStep > 0 ? "激活中" : "准备就绪"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(!isVersionCompatible ? Color.red : (progressStep > 0 ? ToolkitColors.green : .gray))
            }
            .padding(.horizontal, 22)
            
            StepProgressView(
                currentStep: progressStep,
                totalSteps: 4,
                stepText: progressText,
                hasError: hasError || !isVersionCompatible
            )
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ToolkitColors.darkBlue.opacity(0.2))
        )
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .id("progressArea")
    }
    
    private var tweaksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("可用调整")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
            
            ForEach(TweakCategory.allCases, id: \.self) { category in
                if let categoryTweaks = tweaksByCategory[category] {
                    TweakCategoryView(
                        category: category,
                        tweaks: categoryTweaks,
                        isExpanded: .init(
                            get: { categoryExpanded[category] ?? false },
                            set: { categoryExpanded[category] = $0 }
                        ),
                        enabledTweakIds: $enabledTweakIds,
                        hasEnabledTweaks: $hasEnabledTweaks
                    )
                    .padding(.bottom, 8)
                }
            }
            
            CustomTweaksCategoryButton(showCustomTweakCreator: $showCustomTweakCreator)
                .padding(.bottom, 8)
            
            revertTweaksInfoPanel
                .padding(.bottom, 8)
            
            JailbreakNewsButton()
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
    }
    
    private var customTweaksCategoryView: some View {
            VStack(spacing: 0) {
                CustomTweaksCategoryButton(showCustomTweakCreator: $showCustomTweakCreator)
                
                if !customTweakManager.customTweaks.isEmpty {
                    TweakCategoryView(
                        category: .custom,
                        tweaks: customTweakManager.customTweaks,
                        isExpanded: .init(
                            get: { categoryExpanded[.custom] ?? false },
                            set: { categoryExpanded[.custom] = $0 }
                        ),
                        enabledTweakIds: $enabledTweakIds,
                        hasEnabledTweaks: $hasEnabledTweaks
                    )
                .padding(.top, 8)
            }
        }
    }
    
    private var revertTweaksInfoPanel: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(ToolkitColors.accent)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("怎么恢复？")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("如果遇到任何问题或想要恢复到默认设置！重启iPhone恢复")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ToolkitColors.darkBlue.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(ToolkitColors.accent.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    struct JailbreakNewsButton: View {
        var body: some View {
            Button(action: {
                if let url = URL(string: "https://raw.githubusercontent.com/pxx917144686/iDevice_ZH/refs/heads/main/VM_BEHAVIOR_ZERO_WIRED_PAGES.c") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(ToolkitColors.green)
                        .frame(width: 26)
                    
                    Text("关于漏洞CVE-2025-24203")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                        .padding(.leading, 8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ToolkitColors.categoryHeaderBackground)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
    
    private func applyButtonView(scrollProxy: ScrollViewProxy) -> some View {
        VStack(spacing: 12) {
            ToolkitButton(
                icon: tweaksAppliedSuccessfully ? "arrow.clockwise" : "bolt.fill",
                text: tweaksAppliedSuccessfully ? "重新加载以应用" :
                    (progressStep > 0 ? "取消操作" : "应用调整"),
                disabled: !hasEnabledTweaks && progressStep == 0 && !tweaksAppliedSuccessfully || !isVersionCompatible
            ) {
                if progressStep > 0 {
                    resetProgress()
                } else if tweaksAppliedSuccessfully {
                    withAnimation {
                        showRespringInstructions = true
                    }
                } else {
                    runOperation()
                    
                    withAnimation {
                        scrollProxy.scrollTo("progressArea", anchor: .top)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(
            Rectangle()
                .fill(ToolkitColors.background)
                .shadow(color: .black.opacity(0.4), radius: 8, y: -4)
        )
    }
    
    private var aboutOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showAbout = false
                    }
                }
            VStack(spacing: 0) {
                HStack {
                    Text("关于 iDevice 工具")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            showAbout = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(ToolkitColors.darkBlue)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("iDevice_ZH")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(ToolkitColors.accent)
                        
                        Text("iOS工具")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Group {
                            Text("由 [pxx917144686](https://github.com/pxx917144686/iDevice_ZH) 修改")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                                .tint(ToolkitColors.accent)
                            
                            Text("• [GeoSn0w 的 Twitter](https://twitter.com/FCE365)")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                                .tint(ToolkitColors.accent)
                                .padding(.top, 4)
                            
                            Text("• [iDevice Central 的 YouTube](https://youtube.com/@idevicecentral)")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                                .tint(ToolkitColors.accent)
                        }
                        
                        Divider()
                            .background(Color.gray.opacity(0.3))
                            .padding(.vertical, 4)
                        
                        Group {
                            Text("• 重启 👉 恢复。")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Text("• 漏洞利用由Google Project Zero的Ian Beer发现")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                            
                        }
                        
                        Divider()
                            .background(Color.gray.opacity(0.3))
                            .padding(.vertical, 8)
                        
                        Group {
                            Text("**致谢名单**")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.bottom, 4)
                            
                            Text("• 感谢 [jailbreak.party](https://github.com/jailbreakdotparty) 的dirtyZero项目提供原始灵感、代码和调整路径")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                                .tint(ToolkitColors.accent)
                            
                            Text("• 感谢 [straight_tamago](https://twitter.com/straight_tamago) 的mdc0项目提供原始灵感、代码和调整路径")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                                .tint(ToolkitColors.accent)
                            
                            Text("• 特别感谢Ian Beer发现CVE-2025-24203漏洞 ([查看详情](https://project-zero.issues.chromium.org/issues/391518636))")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                                .tint(ToolkitColors.accent)
                            
                            Text("• [工具箱图标由Freepik - Flaticon创建](https://www.flaticon.com/free-icons/tool-box)")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                                .tint(ToolkitColors.accent)
                        }
                    }
                    .padding(16)
                }
                .background(ToolkitColors.background)
            }
            .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.6)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.5), radius: 20)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }
    
    // MARK: Functions
    private func runOperation() {
        guard !enabledTweaks.isEmpty else { return }
        hasError = false
        
        iDeviceLogger("[*] 开始操作，已启用 \(enabledTweaks.count) 个调整")
        
        withAnimation {
            progressStep = 1
            progressText = "正在运行漏洞利用..."
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                progressStep = 2
                progressText = "正在应用 \(self.enabledTweaks.count) 个调整..."
                
                var applyingString = "[+] 正在应用选定的调整: "
                let tweakNames = self.enabledTweaks.map { $0.name }.joined(separator: ", ")
                applyingString += tweakNames
                iDeviceLogger(applyingString)
                
                iDeviceLogger("\n[*] 调整详细信息:")
                for (index, tweak) in self.enabledTweaks.enumerated() {
                    iDeviceLogger("\n[\(index + 1)/\(self.enabledTweaks.count)] 调整: \(tweak.name)")
                    
                    iDeviceLogger("    • 需要修改的路径:")
                    
                    for (pathIndex, path) in tweak.paths.enumerated() {
                        iDeviceLogger("      \(pathIndex + 1). \(path)")
                    }
                }
                
                iDeviceLogger("\n[*] 开始调整应用过程...")
            }
            
            let stats = TweakStats()
            
            self.processTweaks(tweaks: self.enabledTweaks, index: 0, stats: stats) {
                self.proceedToVerification(successCount: stats.successCount, failedCount: stats.failedCount)
                withAnimation {
                    showTerminalLog.toggle()
                }
            }
        }
    }
    
    private class TweakStats {
        var successCount: Int = 0
        var failedCount: Int = 0
        var pathsSucceeded: Int = 0
        var pathsFailed: Int = 0
        
        var pathFailures: [(path: String, reason: String)] = []
        
        func addFailedPath(path: String, reason: String) {
            pathsFailed += 1
            pathFailures.append((path: path, reason: reason))
        }
    }
    
    private func processTweaks(tweaks: [TweakPathForFile], index: Int, stats: TweakStats, completion: @escaping () -> Void) {
        guard index < tweaks.count else {
            iDeviceLogger("\n[*] iDevice 工具包调整日志")
            if stats.successCount > 0 {
                iDeviceLogger("[✓] \(stats.successCount) 个调整应用成功")
            }
            if stats.failedCount > 0 {
                iDeviceLogger("[✗] \(stats.failedCount) 个调整应用失败")
            }
            completion()
            return
        }
        
        let tweak = tweaks[index]
        iDeviceLogger("\n[*] 处理调整 [\(index + 1)/\(tweaks.count)]: \(tweak.name)")
        
        let pathStats = TweakStats()
        
        self.processPaths(tweak: tweak, pathIndex: 0, pathStats: pathStats) {
            iDeviceLogger("----------------------------------------------")
            
            if pathStats.pathsFailed == 0 {
                stats.successCount += 1
                iDeviceLogger("✅ 调整状态: \(tweak.name) - 应用成功")
                iDeviceLogger("   • 所有 \(pathStats.pathsSucceeded) 个路径修改成功")
            } else if pathStats.pathsSucceeded > 0 {
                stats.failedCount += 1
                iDeviceLogger("⚠️ 调整状态: \(tweak.name) - 部分应用")
                iDeviceLogger("   • \(pathStats.pathsSucceeded) 个路径成功")
                iDeviceLogger("   • \(pathStats.pathsFailed) 个路径失败")
                
                if !pathStats.pathFailures.isEmpty {
                    iDeviceLogger("   • 失败详情:")
                    for (index, failure) in pathStats.pathFailures.enumerated() {
                        iDeviceLogger("     \(index + 1). 路径: \(failure.path)")
                        iDeviceLogger("        原因: \(failure.reason)")
                    }
                }
            } else {
                stats.failedCount += 1
                iDeviceLogger("❌ 调整状态: \(tweak.name) - 失败")
                iDeviceLogger("   • 所有 \(pathStats.pathsFailed) 个路径应用失败")
                
                if !pathStats.pathFailures.isEmpty {
                    iDeviceLogger("   • 失败详情:")
                    for (index, failure) in pathStats.pathFailures.enumerated() {
                        iDeviceLogger("     \(index + 1). 路径: \(failure.path)")
                        iDeviceLogger("        原因: \(failure.reason)")
                    }
                }
            }
            iDeviceLogger("----------------------------------------------")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.processTweaks(tweaks: tweaks, index: index + 1, stats: stats, completion: completion)
            }
        }
    }    
    private func processPaths(tweak: TweakPathForFile, pathIndex: Int, pathStats: TweakStats, completion: @escaping () -> Void) {
        guard pathIndex < tweak.paths.count else {
            iDeviceLogger("[*] 完成处理 \(tweak.name) 的所有路径")
            completion()
            return
        }
        
        let path = tweak.paths[pathIndex]
        
        iDeviceLogger("[>] 调整 \(tweak.name): 处理路径 [\(pathIndex + 1)/\(tweak.paths.count)]: \(path)")
        
        do {
            let errorReason = try runExploitForPath(path: path)
            if errorReason == nil {
                pathStats.pathsSucceeded += 1
                iDeviceLogger("[+] 路径漏洞利用成功: \(path)")
            } else if let reason = errorReason {
                pathStats.addFailedPath(path: path, reason: reason)
                iDeviceLogger("[!] 应用路径时出错: \(path)")
                iDeviceLogger("    错误详情: \(reason)")
            }
        } catch {
            let reason: String
            if let nsError = error as NSError? {
                reason = nsError.localizedDescription
                pathStats.addFailedPath(path: path, reason: reason)
            } else {
                reason = error.localizedDescription
                pathStats.addFailedPath(path: path, reason: reason)
            }
            
            iDeviceLogger("[!] 应用路径时出错: \(path)")
            iDeviceLogger("    错误详情: \(reason)")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.processPaths(tweak: tweak, pathIndex: pathIndex + 1, pathStats: pathStats, completion: completion)
        }
    }
    
    private func proceedToVerification(successCount: Int, failedCount: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                progressStep = 3
                progressText = "正在验证更改..."
                
                iDeviceLogger("\n[*] 验证调整应用结果")
                
                self.hasError = successCount == 0 && failedCount > 0
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation {
                        iDeviceLogger("\n================================================")
                        iDeviceLogger("                最终操作结果                     ")
                        iDeviceLogger("================================================")
                        
                        if failedCount == 0 {
                            progressText = "调整应用成功！"
                            iDeviceLogger("✅ 成功: 所有 \(successCount) 个调整应用成功！")
                            tweaksAppliedSuccessfully = true
                            progressStep = 0
                        } else if successCount > 0 {
                            progressText = "\(successCount) 个调整已应用，\(failedCount) 个失败"
                            iDeviceLogger("⚠️ 部分成功: \(successCount) 个调整应用成功，\(failedCount) 个失败")
                            tweaksAppliedSuccessfully = successCount > 0
                            progressStep = 0
                        } else {
                            progressText = "无法应用任何调整"
                            iDeviceLogger("❌ 失败: 无法应用任何调整")
                            self.hasError = true
                            tweaksAppliedSuccessfully = false
                        }
                        
                        if tweaksAppliedSuccessfully {
                            iDeviceLogger("\n[*] 下一步:")
                            iDeviceLogger("   1. 重新加载设备以应用更改")
                            iDeviceLogger("   2. 前往 设置 > 显示与亮度")
                            iDeviceLogger("   3. 点击显示缩放并切换视图以触发重新加载")
                        } else {
                            iDeviceLogger("\n[*] 下一步:")
                            iDeviceLogger("   • 尝试使用不同的调整或检查设备兼容性")
                        }
                        
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        let timestamp = dateFormatter.string(from: Date())
                        iDeviceLogger("\n[*] 操作完成于 \(timestamp)")
                        iDeviceLogger("================================================")
                    }
                }
            }
        }
    }
    
    private var respringInstructionsOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showRespringInstructions = false
                        tweaksAppliedSuccessfully = false
                    }
                }
            
            VStack(spacing: 0) {
                HStack {
                    Text("需要重新加载")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            showRespringInstructions = false
                            tweaksAppliedSuccessfully = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(ToolkitColors.darkBlue)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("由于漏洞利用的限制，您需要手动重新加载设备以使调整生效。")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .padding(.bottom, 4)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("操作说明:")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ToolkitColors.accent)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                Text("1.")
                                    .foregroundColor(.white)
                                    .frame(width: 20, alignment: .leading)
                                Text("前往 设置 > 显示与亮度")
                                    .foregroundColor(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            HStack(alignment: .top) {
                                Text("2.")
                                    .foregroundColor(.white)
                                    .frame(width: 20, alignment: .leading)
                                Text("向下滚动至显示缩放")
                                    .foregroundColor(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            HStack(alignment: .top) {
                                Text("3.")
                                    .foregroundColor(.white)
                                    .frame(width: 20, alignment: .leading)
                                Text("在默认和放大文字选项之间切换")
                                    .foregroundColor(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            HStack(alignment: .top) {
                                Text("4.")
                                    .foregroundColor(.white)
                                    .frame(width: 20, alignment: .leading)
                                Text("这将触发重新加载")
                                    .foregroundColor(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            HStack(alignment: .top) {
                                Text("5.")
                                    .foregroundColor(.white)
                                    .frame(width: 20, alignment: .leading)
                                Text("之后您可以切换回您喜欢的选项")
                                    .foregroundColor(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .font(.system(size: 14))
                        
                        Spacer(minLength: 20)
                        
                        Button(action: {
                            withAnimation {
                                showRespringInstructions = false
                                tweaksAppliedSuccessfully = false
                            }
                        }) {
                            Text("知道了！")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(ToolkitColors.accent)
                                )
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 10)
                    }
                    .padding(16)
                }
                .background(ToolkitColors.background)
            }
            .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.5)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.5), radius: 20)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }
    
    private func resetProgress() {
        withAnimation {
            progressStep = 0
            progressText = "> 准备就绪"
            hasError = false
            tweaksAppliedSuccessfully = false
        }
        print("[!] 调整被取消。")
    }
    
    private func runExploitForPath(path: String) throws -> String? {
        iDeviceLogger("[*] 对路径运行漏洞利用: \(path)")
        
        guard let cPath = strdup(path) else {
            let errorMessage = "为路径分配内存失败"
            iDeviceLogger("[!] 错误: \(errorMessage)")
            return errorMessage
        }
        
        defer {
            free(cPath)
        }
        
        let result = poc(cPath)
        
        if result != 0 {
            let errorMessage: String
            switch result {
            case 2: // ENOENT
                errorMessage = "文件未找到 - 路径不存在"
            case 13: // EACCES
                errorMessage = "权限被拒绝 - 无法访问文件"
            case 1: // EPERM
                errorMessage = "操作不被允许 - 权限不足"
            case 21: // EISDIR
                errorMessage = "预期文件但找到目录"
            case 20: // ENOTDIR
                errorMessage = "预期目录但找到文件"
            case 28: // ENOSPC
                errorMessage = "设备上没有剩余空间"
            case 9: // EBADF
                errorMessage = "错误的文件描述符"
            case 22: // EINVAL
                errorMessage = "操作的参数无效"
            default:
                errorMessage = "漏洞利用失败，代码 \(result)"
            }
            
            iDeviceLogger("[!] 漏洞利用错误: \(errorMessage)")
            throw NSError(domain: "ExploitError", code: Int(result), userInfo: [NSLocalizedDescriptionKey: errorMessage])
            
        } else {
            iDeviceLogger("[+] 路径漏洞利用成功: \(path)")
            return nil
        }
    }
}

#Preview {
    ContentView()
}