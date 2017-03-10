//
//  SlideshowItem.swift
//  Digital Signage
//
//  Created by Micah Bucy on 12/17/15.
//  Copyright © 2015 Micah Bucy. All rights reserved.
//
//  The MIT License (MIT)
//  This file is subject to the terms and conditions defined in LICENSE.md

import Foundation
import AppKit
import FileKit

class SlideshowItem: Operation {
    var url = URL(fileURLWithPath: "")
    var type = "image"
    var image = NSImage()
    var path: Path
    var status = 0
    
    init(url: URL, type: String, path: Path) {
        self.url = url
        self.type = type
        self.path = path
    }
}
