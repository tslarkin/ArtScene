//
//  NSImage+File.swift
//  Art Scene
//
//  Created by Timothy Larkin on 8/13/18.
//  Copyright © 2018 Timothy Larkin. All rights reserved.
//

import Cocoa

extension NSImage {
    func writeToFile(file: String, atomically: Bool, usingType type: NSBitmapImageRep.FileType) -> Bool {
        let properties: [NSBitmapImageRep.PropertyKey : Any] = [NSBitmapImageRep.PropertyKey.compressionFactor: 1]
        guard
            let imageData = tiffRepresentation,
            let imageRep = NSBitmapImageRep(data: imageData),
            let fileData = imageRep.representation(using: type, properties: properties) else {
                return false
        }
        var ok = true
        do {
            try fileData.write(to: URL(fileURLWithPath: file))
        } catch {
            ok = false
        }
        return ok
    }
}
