//
//  ArtScenePrinter.swift
//  Art Scene
//
//  Created by Timothy Larkin on 10/23/15.
//  Copyright © 2015 Timothy Larkin. All rights reserved.
//

import Cocoa
import SceneKit

/**
The view that is rendered on a printer. This shows each wall on a separate page, with distances
for placing pictures. Vertical distances are measured from the floor. Horizontal distances are
measured from the left end of the wall and from the previous picture.
*/
class ArtScenePrinter: NSView {
    
    var pageRange: NSRange = NSRange()
    weak var scene: SCNScene?
    weak var printInfo: NSPrintInfo?
    var currentPageNumber: Int = 0
    /// The list of walls to be printed. A wall may appear more than once if it is spread over
    /// more than one page.
    var walls: [(node: SCNNode, count: Int)]!
    
    override func knowsPageRange(_ range: NSRangePointer) -> Bool {
        range.pointee.location = pageRange.location
        range.pointee.length = pageRange.length
        return true
    }
    
    /// returns the rect from the view that needs to be printed for `page`.
    override func rectForPage(_ page: Int) -> NSRect {
        currentPageNumber = page
        var bounds = self.bounds
        let n = CGFloat(pageRange.length)
        let height = bounds.height / n
        bounds.origin.y = CGFloat(page - 1) * height
        bounds.size.height = height
        return bounds
    }
    
    func drawCenteredString(_ name: NSString, atPoint point: NSPoint, withAttributes attribs: [NSAttributedStringKey: AnyObject]) {
        let size = name.size(withAttributes: attribs)
        var p = point
        p.x -= size.width / 2.0
        name.draw(at: p, withAttributes: attribs)
    }
    
    func drawRectString(_ string: NSString, inRect rect: CGRect, withAttributes attribs: [NSAttributedStringKey: AnyObject]) {
        string.draw(in: rect, withAttributes: attribs)
    }
    
    func drawString(_ name: NSString, atPoint point: NSPoint, justification: NodeEdge, withAttributes attribs: [NSAttributedStringKey: AnyObject])
    {
        let size = name.size(withAttributes: attribs)
        var p = point
        if case justification = NodeEdge.right {
            p.x -= size.width
        }
        p.y -= 1.0
        var rect = NSZeroRect
        rect.origin = p
        rect.size = size
        name.draw(in: rect, withAttributes: attribs)
 }

    /// Draw an entire scene in some number of pages.
    func drawScene(_ dirtyRect: NSRect)
    {
        /// Draw the picture's image from the cache, if it is available. Otherwise, draw the
        /// name of the picture
        func drawImage(_ name: NSString, node: SCNNode, rect: CGRect, attribs: [NSAttributedStringKey: AnyObject])
        {
            var newImage: NSImage!
            let data = node.geometry?.firstMaterial?.diffuse.contents
            if let data = data as? Data {
                newImage = NSImage(data: data)
            } else {
                newImage = data as! NSImage
            }
            newImage.draw(in: rect, from: NSRect(origin: CGPoint.zero, size: newImage.size),
                          operation: .copy, fraction: 1.0, respectFlipped: false, hints: nil)
        }
        
        /// Draw the picture's frame, image, and distances.
        func drawPicture(_ picture: SCNNode, referencex: CGFloat, attributes attribs: [NSAttributedStringKey: AnyObject])
        {
            let font = attribs[.font] as! NSFont
            let hidden = theFrame(picture).isHidden
            let savedSize = picture.size()!
            if hidden {
                picture.setSize(theImage(picture).size()!)
            }
            let pictureSize = nodeSize(picture)
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: picture.position.x, yBy: picture.position.y)
            transform.concat()
            let rect = NSRect(origin: NSPoint(x: -pictureSize.width / 2, y: -pictureSize.height / 2), size: pictureSize)
            if !theFrame(picture).isHidden {
                NSBezierPath.stroke(rect)
            }

            let geometry: SCNGeometry! = picture.geometry
            
            // Draw the image, if there is one
            if let name = geometry.name as NSString? {
                let imageNode = theImage(picture)
                let geometry = thePlane(imageNode)
                let r =  CGRect(x: -geometry.width / 2, y: -geometry.height / 2, width: geometry.width, height: geometry.height)
                drawImage(name, node: imageNode, rect: r, attribs: attribs)
            }
            
            // draw the distance from the left side of the wall
//            let fromLeft =  distanceForPicture(picture, axis: .x, coordinate: picture.leftEdge)
//            drawCenteredString(fromLeft as NSString, atPoint: NSPoint(x: bottomLeft.x, y: bottomLeft.y - 1 - fontHeight + font.descender), withAttributes: attribs)
            
            // draw the distance from the center of the previous picture, or the left side of the wall
            // if there is no previous picture
            let x = picture.leftEdge - referencex
            drawString(convertToFeetAndInches(x, units: .feet) as NSString,
                       atPoint: NSPoint(x: -pictureSize.width / 2.0, y: -pictureSize.height / 2.0 - (font.ascender - font.descender)),
                       justification: NodeEdge.left,
                       withAttributes: attribs)
            
            // draw the distance from the floor
            let rotator = NSAffineTransform()
//            rotator.translateX(by: bottomLeft.x, yBy: bottomLeft.y)
            rotator.rotate(byDegrees: 90.0)
            NSGraphicsContext.saveGraphicsState()
            rotator.concat()
            let fromFloor = distanceForPicture(picture, axis: .y, coordinate: picture.bottomEdge)
            drawString(fromFloor as NSString, atPoint: NSPoint(x: -pictureSize.height / 2.0, y: pictureSize.width / 2.0 - font.descender), justification: NodeEdge.left, withAttributes: attribs)
//            NSBezierPath.strokeLine(from: NSPoint.zero, to: NSPoint(x: 0, y: -tick))
            NSGraphicsContext.restoreGraphicsState()
            NSGraphicsContext.restoreGraphicsState()
            if hidden {
                picture.setSize(savedSize)
            }
        }
        
