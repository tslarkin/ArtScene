//
//  TextFieldExtension.swift
//  Art Scene
//
//  Created by Timothy Larkin on 10/22/15.
//  Copyright © 2015 Timothy Larkin. All rights reserved.
//

import Cocoa

extension NSTextField
{
    override open func mouseDown(with theEvent: NSEvent) {
        if let target = target {
            _ = target.perform(action, with: nil)
        }
    }
}
