//
//  ViewController.swift
//  Digital Signage
//
//  Created by Micah Bucy on 12/17/15.
//  Copyright © 2015 Micah Bucy. All rights reserved.
//
//  The MIT License (MIT)
//  This file is subject to the terms and conditions defined in LICENSE.md

import Cocoa
import FileKit
import AVKit
import AVFoundation
import SwiftyJSON
import CoreGraphics

class ViewController: NSViewController {
    private var url = NSURL(fileURLWithPath: "")
    private var slideshow : [SlideshowItem] = []
    private var slideshowLoader : [SlideshowItem] = []
    private var countdowns : [Countdown] = []
    private var slideshowLength = 0
    private var currentSlideIndex = -1
    private var timer = Timer()
    private var updateTimer = Timer()
    private var countdownTimer = Timer()
    private var updateReady = false
    private var initializing = true
    private var animating = false
    private var applicationSupport = Path.userApplicationSupport + "/theeternalsw0rd/Digital Signage"
    private let appDelegate = NSApplication.shared.delegate as! AppDelegate
    private let downloadQueue = OperationQueue()
    private static var playerItemContext = 0
    
    @IBOutlet weak var countdown: NSTextField!
    @IBOutlet weak var goButton: NSButton!
    @IBOutlet weak var addressBox: NSTextField!
    @IBOutlet weak var label: NSTextField!
    @IBAction func goButtonAction(_ sender: AnyObject) {
        let urlString = self.addressBox.stringValue
        UserDefaults.standard.set(urlString, forKey: "url")
        self.loadSignage(urlString: urlString)
    }
    
    @IBAction func addressBoxAction(_ sender: AnyObject) {
        let urlString = self.addressBox.stringValue
        UserDefaults.standard.set(urlString, forKey: "url")
        self.loadSignage(urlString: urlString)
    }
    
    func resetView() {
        self.appDelegate.backgroundThread(background: {
            while(self.animating) {
                usleep(10000)
            }
        }, completion: {
            self.stopSlideshow()
            self.stopUpdater()
            self.stopCountdowns()
            self.countdown.isHidden = true
            let urlString = UserDefaults.standard.string(forKey: "url")
            self.initializing = true
            self.releaseOtherViews(imageView: nil)
            self.label.isHidden = false
            self.addressBox.isHidden = false
            if(urlString != nil) {
                self.addressBox.stringValue = urlString!
            }
            self.addressBox.becomeFirstResponder()
            self.goButton.isHidden = false
            self.view.needsLayout = true
        })
    }
    
    private func loadSignage(urlString: String) {
        if(!Path(stringInterpolation: self.applicationSupport).exists) {
            do {
                try Path(stringInterpolation: self.applicationSupport).createDirectory()
            }
            catch {
                let alert = NSAlert()
                alert.messageText = "Could not create caching directory."
                alert.addButton(withTitle: "OK")
                let _ = alert.runModal()
                return
            }
        }
        if let _url = URLComponents(string: urlString) {
            var url = _url
            url.scheme = "https"
            if let urlString = url.url?.absoluteString {
                if let _surl = NSURL(string: urlString) {
                    self.url = _surl
                    self.getJSON()
                    self.setCountdowns()
                    self.setUpdateTimer()
                }
                else {
                    let alert = NSAlert()
                    alert.messageText = "URL appears to be malformed."
                    alert.addButton(withTitle: "OK")
                    let _ = alert.runModal()
                }
            }
            else {
                let alert = NSAlert()
                alert.messageText = "URL appears to be malformed."
                alert.addButton(withTitle: "OK")
                let _ = alert.runModal()
            }
        }
        else {
            let alert = NSAlert()
            alert.messageText = "URL appears to be malformed."
            alert.addButton(withTitle: "OK")
            let _ = alert.runModal()
        }
    }
    
    @objc func backgroundUpdate(timer:Timer) {
        self.showNextSlide()
    }
    
