import SwiftUI

struct MinecraftFriendsSheetChrome<Header: View, BodyContent: View, Footer: View>: View {
    private let limitBodyScrollHeight: Bool
    private let header: () -> Header
    private let bodyContent: () -> BodyContent
    private let footer: () -> Footer

    init(
        limitBodyScrollHeight: Bool,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder body: @escaping () -> BodyContent,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.limitBodyScrollHeight = limitBodyScrollHeight
        self.header = header
        self.bodyContent = body
        self.footer = footer
    }

    var body: some View {
        VStack(spacing: 0) {
            header()
                .padding(.horizontal)
                .padding()
            Divider()
            if limitBodyScrollHeight {
                ScrollView {
                    bodyContent()
                        .padding(.horizontal)
                        .padding()
                }
                .frame(maxHeight: 400)
            } else {
                bodyContent()
                    .padding(.horizontal)
                    .padding()
            }
            Divider()
            footer()
                .padding(.horizontal)
                .padding()
        }
    }
}

public struct MinecraftFriendsSheetView<Skin: View>: View {
    private let playerId: String
    @ObservedObject private var viewModel: MinecraftFriendsSheetViewModel
    private let localize: (String) -> String
    private let limitBodyScrollHeight: Bool
    private let skinView: (String, String?) -> Skin

    @Environment(\.dismiss)
    private var dismiss

    @State private var showAddFriendPopover = false
    @FocusState private var addFriendFieldFocused: Bool

    public init(
        playerId: String,
        viewModel: MinecraftFriendsSheetViewModel,
        localize: @escaping (String) -> String,
        limitBodyScrollHeight: Bool,
        @ViewBuilder skinView: @escaping (String, String?) -> Skin
    ) {
        self.playerId = playerId
        self.viewModel = viewModel
        self.localize = localize
        self.limitBodyScrollHeight = limitBodyScrollHeight
        self.skinView = skinView
    }

