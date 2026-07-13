//
//  VideoModel.swift
//  Plugin
//
//  Created by  Quéau Jean Pierre on 13/01/2020.
//  Copyright © 2021 Max Lynch. All rights reserved.
//

import UIKit
import os

class VideoModel: NSObject {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "org.dwbn.awareness",
        category: String(describing: VideoModel.self)
    )
    var videos: [Video] = []

    func addVideo(video: Video) {
        videos.append(video)
    }

    func getVideos() -> [Video] {
        return videos
    }

    func printVideos() {
        for video in self.videos {
            guard let urlPath: String = video.urlPath else {
                continue
            }
            guard let title: String = video.title else {
                continue
            }
            guard let content: String = video.content else {
                continue
            }
            guard let width: Int = video.width else {
                continue
            }
            guard let height: Int = video.height else {
                continue
            }
            Self.logger.debug("Video \(urlPath, privacy: .public) \n \(title, privacy: .public) \n \(content, privacy: .public) \n \(width, privacy: .public) \(height, privacy: .public)")
        }
    }
}
