//
//  MyView.swift
//  Digital Signage
//
//  Created by Micah Bucy on 12/27/15.
//  Copyright © 2015 Micah Bucy. All rights reserved.
//
//  The MIT License (MIT)
//  This file is subject to the terms and conditions defined in LICENSE.md

import Cocoa

class MyView: NSView {
    private var mouseTimer = Timer()
    var trackMouse = false
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
    func hideCursor() {
        NSCursor.setHiddenUntilMouseMoves(true)
    }
    
    func setTimeout() {
        DispatchQueue.main.async(execute: {
            self.mouseTimer.invalidate()
            self.mouseTimer = Timer(timeInterval: 5, target: self, selector: #selector(MyView.hideCursor), userInfo: nil, repeats: false)
            RunLoop.current.add(self.mouseTimer, forMode: RunLoopMode.commonModes)
        })
    }
    
    override func mouseMoved(with theEvent: NSEvent) {
        if(!self.trackMouse) {
            return
        }
        self.setTimeout()
    }
}
