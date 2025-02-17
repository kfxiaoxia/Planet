//
//  PlanetWriterUploadImageThumbnailView.swift
//  Planet
//
//  Created by Kai on 3/30/22.
//

import SwiftUI


struct PlanetWriterUploadImageThumbnailView: View {
    @EnvironmentObject private var viewModel: PlanetWriterViewModel

    var articleID: UUID
    var fileURL: URL

    let thumbnailSize: CGFloat = 60

    @State private var isShowingPlusIcon: Bool = false

    var body: some View {
        ZStack {
            if let imageView = thumbnailFromFile(forTargetHeight: thumbnailSize) {
                imageView
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.vertical, 4)
                    .frame(width: thumbnailSize, height: thumbnailSize, alignment: .center)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18, alignment: .center)
                        .opacity(isShowingPlusIcon ? 1.0 : 0.0)
                    Spacer()
                }
                Spacer()
            }
            .padding(4)
            .onTapGesture {
                insertFile()
            }

            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 12, height: 12, alignment: .center)
                        .opacity(isShowingPlusIcon ? 1.0 : 0.0)
                        .onTapGesture {
                            deleteFile()
                        }
                }
                Spacer()
            }
            .padding(.leading, 0)
            .padding(.top, 2)
            .padding(.trailing, -8)
        }
        .frame(width: thumbnailSize, height: thumbnailSize, alignment: .center)
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .onHover { isHovering in
            withAnimation {
                isShowingPlusIcon = isHovering
            }
        }
    }

    private func getUploadedFile() -> (isImage: Bool, uploadURL: URL?) {
        let filename = fileURL.lastPathComponent
        let isImage = PlanetWriterManager.shared.uploadingIsImageFile(fileURL: fileURL)
        var filePath: URL?
        if let planetID = PlanetDataController.shared.getArticle(id: articleID)?.planetID,
           let planet = PlanetDataController.shared.getPlanet(id: planetID), planet.isMyPlanet(),
           let planetArticlePath = PlanetWriterManager.shared.articlePath(articleID: articleID, planetID: planetID),
           FileManager.default.fileExists(atPath: planetArticlePath.appendingPathComponent(filename).path) {
            filePath = planetArticlePath.appendingPathComponent(filename)
        }

        // if not exists, find in draft directory:
        let draftPath = PlanetWriterManager.shared.articleDraftPath(articleID: articleID)
        let draftFilePath = draftPath.appendingPathComponent(filename)
        if filePath == nil, FileManager.default.fileExists(atPath: draftFilePath.path) {
            filePath = draftFilePath
        }

        return (isImage, filePath)
    }

    private func deleteFile() {
        // if in edit mode, backup a copy in draft/[article_uuid] for recovery
        let uploaded = getUploadedFile()
        guard let filePath = uploaded.uploadURL else { return }
        let draftPath = PlanetWriterManager.shared.articleDraftPath(articleID: articleID)
        if draftPath.path != filePath.deletingLastPathComponent().path {
            PlanetWriterManager.shared.backupFileQueue.async {
                do {
                    try PlanetWriterManager.shared.backupUploading(articleID: articleID, fileURL: filePath)
                } catch {
                    debugPrint("failed to backup uploading: \(filePath), article: \(articleID), error: \(error)")
                }
            }
        }
        PlanetWriterManager.shared.backupFileQueue.async {
            do {
                try FileManager.default.removeItem(at: filePath)
                Task { @MainActor in
                    viewModel.removeUploadings(articleID: articleID, url: fileURL)
                }
                let filename = filePath.lastPathComponent
                let c: String = (uploaded.isImage ? "!" : "") + "[\(filename)]" + "(" + filename + ")"
                let removeNotification: Notification.Name = Notification.Name.notification(notification: .removeText, forID: articleID)
                let rerenderNotification = Notification.Name.notification(notification: .rerenderPage, forID: articleID)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: removeNotification, object: c)
                    NotificationCenter.default.post(name: rerenderNotification, object: c)
                }
            } catch {
                debugPrint("failed to delete uploaded file: \(fileURL), error: \(error)")
            }
        }
    }

    private func insertFile() {
        let uploaded = getUploadedFile()
        guard let filePath = uploaded.uploadURL else { return }
        let filename = filePath.lastPathComponent
        let c: String = (uploaded.isImage ? "\n" : "") + (uploaded.isImage ? "!" : "") + "[\(filename)]" + "(" + filename + ")"
        let n: Notification.Name = Notification.Name.notification(notification: .insertText, forID: articleID)
        NotificationCenter.default.post(name: n, object: c)
    }

    private func thumbnailFromFile(forTargetHeight targetHeight: CGFloat) -> Image? {
        // check file locations
        let filename = fileURL.lastPathComponent
        // find in planet directory:
        if let planetID = PlanetDataController.shared.getArticle(id: articleID)?.planetID,
           let planet = PlanetDataController.shared.getPlanet(id: planetID), planet.isMyPlanet(),
           let planetArticlePath = PlanetWriterManager.shared.articlePath(articleID: articleID, planetID: planetID),
           FileManager.default.fileExists(atPath: planetArticlePath.appendingPathComponent(filename).path),
           let img = NSImage(contentsOf: planetArticlePath.appendingPathComponent(filename)) {
            let size = scaledThumbnailSize(size: img.size, forHeight: targetHeight*2)
            if let resizedImg = img.resize(size) {
                return Image(nsImage: resizedImg)
            }
        }

        // if not exists, find in draft directory:
        let draftPath = PlanetWriterManager.shared.articleDraftPath(articleID: articleID)
        let imagePath = draftPath.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: imagePath.path),
           let img = NSImage(contentsOf: imagePath) {
            let size = scaledThumbnailSize(size: img.size, forHeight: targetHeight*2)
            if let resizedImg = img.resize(size) {
                return Image(nsImage: resizedImg)
            }
        }

        return nil
    }

    private func scaledThumbnailSize(size: NSSize, forHeight height: CGFloat) -> NSSize {
        let ratio = height / size.height
        let newWidth = size.width * ratio
        return NSSize(width: newWidth, height: height)
    }
}
