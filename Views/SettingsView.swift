import SwiftUI

struct SettingsView: View {
    @Environment(UserViewModel.self) private var userViewModel
    @Environment(\.dismiss) private var dismiss

    @AppStorage("kaiColorScheme") private var colorSchemeRaw: String = "system"
    @State private var showingOnboarding = false
    @State private var showingJoinSheet = false
    @State private var showingProgressSheet = false

    var body: some View {
        NavigationStack {
            Form {

                // MARK: - Getting Started
                Section("Getting Started") {
                    Button {
                        showingOnboarding = true
                    } label: {
                        Label("How to Use Kai To Do", systemImage: "sparkles")
                            .foregroundStyle(Color.kaiPurple)
                    }
                }

                // MARK: - Lists & Buddies
                Section {
                    Button {
                        showingJoinSheet = true
                    } label: {
                        Label("Join a List", systemImage: "person.badge.plus")
                            .foregroundStyle(.primary)
                    }

                    Button {
                        showingProgressSheet = true
                    } label: {
                        Label("Family Progress", systemImage: "chart.bar.fill")
                            .foregroundStyle(.primary)
                    }
                } header: {
                    Text("Lists & Buddies")
                } footer: {
                    Text("Join a shared list with an invite code and see how your whole family is doing.")
                }

                // MARK: - Appearance
                Section("Appearance") {
                    Picker(selection: $colorSchemeRaw) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    } label: {
                        Label("Color Scheme", systemImage: "circle.lefthalf.filled")
                    }
                }

                // MARK: - Feedback
                Section {
                    Button {
                        let subject = "Kai%20To%20Do%20Feedback"
                        let body = "Hi%20KindCode%20team%2C%0A%0A"
                        if let url = URL(string: "mailto:kindcodedevelopment@gmail.com?subject=\(subject)&body=\(body)") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Report a Bug or Request a Feature", systemImage: "envelope.fill")
                            .foregroundStyle(Color.kaiPurple)
                    }
                } header: {
                    Text("Feedback")
                } footer: {
                    Text("Your feedback goes directly to the KindCode team. We read every message! 💙")
                }

                // MARK: - About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Created by ")
                            .foregroundStyle(.secondary)
                        + Text("KindCode")
                            .foregroundStyle(Color.kaiTeal)
                        Spacer()
                    }
                    .onTapGesture {
                        if let url = URL(string: "https://kindcode.us") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showingOnboarding) {
                OnboardingView(isReplay: true) {
                    showingOnboarding = false
                }
            }
            .sheet(isPresented: $showingJoinSheet) {
                JoinListSheet()
            }
            .sheet(isPresented: $showingProgressSheet) {
                FamilyProgressSheet()
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

#Preview {
    SettingsView()
        .environment(UserViewModel())
}
