//
//  Print.swift
//  Art Scene
//
//  Created by Timothy Larkin on 10/23/15.
//  Copyright © 2015 Timothy Larkin. All rights reserved.
//

import Cocoa
import SceneKit

let maxWallLength: CGFloat = 20.0 // If a wall is wider than this, it should be printed across pages

extension ArtSceneView
{

    func getPrintWalls(_ walls: [SCNNode])->[(node: SCNNode, count: Int)]
    {
        var pWalls:[(SCNNode, Int)] = []
        
        for wall in walls {
            if  wall.childNodes.filter( { nodeType($0) == .Picture}).count == 0 {
                continue
            }
            let count = Int(ceil(wall.size()!.width / maxWallLength))
                pWalls.append((wall, count))
        }
        return pWalls
    }
    
    func printView(_ info: NSPrintInfo) -> NSView
    {
        info.bottomMargin = 18
        info.topMargin = 18
        info.leftMargin = 18
        info.rightMargin = 18
        info.orientation = .landscape
        var size = info.paperSize
        size.width -= info.leftMargin + info.rightMargin
        size.height -= info.topMargin + info.bottomMargin
        let walls = scene!.rootNode.childNodes(passingTest: { x, yes in x.name == "Wall" && x.childNodes.filter({ nodeType($0) == .Picture}).count > 0})
        let printWalls = getPrintWalls(walls)
        size.height *= printWalls.reduce(0.0, { $0 + CGFloat($1.count) })
        let max = printWalls.map( { return min(nodeSize($0.node).width, maxWallLength) } ).max()
        let scale: CGFloat = size.width / max!
        var frame = NSRect.zero
        frame.size = size
        let print = ArtScenePrinter(frame: frame)
        print.walls = printWalls
        print.scaleUnitSquare(to: NSSize(width: scale, height: scale))
        print.scene = scene!
        print.pageRange = NSRange(location: 1, length: printWalls.reduce(0, { $0 + $1.count }))
        print.printInfo = info
        return print
    }
    
}
