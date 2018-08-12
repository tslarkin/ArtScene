//
//  Print.swift
//  Art Scene
//
//  Created by Timothy Larkin on 10/23/15.
//  Copyright © 2015 Timothy Larkin. All rights reserved.
//

import Cocoa

extension ArtSceneView
{
    func printView(_ info: NSPrintInfo) -> NSView
    {
        var size = info.paperSize
        size.width -= info.leftMargin + info.rightMargin
        size.height -= info.topMargin + info.bottomMargin
        let walls = scene!.rootNode.childNodes(passingTest: { x, yes in x.name == "Wall"})
        size.height *= CGFloat(walls.count)
        let max = walls.map( { return nodeSize($0).width } ).max()
        let scale: CGFloat = size.width / max!
        var frame = NSRect.zero
        frame.size = size
        let print = ArtScenePrinter(frame: frame)
        print.scaleUnitSquare(to: NSSize(width: scale, height: scale))
        print.scene = scene!
        print.pageRange = NSRange(location: 1, length: walls.count)
        print.printInfo = info
        print.imageCache = imageCacheForPrint
        return print
    }
    
}
