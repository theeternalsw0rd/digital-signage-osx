//
//  MyImageView.swift
//  Digital Signage
//
//  Created by Micah Bucy on 12/27/15.
//  Copyright © 2015 Micah Bucy. All rights reserved.
//
//  The MIT License (MIT)
//  This file is subject to the terms and conditions defined in LICENSE.md

import Cocoa

class MyImageView: NSImageView {
    
    func imageWithSize(image: NSImage, w: CGFloat, h: CGFloat) {
        let destSize = NSMakeSize(w, h)
        let newImage = NSImage(size: destSize)
        newImage.lockFocus()
        image.draw(in: NSMakeRect(0, 0, destSize.width, destSize.height), from: NSMakeRect(0, 0, image.size.width, image.size.height), operation: NSCompositingOperation.sourceOver, fraction: CGFloat(1))
        newImage.unlockFocus()
        newImage.size = destSize
        self.image = NSImage(data: newImage.tiffRepresentation!)!
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
    override func mouseMoved(with theEvent: NSEvent) {
        super.mouseMoved(with: theEvent)
    }
    
    override func updateTrackingAreas() {
        if(trackingAreas.count > 0) {
            for trackingArea in trackingAreas {
                removeTrackingArea(trackingArea)
            }
        }
        let options = NSTrackingArea.Options.activeAlways.symmetricDifference(NSTrackingArea.Options.mouseMoved)
        let trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea)
    }
}
