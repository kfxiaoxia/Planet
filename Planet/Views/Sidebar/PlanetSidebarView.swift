//
//  PlanetSidebarView.swift
//  Planet
//
//  Created by Kai on 2/20/22.
//

import SwiftUI


struct PlanetSidebarLoadingIndicatorView: View {
    @EnvironmentObject private var planetStore: PlanetStore

    @State private var timerState: Int = 0
    @State private var hourglass: String = "hourglass.bottomhalf.filled"

    var body: some View {
        VStack {
            Image(systemName: hourglass)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 12, height: 12, alignment: .center)
        }
        .padding(0)
        .onReceive(planetStore.indicatorTimer) { t in
            if timerState > 2 {
                timerState = 0
            }
            switch timerState {
            case 1:
                hourglass = "hourglass"
            case 2:
                hourglass = "hourglass.tophalf.filled"
            default:
                hourglass = "hourglass.bottomhalf.filled"
            }
            timerState += 1
        }
    }
}


struct PlanetSidebarToolbarButtonView: View {
    @EnvironmentObject private var planetStore: PlanetStore
    @Environment(\.managedObjectContext) private var context

    var body: some View {
        Button {
            planetStore.isShowingPlanetInfo = true
        } label: {
            Image(systemName: "info.circle")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 16, height: 16, alignment: .center)
        }
        .disabled(planetStore.currentPlanet == nil)

        Button {
            if let planet = planetStore.currentPlanet, planet.isMyPlanet() {
                PlanetWriterManager.shared.launchWriter(forPlanet: planet)
            }
        } label: {
            Image(systemName: "square.and.pencil")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 16, height: 16, alignment: .center)
        }
        .disabled(planetStore.currentPlanet == nil || !planetStore.currentPlanet!.isMyPlanet())
    }
}


struct PlanetSidebarView: View {
    @EnvironmentObject private var planetStore: PlanetStore

    @FetchRequest(
            sortDescriptors: [SortDescriptor(\.created, order: .reverse)],
            predicate: NSPredicate(format: "softDeleted == nil"),
            animation: Animation.easeInOut
    ) var planets: FetchedResults<Planet>
    @FetchRequest(
            sortDescriptors: [SortDescriptor(\.created, order: .reverse)],
            predicate: NSPredicate(format: "softDeleted == nil"),
            animation: Animation.easeInOut
    ) var articles: FetchedResults<PlanetArticle>
    @Environment(\.managedObjectContext) private var context

    @ObservedObject private var statusViewModel: PlanetStatusViewModel = PlanetStatusViewModel.shared

