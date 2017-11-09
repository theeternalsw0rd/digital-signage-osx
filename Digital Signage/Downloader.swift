//
//  Downloader.swift
//  Digital Signage
//
//  Created by Micah Bucy on 12/22/15.
//  Copyright © 2015 Micah Bucy. All rights reserved.
//
//  The MIT License (MIT)
//  This file is subject to the terms and conditions defined in LICENSE.md

import Foundation
import AppKit
import Alamofire

class Downloader: Operation {
    let item: SlideshowItem
    
    init(item: SlideshowItem) {
        self.item = item
        super.init()
    }
    
    override func main() {
        let destination: DownloadRequest.DownloadFileDestination = { _, _ in
            let destinationURL = URL(fileURLWithPath: self.item.path.rawValue, isDirectory: false)
            return (destinationURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        Alamofire.download(self.item.url, to: destination)
        .response { response in
            if let error = response.error {
                NSLog("Failed with error: %@", error.localizedDescription)
                self.item.status = -1
            } else {
                self.item.status = 1
                NSLog("Downloaded %@", self.item.path.rawValue)
            }
        }
        while(self.item.status == 0) {
            usleep(100000)
        }
    }
}
