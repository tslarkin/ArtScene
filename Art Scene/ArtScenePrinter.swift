//
//  ArtScenePrinter.swift
//  Art Scene
//
//  Created by Timothy Larkin on 10/23/15.
//  Copyright © 2015 Timothy Larkin. All rights reserved.
//

import Cocoa
import SceneKit

class ArtScenePrinter: NSView {
    
    var pageRange: NSRange = NSRange()
    weak var scene: SCNScene?
    weak var printInfo: NSPrintInfo?
    var currentPageNumber: Int = 0
    var imageCache: [String: NSImage]? = nil
    
    override func knowsPageRange(range: NSRangePointer) -> Bool {
        range.memory.location = pageRange.location
        range.memory.length = pageRange.length
        return true
    }
    
    override func rectForPage(page: Int) -> NSRect {
        currentPageNumber = page
        var bounds = self.bounds
        let n = CGFloat(pageRange.length)
        let height = bounds.height / n
        bounds.origin.y = CGFloat(page - 1) * height
        bounds.size.height = height
        return bounds
    }
    
    func drawCenteredString(name: NSString, atPoint point: NSPoint, withAttributes attribs: [String: AnyObject]) {
        let size = name.sizeWithAttributes(attribs)
        var p = point
        p.x -= size.width / 2.0
        name.drawAtPoint(p, withAttributes: attribs)
    }
    
    func drawRectString(string: NSString, inRect rect: CGRect, withAttributes attribs: [String: AnyObject]) {
        string.drawInRect(rect, withAttributes: attribs)
    }

