import SwiftUI

@main
struct AIQuotaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var viewModel = AppViewModel()
    @State private var showingSettings = false
    
    var body: some View {
        Group {
            if viewModel.hasEndpoint {
                DashboardView(viewModel: viewModel)
            } else {
                setupGuideView
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }
    
    private var setupGuideView: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                // Tech-themed logo circle with gradients
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.12), Color.purple.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 150, height: 150)
                    
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(spacing: 12) {
                    Text("AI Quota")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                    
                    Text("隨時掌握 Codex、Claude 與 AGY 的剩餘額度\n支援 Home Screen Widget 快速查看與過期標記")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                Button {
                    showingSettings = true
                } label: {
                    HStack {
                        Image(systemName: "link")
                        Text("開始設定 HTTPS 連線")
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.blue.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(viewModel: viewModel)
            }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "aiquota" else { return }
        if url.host == "dashboard" {
            // 開啟 App 並觸發重新整理
            if viewModel.hasEndpoint {
                Task {
                    await viewModel.refresh()
                }
            }
        }
    }
}
