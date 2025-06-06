//
//  PlaylistManager.swift
//  watch
//
//  Created by Konstantin Späth on 13.07.24.
//

import Foundation
import AVFoundation
import SwiftAudioEx

class PlaylistManager {

  private var playlist: Playlist?
  var videos: [Video]?
  private var playlistItems: [AudioItem?] = []

  init() {

  }

  func setPlaylist(_ playlist: Playlist?, videos: [Video]? = nil, shuffle: Bool = false) {
    if let p = playlist {
      self.playlist = p
      self.videos = p.videos
      self.playlistItems = Array(repeating: nil, count: p.videos.count)
    } else if let v = videos {
      self.playlist = nil
      self.videos = v
      self.playlistItems = Array(repeating: nil, count: v.count)
    } else {
      print("Setting playlist invalid")
    }
    
    if shuffle {
      self.videos?.shuffle()
    }
  }

  func getAll() -> [(Video, AudioItem)] {
    if let videos = videos {
      return getVideos(indexSet: IndexSet(0...videos.count-1)).compactMap { v, a in
        if let audio = a {
          return (v, audio)
        }
        return nil
      }
    }
    return []
  }

  func getFirstBatchOfAvailable() -> [(Video, AudioItem)] {
    if let videos = videos {
      var arr = Array<(Video, AudioItem)>()
      let videos = getVideos(indexSet: IndexSet(0...videos.count-1))

      for v in videos {
        if let audio = v.1 {
          arr.append((v.0, audio))
        } else {
          // TODO: Send request for missing video Streaming Data
          videos.forEach { video, audio in
            if audio == nil {
              requestVideo(id: video.id)
            }
          }
          break;
        }
      }
      return arr
    }
    return []
  }

  func getVideos(indexSet: IndexSet) -> [(Video, AudioItem?)] {
    let items : [(Int, AudioItem?)] = indexSet.map { index in
      let playerItem = playlistItems[index]
      if let pItem = playerItem {
        return (index, pItem)
      } else {
        if let videos = videos {
          let pItem = getPlayerItem(videos[index])
          self.playlistItems[index] = pItem
          return (index, pItem)
        }
      }
      return (index, nil)
    }

    return items.compactMap { index, playerItem in
      if let video = videos?[index] {
        return (video, playerItem)
      }
      return nil
    }

  }

  func checkForNewVideos() {
    // TODO: Check if playlist contains new videos
  }

  private func getPlayerItem(_ video: Video) -> AudioItem? {
    if let localFile = video.fileURL {
      let uri = getDownloadDirectory().appending(path: localFile).absoluteString
      print("Local uri: \(uri)")
      
      // Map to downloaded image if available
      var coverURL: String? = nil
      if let url = video.coverURL {
        if url.hasPrefix("/") {
          coverURL = getDownloadDirectory().appending(path: url).absoluteString
        } else {
          coverURL = url
        }
      }
      print("Coverurl: \(coverURL ?? "none")")
      
      if let item = TrackEndtime(url: uri, artworkUrl: coverURL, endTiming: CMTime(value: Int64(video.durationMillis/1000), timescale: 1)) {
        item.title = video.title
        item.artist = video.artist

        return item
      }

      // TODO: Outsource to skip duplicate code
      
    } else if let sURL = video.streamURL, let validUntil = video.validUntil, validUntil > Date(), let item = Track(url: sURL, artworkUrl: video.coverURL) {
      print("Remote uri: \(sURL)")

      // TODO: Outsource to skip duplicate code
      item.title = video.title
      item.artist = video.artist
      // TODO: strip player item to the video duration

      return item
    }
    print("Skipping video: \(video.title ?? video.id) as no type matched")
    return nil
  }

}

protocol PlaylistManagerDelegate {
  func fetchedNewVideos(playlistItems: [AVPlayerItem])
}