    public var body: some View {
        MinecraftFriendsSheetChrome(limitBodyScrollHeight: limitBodyScrollHeight) {
            headerBar
        } body: {
            bodyContent
        } footer: {
            footerBar
        }
        .id(playerId)
        .onDisappear {
            viewModel.clearLoadedData()
        }
    }

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(localize("minecraft.friends.sheet.title"))
                .font(.headline)
            Spacer()
            Button {
                showAddFriendPopover = true
            } label: {
                Text(localize("minecraft.friends.add.open"))
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoading)
            .popover(isPresented: $showAddFriendPopover, arrowEdge: .bottom) {
                addFriendPopoverContent
                    .presentationCompactAdaptation(.popover)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var bodyContent: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if isEmptyState {
                Text(localize("minecraft.friends.empty"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        friendsListSection(
                            sectionId: "friends",
                            title: localize("minecraft.friends.section.friends"),
                            dtos: viewModel.uiData.lists.friends,
                            rowActions: .confirmed
                        )
                        friendsListSection(
                            sectionId: "incoming",
                            title: localize("minecraft.friends.section.incoming"),
                            dtos: viewModel.uiData.lists.incomingRequests,
                            rowActions: .incoming
                        )
                        friendsListSection(
                            sectionId: "outgoing",
                            title: localize("minecraft.friends.section.outgoing"),
                            dtos: viewModel.uiData.lists.outgoingRequests,
                            rowActions: .outgoing
                        )
                    }
                }
                .frame(maxWidth: 400)
            }
        }
    }

    private var footerBar: some View {
        HStack {
            Button {
                Task { await viewModel.load(forceRefresh: true) }
            } label: {
                Text(localize("minecraft.friends.refresh"))
            }
            .disabled(viewModel.isLoading)

            Spacer()

            Button(localize("common.close")) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
    }

    @ViewBuilder private var addFriendPopoverContent: some View {
        HStack {
            TextField(localize("minecraft.friends.add.placeholder"), text: $viewModel.addFriendName)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 240)
                .focused($addFriendFieldFocused)
                .disabled(viewModel.isLoading)
                .onSubmit { submitAddFriendFromPopover() }
            Button(localize("minecraft.friends.add.button")) {
                submitAddFriendFromPopover()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(viewModel.isLoading)
        }
        .padding()
        .onAppear {
            addFriendFieldFocused = true
        }
    }

    private func submitAddFriendFromPopover() {
        let trimmed = viewModel.addFriendName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { @MainActor in
            await viewModel.sendFriendRequest()
            showAddFriendPopover = false
        }
    }

    private var isEmptyState: Bool {
        let l = viewModel.uiData.lists
        return l.friends.isEmpty && l.incomingRequests.isEmpty && l.outgoingRequests.isEmpty
    }

    @ViewBuilder
    private func friendsListSection(sectionId: String, title: String, dtos: [MinecraftFriendProfileDTO], rowActions: RowActions) -> some View {
        if !dtos.isEmpty {
            sectionHeader(title)
            ForEach(dtos, id: \.profileId.normalized) { dto in
                friendRow(dto: dto, rowActions: rowActions)
                    .id("\(sectionId)-\(rowActions.rawValue)-\(dto.profileId.normalized)")
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private enum RowActions: String {
        case confirmed
        case incoming
        case outgoing
    }

    private func friendRow(dto: MinecraftFriendProfileDTO, rowActions: RowActions) -> some View {
        let pid = dto.profileId.normalized
        let presence = viewModel.uiData.presenceByProfileId[pid]
        let skinSrc = viewModel.skinTextureURLString(forUUIDNormalized: pid)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                skinView(pid, skinSrc)
                    .id("\(pid)-\(skinSrc ?? "")")
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dto.name)
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                        if rowActions == .confirmed,
                           presence?.joinInfo?.invited == true {
                            Text(localize("minecraft.friends.invite.invited_hint"))
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 4)
                    presenceBadge(presence?.status)
                }
                actionButtons(for: dto, rowActions: rowActions)
            }
        }
    }

    @ViewBuilder
    private func actionButtons(for dto: MinecraftFriendProfileDTO, rowActions: RowActions) -> some View {
        let wireId = dto.profileId.dashedLowercase
        switch rowActions {
        case .confirmed:
            Button(localize("minecraft.friends.action.remove")) {
                Task { await viewModel.removeFriend(profileId: wireId) }
            }
            .disabled(viewModel.isLoading)
            .controlSize(.small)
        case .incoming:
            HStack(spacing: 6) {
                Button(localize("minecraft.friends.action.accept")) {
                    Task { await viewModel.acceptIncoming(profileId: wireId) }
                }
                .disabled(viewModel.isLoading)
                .controlSize(.small)
                Button(localize("minecraft.friends.action.decline")) {
                    Task { await viewModel.declineIncoming(profileId: wireId) }
                }
                .disabled(viewModel.isLoading)
                .controlSize(.small)
            }
        case .outgoing:
            Button(localize("minecraft.friends.action.revoke")) {
                Task { await viewModel.revokeOutgoing(profileId: wireId) }
            }
            .disabled(viewModel.isLoading)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private func presenceBadge(_ status: MinecraftPresenceWireStatus?) -> some View {
        let s = status ?? .offline
        HStack(spacing: 6) {
            Circle()
                .fill(presenceColor(s))
                .frame(width: 7, height: 7)
            Text(localize(presenceTitleKey(s)))
                .font(.caption.weight(.medium))
                .foregroundStyle(presenceColor(s))
        }
        .accessibilityElement(children: .combine)
    }

    private func presenceColor(_ s: MinecraftPresenceWireStatus) -> Color {
        switch s {
        case .online, .playingServer, .playingHostedServer, .playingRealms:
            return .green
        case .playingOffline:
            return .orange
        case .offline:
            return Color.secondary.opacity(0.45)
        }
    }

    private func presenceTitleKey(_ s: MinecraftPresenceWireStatus) -> String {
        switch s {
        case .online:
            return "minecraft.friends.presence.online"
        case .offline:
            return "minecraft.friends.presence.offline"
        case .playingOffline:
            return "minecraft.friends.presence.playing_offline"
        case .playingRealms:
            return "minecraft.friends.presence.playing_realms"
        case .playingServer:
            return "minecraft.friends.presence.playing_server"
        case .playingHostedServer:
            return "minecraft.friends.presence.playing_hosted_server"
        }
    }
}
