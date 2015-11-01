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
    func printView(info: NSPrintInfo) -> NSView
    {
        var size = info.paperSize
        size.width -= info.leftMargin + info.rightMargin
        size.height -= info.topMargin + info.bottomMargin
        let walls = scene!.rootNode.childNodesPassingTest({ x, yes in x.name == "Wall"})
        size.height *= CGFloat(walls.count)
        let max = walls.map( { return nodeSize($0).width } ).maxElement()
        let scale: CGFloat = size.width / max!
        var frame = NSRect.zero
        frame.size = size
        let print = ArtScenePrinter(frame: frame)
        print.scaleUnitSquareToSize(NSSize(width: scale, height: scale))
        print.scene = scene!
        print.pageRange = NSRange(location: 1, length: walls.count)
        print.printInfo = info
        print.imageCache = imageCacheForPrint
        return print
    }
    
}