        /// Draw a wall and its pictures.
        func drawWall(_ wall: SCNNode)
        {
            // Prepare the attributes for text
            let fontSize: CGFloat = 8.0 * bounds.height / frame.height
//           let font1 = NSFont(name: "LucidaGrande", size: fontSize)
            let font = NSFont.systemFont(ofSize: fontSize)
//            let font = NSFont.systemFont(ofSize: fontSize)
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = NSParagraphStyle.LineBreakMode.byWordWrapping
            style.alignment = NSTextAlignment.center
            let attributes: [NSAttributedStringKey: AnyObject] = [.font: font, .paragraphStyle: style]
            
            // Stroke a rect the size of wall with its center at {0, 0}
            let wallSize = nodeSize(wall)
            var rect = NSRect()
            rect.size = wallSize
            rect.origin.x = -wallSize.width / 2.0
            rect.origin.y = -wallSize.height / 2.0
            NSBezierPath.stroke(rect)
            
            // Draw the pictures in x order, keeping track of the x coordinate of the previous picture
            // so that we can report its distance from the current picture.
            var pictures = wall.childNodes.filter{ nodeType($0) == .Picture }
            pictures.sort(by: { $0.leftEdge < $1.leftEdge })
            var previous: CGPoint?
            for picture in pictures {
                // Draw a line from the left bottom of the previous picture to the left bottom of the current one.
                let leftEdge = theFrame(picture).isHidden ? picture.position.x - theImage(picture).size()!.width / 2.0: picture.leftEdge
                let bottomEdge = theFrame(picture).isHidden ? picture.position.y - theImage(picture).size()!.height / 2.0: picture.bottomEdge
                if let previous = previous {
                    NSBezierPath.strokeLine(from: NSPoint(x: previous.x, y: previous.y),
                                            to: NSPoint(x: leftEdge, y: bottomEdge))
                } else {
                    previous = CGPoint(x: -wallSize.width / 2.0, y: 0.0)
                }
                drawPicture(picture, referencex: previous!.x, attributes: attributes)
                previous!.x = leftEdge
                previous!.y = bottomEdge
            }
        }
        
        // DrawScene begins.
        if walls.isEmpty { return }
        // bounds dimensions are feet, same as node dimensions
        let pageHeight: CGFloat = bounds.height / CGFloat(pageRange.length)
        let pageWidth: CGFloat = bounds.width
        NSBezierPath.defaultLineWidth = 0.01
        NSColor.black.setStroke()
        
        // `dTransform` is the transform delta, which prepares `transform` to print the next page.
        let dTransform = NSAffineTransform()
        dTransform.translateX(by: 0, yBy: pageHeight)
        var center: NSPoint = NSMakePoint(0.0, pageHeight / 2.0)
        for (wall, count) in walls {
            let totalWidth = pageWidth * CGFloat(count)
            center.x = totalWidth / 2.0
            NSGraphicsContext.saveGraphicsState()
            let t = NSAffineTransform()
            t.translateX(by: center.x, yBy: center.y)
            t.concat()
            for _ in 0...count - 1 {
                drawWall(wall)
                let t = NSAffineTransform()
                t.translateX(by: -pageWidth, yBy: pageHeight)
                t.concat()
                center.y += pageHeight
            }
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        drawScene(dirtyRect)
    }

    /// Draw the page number and date at the header and footer of the page.
    override func drawPageBorder(with borderSize: NSSize) {
        guard let info = printInfo else { return }
        
        let font = NSFont.systemFont(ofSize: 8.0 * bounds.height / frame.height)
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = NSParagraphStyle.LineBreakMode.byTruncatingMiddle
        style.alignment = NSTextAlignment.center
        let attributes: [NSAttributedStringKey: AnyObject] = [NSAttributedStringKey.font: font,
                                                        NSAttributedStringKey.paragraphStyle: style]
        
        let oldFrame = frame
        let scale = bounds.size.width / frame.size.width
        frame = NSRect(origin: CGPoint.zero, size: borderSize)
        lockFocus()
        var y = bounds.height - info.topMargin * scale / 3.0
        let x = bounds.width / 2.0
        drawCenteredString("Page \(currentPageNumber)" as NSString, atPoint: NSPoint(x: x, y: y - 1), withAttributes: attributes)
        y = info.bottomMargin * scale / 3.0
        
        let formatter = DateFormatter();
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss";
        let date = formatter.string(from: Date());
        drawCenteredString("\(date)" as NSString, atPoint: NSPoint(x: x, y: y - 1), withAttributes: attributes)
        unlockFocus()
        frame = oldFrame
    }
    
}
