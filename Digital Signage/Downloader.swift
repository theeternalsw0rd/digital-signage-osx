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

class Downloader: Operation {
    let item: SlideshowItem
    
    init(item: SlideshowItem) {
        self.item = item
        super.init()
    }
    
    override func main() {
        let _ = URLSession.shared.downloadTask(with: self.item.url, completionHandler: { tempFile, response, error in
            guard let tempFile = tempFile else {
                NSLog("Problem downloading item due to undocumented system error.")
                self.item.status = -1
                return
            }
            if let error = error {
                NSLog("Failed with error: " + error.localizedDescription)
                self.item.status = -1
                return
            }
            else {
                let fileManager = FileManager.default
                if(fileManager.fileExists(atPath: self.item.path)) {
                    do {
                        try fileManager.removeItem(atPath: self.item.path)
                    } catch let fileErr {
                        self.item.status = -1
                        NSLog("Failed to delete existing file. " + fileErr.localizedDescription)
                        return
                    }
                }
                do {
                    try fileManager.moveItem(atPath: tempFile.path, toPath: self.item.path)
                } catch let fileErr {
                    self.item.status = -1
                    NSLog("Failed to write item to disk " + self.item.path + " with error: " + fileErr.localizedDescription)
                    return
                }
                self.item.status = 1
                NSLog("Item written to disk at " + self.item.path)
            }
        }).resume()
        while(self.item.status == 0) {
            usleep(100000)
        }
    }
}
