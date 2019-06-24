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
    
    func drawCenteredString(_ name: NSString, atPoint point: NSPoint, withAttributes attribs: [NSAttributedString.Key: AnyObject]) {
        let size = name.size(withAttributes: attribs)
        var p = point
        p.x -= size.width / 2.0
        name.draw(at: p, withAttributes: attribs)
    }
    
    func drawRectString(_ string: NSString, inRect rect: CGRect, withAttributes attribs: [NSAttributedString.Key: AnyObject]) {
        string.draw(in: rect, withAttributes: attribs)
    }
    
    func drawString(_ name: NSString, atPoint point: NSPoint, justification: NodeEdge, withAttributes attribs: [NSAttributedString.Key: AnyObject])
    {
        let size = name.size(withAttributes: attribs)
        var p = point
        switch justification {
        case .right:
            p.x -= size.width
        case .center:
            p.x -= size.width / 2.0
        default:
            ()
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
        func drawImage(_ name: NSString, node: SCNNode, rect: CGRect, attribs: [NSAttributedString.Key: AnyObject])
        {
            var newImage: NSImage!
            let data = node.geometry?.firstMaterial?.diffuse.contents
            if let data = data as? Data {
                newImage = NSImage(data: data)
            } else {
                newImage = data as? NSImage
            }
            newImage.draw(in: rect, from: NSRect(origin: CGPoint.zero, size: newImage.size),
                          operation: .copy, fraction: 1.0, respectFlipped: false, hints: nil)
        }
        
        /// Draw an arrow from base, of a certain length. The arrow head is centered at {0, 0}, and the arrow is pointed at angle.
        func drawArrow(base: CGPoint, length: CGFloat, angle: CGFloat)
        {
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: base.x, yBy: base.y)
            transform.rotate(byRadians: angle)
            transform.concat()
            NSBezierPath.strokeLine(from: NSPoint(x: 0, y: 0), to: NSPoint(x: length, y: 0.0))
            let s = 2.0.inches // length of a side of the arrow head
            let h = sqrt (s * s - s * s / 4.0) // distance between a vertex and the mid-point of its opposite side
            let path = NSBezierPath()
            path.move(to: NSPoint(x: -h / 2.0, y: 0.0))
            path.line(to: NSPoint(x: h / 2.0, y: s / 2.0))
            path.line(to: NSPoint.zero)
            path.line(to: NSPoint(x: h / 2.0, y: -s / 2.0))
            path.close()
            path.stroke()
            NSGraphicsContext.restoreGraphicsState()
        }
        
        /// Draw the picture's frame, image, and distances.
        func drawPicture(_ picture: SCNNode, reference: CGPoint?, attributes attribs: [NSAttributedString.Key: AnyObject])
        {
            let referencex = reference == nil ? -picture.parent!.size()!.width / 2.0 : reference!.x
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
            if !hidden {
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
            let x = picture.centerX - referencex
//            let x2 = picture.parent!.size()!.width / 2.0 + picture.centerX
            let xf = convertToFeetAndInches(x, units: .feet) as NSString
//            let x2f = convertToFeetAndInches(x2, units: .feet) as NSString
            var arrowLength = 5.0.inches
            drawString(xf as NSString,
                       atPoint: NSPoint(x: 0.0, y: -pictureSize.height / 2.0 - (font.ascender - font.descender)),
                       justification: NodeEdge.center,
                       withAttributes: attribs)
            NSBezierPath.strokeLine(from: NSPoint(x: 0.0, y: -pictureSize.height / 2.0 - 1.2 * (font.ascender - font.descender)), to: NSPoint(x: 0.0, y: -pictureSize.height / 2.0 - 2.0 * (font.ascender - font.descender)))
            drawArrow(base: CGPoint(x: -arrowLength, y: -pictureSize.height / 2.0 - 1.6 * (font.ascender - font.descender)), length: arrowLength, angle: 0.0)
            
            // draw the distance from the floor
            let rotator = NSAffineTransform()
            rotator.translateX(by: -picture.size()!.width / 2.0, yBy: picture.size()!.height / 2.0)
            rotator.rotate(byDegrees: 90.0)
            NSGraphicsContext.saveGraphicsState()
            rotator.concat()
            let fromFloor = distanceForPicture(picture, axis: .y, coordinate: picture.topEdge)
            let ffSize = (fromFloor as NSString).size(withAttributes: attribs)
            NSBezierPath.strokeLine(from: NSPoint.zero, to: NSPoint(x: 0.0, y: font.xHeight * 2.0))
            NSBezierPath.strokeLine(from: NSPoint(x: 0.0, y: font.xHeight), to: NSPoint(x: -1.0.inches, y: font.xHeight))
            drawString(fromFloor as NSString, atPoint: NSPoint(x: -1.0.inches, y:  -font.descender), justification: NodeEdge.right, withAttributes: attribs)
            arrowLength = 2.0.inches
            drawArrow(base: CGPoint(x: -ffSize.width - arrowLength - 1.0.inches, y: font.xHeight), length: arrowLength, angle: 0.0)
//            NSBezierPath.strokeLine(from: NSPoint.zero, to: NSPoint(x: 0, y: -tick))
            NSGraphicsContext.restoreGraphicsState()
            // Draw a line between the centers of the previous picture and the current picture
            if reference != nil {
                let adj =  reference!.x - picture.centerX
                let opp = reference!.y - picture.centerY
                let length = sqrt(adj * adj + opp * opp)
                let angle: CGFloat = atan2(opp, adj)
                drawArrow(base: NSPoint.zero, length: length, angle: angle)
            }
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
            style.lineBreakMode = .byWordWrapping
            style.alignment = NSTextAlignment.center
            let attributes: [NSAttributedString.Key: AnyObject] = [.font: font, .paragraphStyle: style]
            
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
            pictures.sort(by: { $0.position.x < $1.position.x })
            var previous: CGPoint?
            for picture in pictures {
                // Draw a line from the left bottom of the previous picture to the left bottom of the current one.
                drawPicture(picture, reference: previous, attributes: attributes)
                previous = CGPoint(x: picture.position.x, y: picture.position.y)
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
            for _ in 0..<count {
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
		style.lineBreakMode = .byTruncatingMiddle
        style.alignment = NSTextAlignment.center
        let attributes: [NSAttributedString.Key: AnyObject] = [NSAttributedString.Key.font: font,
                                                        NSAttributedString.Key.paragraphStyle: style]
        
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
