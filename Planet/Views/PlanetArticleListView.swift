//
//  PlanetArticleListView.swift
//  Planet
//
//  Created by Kai on 2/20/22.
//

import SwiftUI


struct PlanetArticleListView: View {
    @EnvironmentObject private var planetStore: PlanetStore
    @Environment(\.managedObjectContext) private var context
    
    var planetID: UUID?
    var articles: FetchedResults<PlanetArticle>?
    
    var body: some View {
        VStack {
            if let planetID = planetID, let articles = articles, articles.filter({ aa in
                if let id = aa.planetID {
                    return id == planetID
                }
                return false
            }).count > 0 {
                List(articles.filter({ a in
                    if let id = a.planetID {
                        return id == planetID
                    }
                    return false
                })) { article in
                    NavigationLink(destination: PlanetArticleView(article: article).environmentObject(planetStore), tag: article.id!.uuidString, selection: $planetStore.selectedArticle) {
                        VStack {
                            HStack {
                                Text(article.title ?? "")
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            HStack {
                                Text(article.created?.dateDescription() ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                    .contextMenu {
                        VStack {
                            if let planet = PlanetDataController.shared.getPlanet(id: planetID), planet.isMyPlanet() {
                                Button {
                                    launchWriter(forArticle: article)
                                } label: {
                                    Text("Update Article: \(article.title ?? "")")
                                }
                                Button {
                                    PlanetDataController.shared.removeArticle(article: article)
                                } label: {
                                    Text("Delete Article: \(article.title ?? "")")
                                }
                                Button {
                                    PlanetDataController.shared.refreshArticle(article)
                                } label: {
                                    Text("Refresh")
                                }
                            }
                            Button {
                                PlanetDataController.shared.copyPublicLinkOfArticle(article)
                            } label: {
                                Text("Copy Public Link")
                            }
                        }
                    }
                }
            } else {
                Text("No Planet Selected")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(
            planetStore.currentPlanet == nil ? "Planet" : planetStore.currentPlanet.name ?? "Planet"
        )
    }
    
    private func launchWriter(forArticle article: PlanetArticle) {
        let articleID = article.id!
        
        if planetStore.writerIDs.contains(articleID) {
            DispatchQueue.main.async {
                self.planetStore.activeWriterID = articleID
            }
            return
        }
        
        let writerView = PlanetWriterView(articleID: articleID, isEditing: true, title: article.title ?? "", content: article.content ?? "")
        let writerWindow = PlanetWriterWindow(rect: NSMakeRect(0, 0, 480, 320), maskStyle: [.closable, .miniaturizable, .resizable, .titled, .fullSizeContentView], backingType: .buffered, deferMode: false, articleID: articleID)
        writerWindow.center()
        writerWindow.contentView = NSHostingView(rootView: writerView)
        writerWindow.makeKeyAndOrderFront(nil)
    }
}

struct PlanetArticleListView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetArticleListView()
    }
}