    var body: some View {
        VStack {
            List {
                Section(header:
                HStack {
                    Text("Smart Feeds")
                    Spacer()
                }) {
                    NavigationLink(destination: PlanetArticleListView(planetID: nil, articles: articles, type: .today)
                    .environmentObject(planetStore)
                    .environment(\.managedObjectContext, context)
                    .frame(minWidth: 200)
                    .toolbar {
                        ToolbarItemGroup {
                            Spacer()
                        }
                    }, tag: SmartFeedType.today, selection: $planetStore.selectedSmartFeedType) {
                        SmartFeedView(feedType: .today)
                    }

                    NavigationLink(destination: PlanetArticleListView(planetID: nil, articles: articles, type: .unread)
                    .environmentObject(planetStore)
                    .environment(\.managedObjectContext, context)
                    .frame(minWidth: 200)
                    .toolbar {
                        ToolbarItemGroup {
                            Spacer()
                        }
                    }, tag: SmartFeedType.unread, selection: $planetStore.selectedSmartFeedType) {
                        SmartFeedView(feedType: .unread)
                    }

                    NavigationLink(destination: PlanetArticleListView(planetID: nil, articles: articles, type: .starred)
                    .environmentObject(planetStore)
                    .environment(\.managedObjectContext, context)
                    .frame(minWidth: 200)
                    .toolbar {
                        ToolbarItemGroup {
                            Spacer()
                        }
                    }, tag: SmartFeedType.starred, selection: $planetStore.selectedSmartFeedType) {
                        SmartFeedView(feedType: .starred)
                    }
                }
                Section(header:
                HStack {
                    Text("My Planets")
                    Spacer()
                }) {
                    ForEach(planets.filter { p in
                        p.keyName != nil && p.keyID != nil
                    }, id: \.id) { planet in
                        NavigationLink(
                                destination: PlanetArticleListView(planetID: planet.id!, articles: articles)
                                .environmentObject(planetStore)
                                .environment(\.managedObjectContext, context)
                                .frame(minWidth: 200)
                                .toolbar {
                                    ToolbarItemGroup {
                                        Spacer()
                                        PlanetSidebarToolbarButtonView()
                                        .environmentObject(planetStore)
                                        .environment(\.managedObjectContext, context)
                                    }
                                },
                                tag: planet,
                                selection: $planetStore.currentPlanet
                        ) {
                            VStack {
                                HStack(spacing: 4) {
                                    PlanetAvatarView(planet: planet, size: CGSize(width: 24, height: 24))
                                    Text(planet.name ?? "")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    Spacer()
                                    PlanetSidebarLoadingIndicatorView()
                                    .environmentObject(planetStore)
                                            .opacity(planet.isPublishing ? 1.0 : 0.0)
                                }
                            }
                        }
                        .contextMenu(menuItems: {
                            VStack {
                                Button {
                                    if let planet = planetStore.currentPlanet, planet.isMyPlanet() {
                                        PlanetWriterManager.shared.launchWriter(forPlanet: planet)
                                    }
                                } label: {
                                    Text("New Article")
                                }

                                if !planet.isPublishing {
                                    Button {
                                        Task.init {
                                            await PlanetManager.shared.publish(planet)
                                        }
                                    } label: {
                                        Text("Publish Planet")
                                    }
                                } else {
                                    Button {
                                    } label: {
                                        Text("Publishing...")
                                    }
                                    .disabled(true)
                                }

                                Button {
                                    copyPlanetIPNSAction(planet: planet)
                                } label: {
                                    Text("Copy IPNS")
                                }

                                Divider()

                                Button {
                                    Task.init {
                                        if let keyName = planet.keyName, keyName != "" {
                                            await PlanetManager.shared.deleteKey(withName: keyName)
                                        }
                                        await PlanetDataController.shared.remove(planet)
                                        PlanetDataController.shared.save()
                                    }
                                } label: {
                                    Text("Delete Planet")
                                }

                                Divider()

                                Button {
                                    Task.init {
                                        await PlanetDataController.shared.fixPlanet(planet)
                                    }
                                } label: {
                                    Text("Fix Planet")
                                }
                            }
                        })
                    }
                }

                Section(header:
                HStack {
                    Text("Following Planets")
                    Spacer()
                }
                ) {
                    ForEach(planets.filter { p in
                        p.keyName == nil && p.keyID == nil
                    }, id: \.id) { planet in
                        NavigationLink(destination: PlanetArticleListView(planetID: planet.id!, articles: articles)
                        .environmentObject(planetStore)
                        .environment(\.managedObjectContext, context)
                        .frame(minWidth: 200)
                        .toolbar {
                            ToolbarItemGroup {
                                Spacer()
                                PlanetSidebarToolbarButtonView()
                                .environmentObject(planetStore)
                                .environment(\.managedObjectContext, context)
                            }
                        }, tag: planet, selection: $planetStore.currentPlanet) {
                            VStack {
                                HStack(spacing: 4) {
                                    if planet.name == nil || planet.name == "" {
                                        Text(planet.isUpdating ? "Waiting for planet..." : "Unknown Planet")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    } else {
                                        PlanetAvatarView(planet: planet, size: CGSize(width: 24, height: 24))
                                        Text(planet.name ?? "")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    }
                                    Spacer()
                                    if planet.isUpdating {
                                        PlanetSidebarLoadingIndicatorView()
                                        .environmentObject(planetStore)
                                    }
                                }
                                .badge(PlanetDataController.shared.getArticleStatus(byPlanetID: planet.id!).unread)
                            }
                        }
                        .contextMenu(menuItems: {
                            VStack {
                                if !planet.isUpdating {
                                    Button {
                                        Task.init {
                                            try await PlanetManager.shared.update(planet)
                                        }
                                    } label: {
                                        Text("Check for update")
                                    }
                                } else {
                                    Button {
                                    } label: {
                                        Text("Updating...")
                                    }
                                    .disabled(true)
                                }

                                if articles.count > 0 {
                                    Button {
                                        let _ = articles.map { article in
                                            article.isRead = true
                                        }
                                        PlanetDataController.shared.save()
                                    } label: {
                                        Text("Mark All as Read")
                                    }
                                }

                                Button {
                                    copyPlanetIPNSAction(planet: planet)
                                } label: {
                                    Text("Copy IPNS")
                                }

                                Divider()

                                Button {
                                    unfollowPlanetAction(planet: planet)
                                } label: {
                                    Text("Unfollow")
                                }
                            }
                        })
                    }
                }
            }
            .listStyle(.sidebar)

            HStack(spacing: 6) {
                Circle()
                .frame(width: 11, height: 11, alignment: .center)
                .foregroundColor((statusViewModel.daemonIsOnline && statusViewModel.peersCount > 0) ? Color.green : Color.red)
                Text(statusViewModel.peersCount == 0 ? "Offline" : "Online (\(statusViewModel.peersCount))")
                .font(.body)

                Spacer()

                Menu {
                    Button(action: {
                        planetStore.isCreatingPlanet = true
                    }) {
                        Label("Create Planet", systemImage: "plus")
                    }
                    .disabled(planetStore.isCreatingPlanet)

                    Divider()

                    Button(action: {
                        planetStore.isFollowingPlanet = true
                    }) {
                        Label("Follow Planet", systemImage: "plus")
                    }
                } label: {
                    Image(systemName: "plus.app")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24, alignment: .center)
                }
                .padding(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 0))
                .frame(width: 24, height: 24, alignment: .center)
                .menuStyle(BorderlessButtonMenuStyle())
                .menuIndicator(.hidden)
            }
            .onTapGesture {
                guard !statusViewModel.daemonIsOnline else {
                    return
                }
                PlanetManager.shared.relaunchDaemon()
            }
            .frame(height: 44)
            .padding(.leading, 16)
            .padding(.trailing, 10)
            .background(Color.secondary.opacity(0.05))
        }
        .padding(.bottom, 0)
        .sheet(isPresented: $planetStore.isFollowingPlanet) {
        } content: {
            FollowPlanetView()
            .environmentObject(planetStore)
        }
        .sheet(isPresented: $planetStore.isCreatingPlanet) {
        } content: {
            CreatePlanetView()
            .environmentObject(planetStore)
        }
    }

    private func unfollowPlanetAction(planet: Planet) {
        Task.init {
            await PlanetDataController.shared.remove(planet)
            PlanetDataController.shared.save()
        }
    }

    private func copyPlanetIPNSAction(planet: Planet) {
        guard let ipns = planet.ipns else {
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(ipns, forType: .string)
    }
}


struct PlanetSidebarView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetSidebarView()
    }
}
