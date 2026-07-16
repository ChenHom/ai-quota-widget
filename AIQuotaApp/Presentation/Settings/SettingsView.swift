import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var urlInput = ""
    @State private var showingResetAlert = false
    @State private var testSuccess = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("HTTPS Endpoint")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                        
                        TextField("https://example.com/quota.json", text: $urlInput)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .font(.body)
                    }
                    .padding(.vertical, 4)
                    
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView("測試連線中...")
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else {
                        Button {
                            Task {
                                testSuccess = false
                                let success = await viewModel.saveEndpoint(urlInput)
                                if success {
                                    testSuccess = true
                                    // 延遲關閉讓使用者看到打勾動畫
                                    try? await Task.sleep(nanoseconds: 800_000_000)
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack {
                                Spacer()
                                if testSuccess {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(SemanticColor.green.color)
                                    Text("連線成功並儲存")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(SemanticColor.green.color)
                                } else {
                                    Text("連線測試並儲存")
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                            }
                        }
                        .disabled(urlInput.isEmpty)
                    }
                } header: {
                    Text("API 連線設定")
                } footer: {
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(SemanticColor.red.color)
                            .font(.caption)
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        labelRow(icon: "shield.fill", color: .blue, text: "此 App 僅接受加密的 HTTPS 連線。")
                        labelRow(icon: "wifi", color: .orange, text: "若連線端點位於區網內 (LAN)，請確保已允許 App 的「本機網路」存取權限。")
                        labelRow(icon: "lock.badge.clock.fill", color: .red, text: "若使用自簽憑證 (如 mkcert)，您的 iPhone 必須安裝並完整信任該 CA，且 SAN 欄位需涵蓋伺服器網址。")
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("區域網路與安全憑證排錯提示")
                }
                
                if viewModel.hasEndpoint {
                    Section {
                        Button(role: .destructive) {
                            showingResetAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("重設端點並清除本機快取")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("設定 API 端點")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("確定重設端點？", isPresented: $showingResetAlert) {
                Button("確定清除", role: .destructive) {
                    viewModel.resetConnection()
                    urlInput = ""
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("這將移除目前設定的 API 網址，並將 App Group 中的共用快取清除，Widget 也將回復至未設定狀態。")
            }
            .onAppear {
                urlInput = viewModel.endpoint
            }
        }
    }
    
    private func labelRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 18)
                .font(.system(size: 14))
            
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
    }
}

#Preview {
    let vm = AppViewModel()
    SettingsView(viewModel: vm)
}
