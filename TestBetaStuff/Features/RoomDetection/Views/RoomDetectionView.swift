import SwiftUI

struct RoomDetectionView: View {
    @StateObject private var viewModel = RoomDetectionViewModel()
    @State private var showProfileEditor = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Status Header
                statusHeader

                // Content
                if viewModel.isActive {
                    activeContent
                } else {
                    inactiveContent
                }
            }
            .navigationTitle("Room Detection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showProfileEditor.toggle()
                    } label: {
                        Image(systemName: "person.circle")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showProfileEditor) {
                ProfileEditorView(
                    displayName: viewModel.userProfile.displayName,
                    onSave: { newName in
                        viewModel.updateProfile(displayName: newName)
                        showProfileEditor = false
                    },
                    onCancel: {
                        showProfileEditor = false
                    }
                )
            }
        }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        VStack(spacing: 12) {
            // Status indicator
            HStack {
                Circle()
                    .fill(viewModel.isActive ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)

                Text(viewModel.isActive ? "Active" : "Inactive")
                    .font(.headline)
                    .foregroundColor(viewModel.isActive ? .green : .secondary)

                Spacer()

                // Toggle button
                Button(action: viewModel.toggleDetection) {
                    Text(viewModel.isActive ? "Stop" : "Start")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(viewModel.isActive ? Color.red : Color.blue)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)

            // User info
            VStack(spacing: 4) {
                Text(viewModel.userProfile.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("ID: \(viewModel.userProfile.id.prefix(8))...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 8)

            Divider()
        }
    }

    // MARK: - Active Content

    private var activeContent: some View {
        VStack(spacing: 0) {
            // Detected peers section
            peersSection

            Divider()

            // Message input section
            messageSection

            Divider()

            // Logs section
            logsSection
        }
    }

    // MARK: - Peers Section

    private var peersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Detected Friends")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 12)

                Spacer()

                Text("\(viewModel.detectedPeers.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .cornerRadius(8)
                    .padding(.trailing)
                    .padding(.top, 12)
            }

            if viewModel.detectedPeers.isEmpty {
                emptyPeersView
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(viewModel.detectedPeers) { peer in
                            PeerRowView(peer: peer)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 200)
            }
        }
    }

    private var emptyPeersView: some View {
        VStack(spacing: 8) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("Searching for friends...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: - Message Section

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Send Test Message")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 12)

            HStack(spacing: 12) {
                TextField("Type a message...", text: $viewModel.messageText)
                    .textFieldStyle(.roundedBorder)

                Button(action: viewModel.sendTestMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(viewModel.messageText.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(8)
                }
                .disabled(viewModel.messageText.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Logs Section

    private var logsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Debug Logs")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 12)

                Spacer()

                Button("Clear") {
                    viewModel.clearLogs()
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.trailing)
                .padding(.top, 12)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.logs) { log in
                        HStack(alignment: .top, spacing: 8) {
                            Text(log.formattedTime)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)

                            Text(log.message)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)

                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 2)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Inactive Content

    private var inactiveContent: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right.circle")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            VStack(spacing: 8) {
                Text("Room Detection")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Automatically detect friends nearby")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "wave.3.right", text: "iBeacon broadcasting")
                FeatureRow(icon: "wifi", text: "Multipeer connectivity")
                FeatureRow(icon: "lock.fill", text: "Encrypted connections")
                FeatureRow(icon: "bolt.fill", text: "Fully automatic")
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)

            Text("Tap Start to begin detecting friends")
                .font(.callout)
                .foregroundColor(.secondary)
                .padding(.top, 8)

            Spacer()
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

// MARK: - Profile Editor View

struct ProfileEditorView: View {
    @State var displayName: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Information")) {
                    TextField("Display Name", text: $displayName)
                        .autocorrectionDisabled()
                }

                Section {
                    Text("This name will be visible to other users when you connect.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(displayName)
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RoomDetectionView()
}