    private func releaseOtherViews(imageView: NSView?) {
        for view in self.view.subviews {
            // hide views that need to retain properties
            if(view != imageView && view != self.countdown && !(view.isHidden)) {
                view.removeFromSuperview()
            }
        }
    }
    
    private func playVideo(frameSize: NSSize, boundsSize: NSSize, uri: NSURL) {
        DispatchQueue.main.async(execute: { () -> Void in
            let videoView = NSView()
            videoView.frame.size = frameSize
            videoView.bounds.size = boundsSize
            videoView.wantsLayer = true
            videoView.layerContentsRedrawPolicy = NSView.LayerContentsRedrawPolicy.onSetNeedsDisplay
            let player = AVPlayer(url: uri as URL)
            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.videoGravity = AVLayerVideoGravity.resize
            videoView.layer = playerLayer
            videoView.layer?.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0)
            self.view.addSubview(videoView, positioned: NSWindow.OrderingMode.below, relativeTo: self.countdown)
            NotificationCenter.default.addObserver(self, selector: #selector(self.playerDidFinishPlaying), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player.currentItem)
            NotificationCenter.default.addObserver(self, selector: #selector(self.playerDidFinishPlaying), name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: player.currentItem)
            player.currentItem?.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.old, .new], context: &ViewController.playerItemContext)
            player.play()
        })
    }
    
    private func createImageView(image: NSImage, thumbnail: Bool, frameSize: NSSize, boundsSize: NSSize) {
        DispatchQueue.main.async(execute: { () -> Void in
            let imageView = MyImageView()
            imageView.removeConstraints(imageView.constraints)
            imageView.translatesAutoresizingMaskIntoConstraints = true
            imageView.alphaValue = 0
            if(thumbnail) {
                imageView.image = image
            }
            else {
                imageView.imageWithSize(image: image, w: frameSize.width, h: frameSize.height)
            }
            imageView.frame.size = frameSize
            imageView.bounds.size = boundsSize
            imageView.wantsLayer = true
            imageView.layerContentsRedrawPolicy = NSView.LayerContentsRedrawPolicy.onSetNeedsDisplay
            self.view.addSubview(imageView, positioned: NSWindow.OrderingMode.below, relativeTo: self.countdown)
            self.animating = true
            NSAnimationContext.runAnimationGroup(
                { (context) -> Void in
                    context.duration = 1.0
                    imageView.animator().alphaValue = 1.0
                    
                }, completionHandler: { () -> Void in
                    self.releaseOtherViews(imageView: imageView)
                    if(thumbnail) {
                        let item = self.slideshow[self.currentSlideIndex]
                        let path = item.path.rawValue
                        let uri = NSURL(fileURLWithPath: path)
                        self.playVideo(frameSize: frameSize, boundsSize: boundsSize, uri: uri)
                    }
                    else {
                        self.setTimer()
                    }
                    self.animating = false
                }
            )
        })
    }
    
    private func showNextSlide() {
        DispatchQueue.main.async(execute: { () -> Void in
            self.currentSlideIndex += 1
            if(self.currentSlideIndex == self.slideshowLength) {
                if(self.updateReady) {
                    self.updateSlideshow()
                    self.updateReady = false
                    return
                }
                self.currentSlideIndex = 0
            }
            if(self.slideshow.count == 0) {
                if(self.updateReady) {
                    self.updateSlideshow()
                    self.updateReady = false
                    return
                }
                NSLog("Slideshow is empty at a point when it shouldn't be. Check server json response for properly configured data.")
                self.setTimer()
                return
            }
            let item = self.slideshow[self.currentSlideIndex]
            let type = item.type
            let path = item.path.rawValue
            let frameSize = self.view.frame.size
            let boundsSize = self.view.bounds.size
            if(type == "image") {
                let image = NSImage(contentsOfFile: path)
                self.createImageView(image: image!, thumbnail: false, frameSize: frameSize, boundsSize: boundsSize)
            }
            else if(type == "video") {
                let uri = NSURL(fileURLWithPath: path)
                let avAsset = AVURLAsset(url: uri as URL)
                let avAssetImageGenerator = AVAssetImageGenerator(asset: avAsset)
                let time = NSValue(time: CMTimeMake(0, 1))
                avAssetImageGenerator.generateCGImagesAsynchronously(forTimes: [time],
                    completionHandler: {(_, image:CGImage?, _, _, error:Error?) in
                        if(error == nil) {
                            self.createImageView(image: NSImage(cgImage: image!, size: frameSize), thumbnail: true, frameSize: frameSize, boundsSize: boundsSize)
                        }
                        else {
                            self.playVideo(frameSize: frameSize, boundsSize: boundsSize, uri: uri)
                        }
                    }
                )
            }
            else {
                self.setTimer()
            }
        })
    }
    
    @objc func playerDidFinishPlaying(note: NSNotification) {
        self.showNextSlide()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func stopSlideshow() {
        DispatchQueue.main.async(execute: {
            self.timer.invalidate()
        })
    }
    
    private func stopUpdater() {
        DispatchQueue.main.async(execute: {
            self.updateTimer.invalidate()
        })
    }
    
    private func stopCountdowns() {
        DispatchQueue.main.async(execute: {
            self.countdownTimer.invalidate()
        })
    }
    
    private func setCountdowns() {
        DispatchQueue.main.async(execute: {
            self.countdownTimer.invalidate()
            self.countdownTimer = Timer(timeInterval: 0.1, target: self, selector: #selector(self.updateCountdowns), userInfo: nil, repeats: true)
            RunLoop.current.add(self.countdownTimer, forMode: RunLoopMode.commonModes)
        })
    }
    
    private func setUpdateTimer() {
        DispatchQueue.main.async(execute: {
            self.updateTimer.invalidate()
            self.updateTimer = Timer(timeInterval: 30, target: self, selector: #selector(self.update), userInfo: nil, repeats: false)
            RunLoop.current.add(self.updateTimer, forMode: RunLoopMode.commonModes)
        })
    }
    
    private func setTimer() {
        DispatchQueue.main.async(execute: {
            var duration: Double = 7.0
            if(self.slideshow.count > 0) {
                let item = self.slideshow[self.currentSlideIndex]
                duration = Double(item.duration)
            }
            self.timer = Timer(timeInterval: duration, target: self, selector: #selector(self.backgroundUpdate), userInfo: nil, repeats: false)
            RunLoop.current.add(self.timer, forMode: RunLoopMode.commonModes)
        })
    }
    
    private func startSlideshow() {
        self.showNextSlide()
    }
    
    private func downloadItems() {
        if(self.downloadQueue.operationCount > 0) {
            return
        }
        self.downloadQueue.isSuspended = true
        for item in self.slideshowLoader {
            if(Path(stringInterpolation: item.path).exists) {
                if(item.status == 1) {
                    continue
                }
                let fileManager = FileManager.default
                do {
                    try fileManager.removeItem(atPath: item.path.rawValue)
                } catch {
                    NSLog("Could not remove existing file: %@", item.path.rawValue)
                    continue
                }
                let operation = Downloader(item: item)
                self.downloadQueue.addOperation(operation)
            }
            else {
                let operation = Downloader(item: item)
                self.downloadQueue.addOperation(operation)
            }
        }
        self.appDelegate.backgroundThread(background: {
            self.downloadQueue.isSuspended = false
            while(self.downloadQueue.operationCount > 0) {
                usleep(100000)
            }
        }, completion: {
            if(self.initializing) {
                self.initializing = false
                self.goButton.isHidden = true
                self.addressBox.resignFirstResponder()
                self.addressBox.isHidden = true
                self.label.isHidden = true
                self.view.becomeFirstResponder()
                // move cursor works around mac mini 10.13 bug
                var cursorPoint = CGPoint(x: 500, y: 500)
                if let screen = NSScreen.main {
                    // work around cursor sometimes getting stuck in visible state
                    cursorPoint = CGPoint(x: screen.frame.width, y: screen.frame.height)
                }
                CGWarpMouseCursorPosition(cursorPoint)
                if(!(self.view.window?.styleMask)!.contains(NSWindow.StyleMask.fullScreen)) {
                    self.view.window?.toggleFullScreen(nil)
                }
                /* should use this but breaks things on mac minis 10.13 and higher
                if(!(self.view.isInFullScreenMode)) {
                    let presOptions: NSApplicationPresentationOptions =
                        [NSApplicationPresentationOptions.hideDock, NSApplicationPresentationOptions.hideMenuBar, NSApplicationPresentationOptions.disableAppleMenu]
                    let optionsDictionary = [NSFullScreenModeApplicationPresentationOptions :
                        presOptions]
                    self.view.enterFullScreenMode(NSScreen.main()!, withOptions:optionsDictionary)
                }
                */
                let view = self.view as! MyView
                view.trackMouse = true
                view.hideCursor()
                view.setTimeout()
                self.updateSlideshow()
            }
            else {
                self.updateReady = true
            }
        })
    }
    
    private func updateSlideshow() {
        self.stopSlideshow()
        self.slideshow = self.slideshowLoader
        self.slideshowLength = self.slideshow.count
        self.currentSlideIndex = -1
        self.slideshowLoader = []
        self.appDelegate.backgroundThread(
            background: {
                let items = self.slideshow
                let files = self.applicationSupport.find(searchDepth: 1) {
                    path in path.rawValue != self.applicationSupport.rawValue + "/json.txt"
                }
                for file in files {
                    var remove = true
                    for item in items {
                        if(item.path.rawValue == file.rawValue) {
                            remove = false
                            break
                        }
                    }
                    if(remove) {
                        let fileManager = FileManager.default
                        do {
                            try fileManager.removeItem(atPath: file.rawValue)
                        } catch {
                            NSLog("Could not remove existing file: %@", file.rawValue)
                            continue
                        }
                    }
                }
            }, completion: {
                self.setUpdateTimer()
            }
        )
        self.startSlideshow()
    }
    
    func getDayOfWeek(date: NSDate)->Int? {
        let myCalendar = NSCalendar(calendarIdentifier: NSCalendar.Identifier.gregorian)
        let myComponents = myCalendar?.components(NSCalendar.Unit.weekday, from: date as Date)
        let weekDay = myComponents?.weekday
        return weekDay
    }
    
    @objc func updateCountdowns() {
        let date = NSDate()
        let currentDay = getDayOfWeek(date: date)
        let calendar = NSCalendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: date as Date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = components.second ?? 0
        let seconds = hour * 3600 + minute * 60 + second
        var hide = true
        for countdown in self.countdowns {
            if(countdown.day != currentDay || countdown.duration > countdown.minute + countdown.hour * 60) {
                continue
            }
            let countdownSeconds = countdown.hour * 3600 + countdown.minute * 60
            let difference = countdownSeconds - seconds
            if(difference > 0 && difference <= countdown.duration * 60) {
                var minuteString = ""
                var secondString = ""
                hide = false
                let minuteDifference = Int(difference / 60)
                let secondDifference = difference % 60
                if(minuteDifference < 10) {
                    minuteString = "0" + String(minuteDifference)
                }
                else {
                    minuteString = String(minuteDifference)
                }
                if(secondDifference < 10) {
                    secondString = "0" + String(secondDifference)
                }
                else {
                    secondString = String(secondDifference)
                }
                self.countdown.stringValue = minuteString + ":" + secondString
                break
            }
        }
        self.countdown.isHidden = hide
    }
    
    @objc func update() {
        self.getJSON()
    }
    
    private func generateCountdowns(countdowns: [JSON]) {
        self.countdowns = []
        for countdown in countdowns {
            let day = countdown["day"].stringValue
            let hour = countdown["hour"].stringValue
            let minute = countdown["minute"].stringValue
            let duration = countdown["duration"].stringValue
            let newCountdown = Countdown(day: day, hour: hour, minute: minute, duration: duration)
            self.countdowns.append(newCountdown)
        }
    }
    
    private func getJSON() {
        if(self.updateReady) {
            // don't update while previous update in queue
            self.setUpdateTimer()
            return
        }
        let jsonLocation = self.applicationSupport + "/json.txt"
        let userAgent = "Digital Signage"
        let request = NSMutableURLRequest(url: self.url as URL)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let session = URLSession.shared
        let task = session.dataTask(with: request as URLRequest) { (data, response, error) -> Void in
            if error == nil {
                if let dumpData = data {
                    let dumpNSData = NSData(data: dumpData)
                    do {
                        var cachedJSON = try JSON(data: dumpData)
                        if let cachedData = NSData(contentsOfFile: String(describing: jsonLocation)) {
                            do {
                                let localCachedJSON = try JSON(data: cachedData as Data)
                                cachedJSON = localCachedJSON
                                if(dumpNSData.isEqual(to: cachedData) && !self.initializing) {
                                    self.setUpdateTimer()
                                    NSLog("No changes")
                                    return
                                }
                                if (!(dumpNSData.write(toFile: jsonLocation.rawValue, atomically: true))) {
                                    NSLog("Unable to write to file %@", jsonLocation.rawValue)
                                }
                            } catch {
                                NSLog("Could not parse json from data.")
                            }
                        }
                        else {
                            if (!(dumpNSData.write(toFile: jsonLocation.rawValue, atomically: true))) {
                                NSLog("Unable to write to file %@", jsonLocation.rawValue)
                            }
                        }
                        do {
                            let json = try JSON(data: dumpData)
                            if let countdowns = json["countdowns"].array {
                                self.generateCountdowns(countdowns: countdowns)
                            }
                            if let items = json["items"].array {
                                let cachedItems = cachedJSON["items"].array
                                if(items.count > 0) {
                                    self.slideshowLoader.removeAll()
                                    for item in items {
                                        if let itemUrl = item["url"].string {
                                            if let itemNSURL = NSURL(string: itemUrl) {
                                                if let type = item["type"].string {
                                                    if let filename = itemNSURL.lastPathComponent {
                                                        let cachePath = Path(stringInterpolation: self.applicationSupport + "/" + filename)
                                                        let slideshowItem = SlideshowItem(url: itemNSURL as URL, type: type, path: cachePath)
                                                        if(type == "image") {
                                                            if let duration = item["duration"].int {
                                                                slideshowItem.duration = duration
                                                            }
                                                        }
                                                        do {
                                                            let fileAttributes : NSDictionary? = try FileManager.default.attributesOfItem(atPath: NSURL(fileURLWithPath: cachePath.rawValue, isDirectory: false).path!) as NSDictionary?
                                                            if let fileSizeNumber = fileAttributes?.fileSize() {
                                                                let fileSize = fileSizeNumber
                                                                for cachedItem in cachedItems! {
                                                                    if(itemUrl == cachedItem["url"].stringValue) {
                                                                        if let itemSize = UInt64(item["filesize"].stringValue, radix: 10) {
                                                                            if(item["md5sum"] == cachedItem["md5sum"] && itemSize == fileSize) {
                                                                                slideshowItem.status = 1
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                        catch {
                                                        }
                                                        self.slideshowLoader.append(slideshowItem)
                                                    }
                                                    else {
                                                        NSLog("Could not retrieve filename from url: %@", itemUrl)
                                                    }
                                                }
                                                else {
                                                    continue
                                                }
                                            }
                                            else {
                                                continue
                                            }
                                        }
                                        else {
                                            continue
                                        }
                                    }
                                    self.downloadItems()
                                }
                                else {
                                    let alert = NSAlert()
                                    alert.messageText = "Couldn't load any items."
                                    if let dataString = String(data: dumpData, encoding: String.Encoding.utf8) {
                                        alert.informativeText = dataString
                                    }
                                    alert.addButton(withTitle: "OK")
                                    let _ = alert.runModal()
                                }
                            }
                        } catch {
                            NSLog("Could not parse json from data")
                            return
                        }
                    } catch {
                        NSLog("Could not parse json from data.")
                        return
                    }
                }
                else {
                    let alert = NSAlert()
                    alert.messageText = "Couldn't process data."
                    alert.addButton(withTitle: "OK")
                    let _ = alert.runModal()
                }
            }
            else {
                if(self.initializing) {
                    if let cachedData = NSData(contentsOfFile: String(describing: jsonLocation)) {
                        do {
                            let json = try JSON(data: cachedData as Data)
                            if let countdowns = json["countdowns"].array {
                                self.generateCountdowns(countdowns: countdowns)
                            }
                            if let items = json["items"].array {
                                if(items.count > 0) {
                                    for item in items {
                                        if let itemUrl = item["url"].string {
                                            if let itemNSURL = NSURL(string: itemUrl) {
                                                if let type = item["type"].string {
                                                    if let filename = itemNSURL.lastPathComponent {
                                                        let cachePath = Path(stringInterpolation: self.applicationSupport + "/" + filename)
                                                        if(cachePath.exists) {
                                                            let slideshowItem = SlideshowItem(url: itemNSURL as URL, type: type, path: cachePath)
                                                            slideshowItem.status = 1
                                                            self.slideshowLoader.append(slideshowItem)
                                                        }
                                                    }
                                                    else {
                                                        NSLog("Could not retrieve filename from url: %@", itemUrl)
                                                    }
                                                }
                                                else {
                                                    continue
                                                }
                                            }
                                            else {
                                                continue
                                            }
                                        }
                                        else {
                                            continue
                                        }
                                    }
                                    self.downloadItems()
                                }
                            }
                        } catch {
                            let alert = NSAlert()
                            alert.messageText = "Couldn't load data."
                            alert.addButton(withTitle: "OK")
                            let _ = alert.runModal()
                        }
                    }
                    else {
                        let alert = NSAlert()
                        alert.messageText = "Couldn't load data."
                        alert.addButton(withTitle: "OK")
                        let _ = alert.runModal()
                    }
                }
                else {
                    NSLog("Offline")
                    self.setUpdateTimer()
                }
            }
        }
        task.resume()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.window?.acceptsMouseMovedEvents = true
        self.countdown.isHidden = true
        self.countdown.alphaValue = 0.7
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        if let urlString = UserDefaults.standard.string(forKey: "url") {
            self.loadSignage(urlString: urlString)
        }
        if(self.addressBox.isDescendant(of: self.view)) {
            DispatchQueue.main.async(execute: { () -> Void in
                self.addressBox.becomeFirstResponder()
            })
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if(context == &ViewController.playerItemContext) {
            if keyPath == #keyPath(AVPlayerItem.status) {
                let status: AVPlayerItemStatus
                if let statusNumber = change?[.newKey] as? NSNumber {
                    status = AVPlayerItemStatus(rawValue: statusNumber.intValue)!
                } else {
                    status = .unknown
                }
                switch status {
                    case .readyToPlay:
                        break
                    case .failed:
                        (object as! AVPlayerItem?)?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), context: &ViewController.playerItemContext)
                        self.showNextSlide()
                        break
                    case .unknown:
                        (object as! AVPlayerItem?)?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), context: &ViewController.playerItemContext)
                        self.showNextSlide()
                        break
                }
            }
        }
        else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}