    func drawScene(dirtyRect: NSRect)
    {
        func drawImage(name: NSString, rect: CGRect, attribs: [String: AnyObject])
        {
            if let image = imageCache?[name as String] {
//                Swift.print(rect.size, image.size)
                image.drawInRect(rect, fromRect: NSRect(origin: CGPoint.zero, size: image.size),
                    operation: .CompositeCopy, fraction: 1.0, respectFlipped: false, hints: nil)
                
            } else {
                let font = NSFont.systemFontOfSize(6.0 * bounds.height / frame.height)
                let style = attribs[NSParagraphStyleAttributeName]! as! NSMutableParagraphStyle
                style.maximumLineHeight = 7.0 * bounds.height / frame.height
                var fileName: NSString = name.lastPathComponent
                fileName = fileName.stringByDeletingPathExtension
                var rect1 = rect
                rect1.origin.y -= 1.0
                drawRectString(fileName,
                    inRect: rect1,
                    withAttributes: [NSFontAttributeName: font,
                        NSParagraphStyleAttributeName:style])
            }

        }
        
        func drawPicture(picture: SCNNode, referencex: CGFloat, attributes attribs: [String: AnyObject])
        {
            let font = attribs[NSFontAttributeName]
            let fontHeight = font!.capHeight
            let pictureSize = nodeSize(picture)
            let transform = NSAffineTransform()
            transform.translateXBy(picture.position.x, yBy: picture.position.y)
            transform.concat()
            let rect = NSRect(origin: NSPoint(x: -pictureSize.width / 2, y: -pictureSize.height / 2), size: pictureSize)
            NSBezierPath.strokeRect(rect)
            let geometry: SCNGeometry! = picture.geometry
            let tick = 5 * bounds.height / frame.height
            
            // draw the distance from the left side of the wall
            let fromLeft =  distanceForPicture(picture, axis: .X, coordinate: picture.position.x)
            drawCenteredString(fromLeft, atPoint: NSPoint(x: 0, y: -pictureSize.height / 2.0 - 1 - fontHeight + font!.descender), withAttributes: attribs)
            
            // draw the distance from the center of the previous picture, or the left side of the wall
            // if there is no previous picture
            let x = picture.position.x - referencex
            drawCenteredString(convertToFeetAndInches(x, units: .Feet), atPoint: NSPoint(x: 0, y: -pictureSize.height / 2.0 - 1 - font!.descender), withAttributes: attribs)
            let tick1 = -pictureSize.height / 2.0 + fontHeight - font!.descender
            NSBezierPath.strokeLineFromPoint(NSPoint(x: 0, y: tick1),
                toPoint: NSPoint(x: 0, y: tick1 + tick))
            
            // draw the distance from the floor
            let rotator = NSAffineTransform()
            rotator.rotateByDegrees(90.0)
            rotator.translateXBy(0, yBy: pictureSize.width / 2.0)
            rotator.concat()
            let fromFloor = distanceForPicture(picture, axis: .Y, coordinate: picture.position.y)
            drawCenteredString(fromFloor, atPoint: NSPoint(x: 0, y: -1 - font!.descender), withAttributes: attribs)
            NSBezierPath.strokeLineFromPoint(NSPoint.zero, toPoint: NSPoint(x: 0, y: -tick))
            rotator.invert()
            rotator.concat()
            
            // Draw the image, if there is one
            if let name: NSString = geometry.name,
                let imageNode = picture.childNodeWithName("Image", recursively: true),
                let geometry = imageNode.geometry as? SCNPlane {
                let r =  CGRect(x: -geometry.width / 2, y: -geometry.height / 2, width: geometry.width, height: geometry.height)
                drawImage(name, rect: r, attribs: attribs)
            }
            
            transform.invert()
            transform.concat()
            
        }
        
        func drawWall(wall: SCNNode)
        {
            let font = NSFont.systemFontOfSize(8.0 * bounds.height / frame.height)
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = NSLineBreakMode.ByWordWrapping
            style.alignment = NSTextAlignment.Center
            style.maximumLineHeight = 9.0 * bounds.height / frame.height
            let attributes = [NSFontAttributeName: font, NSParagraphStyleAttributeName: style]
            
            let wallSize = nodeSize(wall)
            var rect = NSRect()
            rect.size = wallSize
            rect.origin.x = -wallSize.width / 2.0
            rect.origin.y = -wallSize.height / 2.0
            NSBezierPath.strokeRect(rect)
            var pictures = wall.childNodes
            pictures.sortInPlace({ $0.position.x < $1.position.x })
            var previousX = -wallSize.width / 2.0
            var previousY: CGFloat?
            for picture in pictures {
                drawPicture(picture, referencex: previousX, attributes: attributes)
                if let previousy = previousY {
                    NSBezierPath.strokeLineFromPoint(NSPoint(x: previousX, y: previousy),
                        toPoint: NSPoint(x: picture.position.x, y: picture.position.y))
                }
                previousX = picture.position.x
                previousY = picture.position.y
            }
        }
        
        let walls = scene!.rootNode.childNodesPassingTest({ x, yes in x.name == "Wall"})
        if walls.isEmpty { return }
        let pageHeight: CGFloat = bounds.height / CGFloat(pageRange.length)
        NSBezierPath.setDefaultLineWidth(0.01)
        NSColor.blackColor().setStroke()
        
        let transform = NSAffineTransform()
        transform.translateXBy(bounds.width / 2.0, yBy: pageHeight / 2.0)
        let dTransform = NSAffineTransform()
        dTransform.translateXBy(0, yBy: pageHeight)
        transform.concat()
        for (i, wall) in walls.enumerate() {
            if i == currentPageNumber - 1 {
                drawWall(wall)
            }
            let inverse = transform.copy()
            inverse.invert()
            inverse.concat()
            transform.appendTransform(dTransform)
            transform.concat()
        }
        transform.invert()
        transform.concat()
    }

    override func drawRect(dirtyRect: NSRect) {
        drawScene(dirtyRect)
    }

    override func drawPageBorderWithSize(borderSize: NSSize) {
        guard let info = printInfo else { return }
        
        let font = NSFont.systemFontOfSize(8.0 * bounds.height / frame.height)
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = NSLineBreakMode.ByTruncatingMiddle
        style.alignment = NSTextAlignment.Center
        let attributes = [NSFontAttributeName: font, NSParagraphStyleAttributeName: style]
        
        let oldFrame = frame
        let scale = bounds.size.width / frame.size.width
        frame = NSRect(origin: CGPoint.zero, size: borderSize)
        lockFocus()
        var y = bounds.height - info.topMargin * scale / 3.0
        let x = bounds.width / 2.0
        drawCenteredString("Page \(currentPageNumber)", atPoint: NSPoint(x: x, y: y - 1), withAttributes: attributes)
        y = info.bottomMargin * scale / 3.0
        
        let formatter = NSDateFormatter();
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss";
        let date = formatter.stringFromDate(NSDate());
        drawCenteredString("\(date)", atPoint: NSPoint(x: x, y: y - 1), withAttributes: attributes)
        unlockFocus()
        frame = oldFrame
    }
    
}
