//
//  VideoTrimmer.swift
//  Split
//
//  Created by Alfred Woo on 2019/10/11.
//  Copyright © 2019 Alfred Woo. All rights reserved.
//

import UIKit
import AVKit
import Photos

class VideoTrimmer {
    
    static let shared = VideoTrimmer()
    
    func verifyPresetForAsset(preset: String, asset: AVAsset) -> Bool {
        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: asset)
        let filteredPresets = compatiblePresets.filter { $0 == preset }
        return filteredPresets.count > 0 || preset == AVAssetExportPresetPassthrough
    }
    
    func trimVideo(sourceURL: URL, start: Int64, duration: Int64, completion: @escaping (Bool, Error?) -> Void) {
        
        let options = [
            AVURLAssetPreferPreciseDurationAndTimingKey: true
        ]
        
        let asset = AVURLAsset(url: sourceURL, options: options)
        let preferredPreset = AVAssetExportPresetPassthrough
        
        if CMTimeGetSeconds(asset.duration) <= Float64(start) {
            completion(false, nil)
            return
        }
        
        if verifyPresetForAsset(preset: preferredPreset, asset: asset) {
            
            print(">>> will trim from \(start) for \(duration) seconds")
            
            let composition = AVMutableComposition()
            let videoCompTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: CMPersistentTrackID())
            let audioCompTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: CMPersistentTrackID())
            
            guard let assetVideoTrack: AVAssetTrack = asset.tracks(withMediaType: .video).first else { return }
            guard let assetAudioTrack: AVAssetTrack = asset.tracks(withMediaType: .audio).first else { return }

            videoCompTrack!.preferredTransform = assetVideoTrack.preferredTransform
            
            let startTime = CMTimeMake(value: start, timescale: 1)
            let durationTime = CMTimeMake(value: duration, timescale: 1)
            
            let timeRangeForCurrentSlice = CMTimeRangeMake(start: startTime, duration: durationTime)
            
            do {
                try videoCompTrack!.insertTimeRange(timeRangeForCurrentSlice, of: assetVideoTrack, at: .zero)
                try audioCompTrack!.insertTimeRange(timeRangeForCurrentSlice, of: assetAudioTrack, at: .zero)
            } catch let error {
                completion(false, error)
                return
            }

            
            
            guard let exportSession = AVAssetExportSession(asset: composition, presetName: preferredPreset) else { return }
            
            guard let home = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else { return }
            
            let filename = UUID().uuidString
            
            let destination = "\(home)/\(filename).mov"
            let destinationURL = URL(fileURLWithPath: destination)
            print("destination: \(destination)")
            
            exportSession.outputURL = destinationURL
            exportSession.outputFileType = AVFileType.mov
            exportSession.shouldOptimizeForNetworkUse = true
            
            exportSession.exportAsynchronously {
                if let error = exportSession.error {
                    print("trim finished with error: \(error)")
                    completion(false, error)
                    return
                }
                
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: destinationURL)
                }) { (saved, error) in
                    if let error = error {
                        print("saved: \(saved), error: \(error)")
                        completion(false, error)
                        return
                    }
                }
                
                completion(true, nil)
            }
        } else {
            let error = NSError(domain: "VideoTrimmerError", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Unsupported video format.".localized()
            ])
            completion(false, error)
        }
    }
}
