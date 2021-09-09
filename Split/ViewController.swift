//
//  ViewController.swift
//  Split
//
//  Created by Alfred Woo on 2019/10/11.
//  Copyright © 2019 Alfred Woo. All rights reserved.
//

import UIKit
import AVKit
import StoreKit
import Photos
import MobileCoreServices

class ViewController: UIViewController {
    
    private var url: URL?
    
    private var maxLength: Int = 60
    private var videoLength: Double = 0
    private var estimatedCount: Int = 0
    
    private var currentSplitting = 1
    private var alert: UIAlertController?
    
    @IBOutlet weak private var videoThumbnailView: UIImageView!
    @IBOutlet weak private var playButtonView: UIImageView!
    
    @IBOutlet weak private var secondsSlider: UISlider!
    @IBOutlet weak private var secondsTextField: UITextField!
    @IBOutlet weak private var splitButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let gr = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        self.view.addGestureRecognizer(gr)
        
        self.sliderValueChanged(self.secondsSlider)
        
        self.secondsTextField.delegate = self
    }
    
    @objc func dismissKeyboard() {
        self.secondsTextField.resignFirstResponder()
    }

    @IBAction func sliderValueChanged(_ sender: UISlider) {
        self.secondsTextField.text = String(Int(sender.value))
    }
    
    @IBAction func playButtonTapped() {
        guard let url = self.url else { return }
        
        let player = AVPlayer(url: url)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        self.present(playerViewController, animated: true) {
            playerViewController.player!.play()
        }
    }

    @IBAction func selectButtonTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "Select Video".localized(), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Photo Library".localized(), style: .default, handler: { _ in
            let imagePicker = UIImagePickerController()
            imagePicker.sourceType = .photoLibrary
            imagePicker.delegate = self
            imagePicker.mediaTypes = ["public.movie"]
            imagePicker.videoExportPreset = AVAssetExportPresetPassthrough
            self.present(imagePicker, animated: true, completion: nil)
        }))
        alert.addAction(UIAlertAction(title: "Files".localized(), style: .default, handler: { _ in
            let documentPicker = UIDocumentPickerViewController(documentTypes: [kUTTypeMovie, kUTTypeMPEG4, kUTTypeVideo].map { $0 as String}, in: .open)
            documentPicker.delegate = self
            documentPicker.allowsMultipleSelection = false
            self.present(documentPicker, animated: true, completion: nil)
        }))
        alert.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        
        if let popoverPresentationController = alert.popoverPresentationController {
            popoverPresentationController.sourceView = self.view
            popoverPresentationController.sourceRect = sender.convert(sender.bounds, to: self.view)
        }
        
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func splitButtonTapped() {
        if self.url == nil { return }
        
        if Int(self.secondsSlider.value) == 0 {
            self.showAlertController(message: "Invalid second!")
            return
        }
        
        if Int(ceil(self.secondsSlider.value)) == Int(ceil(self.videoLength)) {
            self.showAlertController(message: "Unnecessary split!")
            return
        }
        
        self.permissionCheck(completion: {
            self.estimatedCount = Int(ceil(self.videoLength / Double(Int64(self.secondsSlider.value)))) + 1
            
            if self.estimatedCount > 10 {
                self.showAlertController(message: String(format: "%d videos are estimated to be created.\nAre you sure you want to continue?".localized(), self.estimatedCount), actions: [
                    UIAlertAction(title: "Continue".localized(), style: .default, handler: { _ in
                        self.startTrim()
                    }),
                    UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil)
                ])
            } else {
                self.startTrim()
            }
        })
        
    }
    
    private func permissionCheck(completion: @escaping () -> Void) {
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized:
            // continue
            completion()
            break
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    if status == .authorized {
                        // continue
                        completion()
                    } else {
                        self.showAlertController(message: "You need to allow Split to access your photo library to split videos.".localized(), actions: [
                            UIAlertAction(title: "Later".localized(), style: .cancel, handler: nil),
                            UIAlertAction(title: "Go to Settings".localized(), style: .default, handler: { action in
                                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
                            })
                        ])
                    }
                }
            }
            break
        default:
            // can't
            self.showAlertController(message: "You need to allow Split to access your photo library to split videos.".localized(), actions: [
                UIAlertAction(title: "Later".localized(), style: .cancel, handler: nil),
                UIAlertAction(title: "Go to Settings".localized(), style: .default, handler: { action in
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
                })
            ])
            break
        }
    }
    
    private func startTrim() {
        self.trim(start: 0, duration: Int64(self.secondsSlider.value))
        
        self.currentSplitting = 1
        self.alert = UIAlertController(title: "Split", message: self.getProcessingString(), preferredStyle: .alert)
        self.present(alert!, animated: true, completion: nil)
    }
    
    private func trim(start: Int64, duration: Int64) {
        VideoTrimmer.shared.trimVideo(sourceURL: self.url!, start: start, duration: duration) { hasMore, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.alert?.dismiss(animated: true, completion: {
                        self.showAlertController(message: error.localizedDescription)
                    })
                } else {
                    if hasMore {
                        self.currentSplitting += 1
                        self.alert?.message = self.getProcessingString()
                        self.trim(start: (start + duration), duration: duration)
                    } else {
                        self.alert?.dismiss(animated: true, completion: {
                            self.showAlertController(message: "Split finished!", actions: [
                                UIAlertAction(title: "OK".localized(), style: .default, handler: { action in
                                    SKStoreReviewController.requestReview()
                                })
                            ])
                        })
                    }
                }
            }
        }
    }
    
    func getProcessingString() -> String {
        return String(format: "Processing %d of %d".localized(), self.currentSplitting, self.estimatedCount)
    }
    
    func showAlertController(message: String, actions: [UIAlertAction]? = nil) {
        let alert = UIAlertController(title: "Split", message: message.localized(), preferredStyle: .alert)
        if let actions = actions {
            for action in actions {
                alert.addAction(action)
            }
        } else {
            alert.addAction(UIAlertAction(title: "OK".localized(), style: .default, handler: nil))
        }
        self.present(alert, animated: true, completion: nil)
    }
    
    private func loadVideo(at url: URL) {
        self.url = url
        self.splitButton.isEnabled = true
        self.playButtonView.isHidden = false
        
        // 썸네일 로드
        let asset = AVAsset(url: url)
        let assetImageGenerator = AVAssetImageGenerator(asset: asset)
        assetImageGenerator.appliesPreferredTrackTransform = true
        assetImageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: CMTimeMakeWithSeconds(138, preferredTimescale: 1))]) { (_, image, _, result, _) in
            if result == .succeeded {
                if let image = image {
                    DispatchQueue.main.async {
                        self.videoThumbnailView.image = UIImage(cgImage: image)
                    }
                }
            }
        }
        
        self.videoLength = CMTimeGetSeconds(asset.duration)
        self.maxLength = Int(ceil(self.videoLength))
        if self.maxLength > 60 {
            self.maxLength = 60
        }
        self.secondsSlider.maximumValue = Float(self.maxLength)
        self.sliderValueChanged(self.secondsSlider)
    }
    
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let url = info[.mediaURL] as? URL {
            self.loadVideo(at: url)
            picker.dismiss(animated: true, completion: nil)
        }
    }
    
}

extension ViewController: UIDocumentPickerDelegate {
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let url = urls.first {
            self.loadVideo(at: url)
            controller.dismiss(animated: true, completion: nil)
        }
    }
    
}

extension ViewController: UITextFieldDelegate {
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if let val = Int(textField.text ?? "") {
            if val > self.maxLength {
                self.secondsSlider.value = Float(self.maxLength)
                self.secondsTextField.text = String(self.maxLength)
            } else {
                self.secondsSlider.value = Float(val)
            }
        }
    }
    
}
