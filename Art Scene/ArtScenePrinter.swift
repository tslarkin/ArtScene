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
    var imageCache: [String: NSImage]? = nil
    
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

    /// Draw an entire scene in some number of pages.
    func drawScene(_ dirtyRect: NSRect)
    {
        /// Draw the picture's image from the cache, if it is available. Otherwise, draw the
        /// name of the picture
        func drawImage(_ name: NSString, rect: CGRect, attribs: [NSAttributedStringKey: AnyObject])
        {
            if let image = imageCache?[name as String] {
                image.draw(in: rect, from: NSRect(origin: CGPoint.zero, size: image.size),
                    operation: .copy, fraction: 1.0, respectFlipped: false, hints: nil)
                
            } else {
                let font = NSFont.systemFont(ofSize: 6.0 * bounds.height / frame.height)
                let style = attribs[.paragraphStyle]! as! NSMutableParagraphStyle
                style.maximumLineHeight = 7.0 * bounds.height / frame.height
                var fileName: NSString = name.lastPathComponent as NSString
                fileName = fileName.deletingPathExtension as NSString
                var rect1 = rect
                rect1.origin.y -= 1.0
                drawRectString(fileName,
                    inRect: rect1,
                    withAttributes: [.font: font, .paragraphStyle: style])
            }

        }
        
        /// Draw the picture's frame, image, and distances.
        func drawPicture(_ picture: SCNNode, referencex: CGFloat, attributes attribs: [NSAttributedStringKey: AnyObject])
        {
            let font = attribs[.font] as! NSFont
            let fontHeight = font.capHeight
            let pictureSize = nodeSize(picture)
            let transform = NSAffineTransform()
            transform.translateX(by: picture.position.x, yBy: picture.position.y)
            (transform as NSAffineTransform).concat()
            let rect = NSRect(origin: NSPoint(x: -pictureSize.width / 2, y: -pictureSize.height / 2), size: pictureSize)
            NSBezierPath.stroke(rect)
            let geometry: SCNGeometry! = picture.geometry
            let tick = 5 * bounds.height / frame.height
            
            // draw the distance from the left side of the wall
            let fromLeft =  distanceForPicture(picture, axis: .x, coordinate: picture.position.x)
            drawCenteredString(fromLeft as NSString, atPoint: NSPoint(x: 0, y: -pictureSize.height / 2.0 - 1 - fontHeight + font.descender), withAttributes: attribs)
            
            // draw the distance from the center of the previous picture, or the left side of the wall
            // if there is no previous picture
            let x = picture.position.x - referencex
            drawCenteredString(convertToFeetAndInches(x, units: .feet) as NSString, atPoint: NSPoint(x: 0, y: -pictureSize.height / 2.0 - 1 - font.descender), withAttributes: attribs)
            let tick1 = -pictureSize.height / 2.0 + fontHeight - font.descender
            NSBezierPath.strokeLine(from: NSPoint(x: 0, y: tick1),
                to: NSPoint(x: 0, y: tick1 + tick))
            
            // draw the distance from the floor
            let rotator = NSAffineTransform()
            rotator.rotate(byDegrees: 90.0)
            rotator.translateX(by: 0, yBy: pictureSize.width / 2.0)
            rotator.concat()
            let fromFloor = distanceForPicture(picture, axis: .y, coordinate: picture.position.y)
            drawCenteredString(fromFloor as NSString, atPoint: NSPoint(x: 0, y: -1 - font.descender), withAttributes: attribs)
            NSBezierPath.strokeLine(from: NSPoint.zero, to: NSPoint(x: 0, y: -tick))
            rotator.invert()
            (rotator as NSAffineTransform).concat()
            
            // Draw the image, if there is one
            if let name = geometry.name as NSString?,
                let imageNode = picture.childNode(withName: "Image", recursively: true),
                let geometry = imageNode.geometry as? SCNPlane {
                let r =  CGRect(x: -geometry.width / 2, y: -geometry.height / 2, width: geometry.width, height: geometry.height)
                drawImage(name, rect: r, attribs: attribs)
            }
            
            transform.invert()
            (transform as NSAffineTransform).concat()
            
        }
        
        /// Draw a wall and its pictures.
        func drawWall(_ wall: SCNNode)
        {
            // Prepare the attributes for text
            let font = NSFont.systemFont(ofSize: 8.0 * bounds.height / frame.height)
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = NSParagraphStyle.LineBreakMode.byWordWrapping
            style.alignment = NSTextAlignment.center
            style.maximumLineHeight = 9.0 * bounds.height / frame.height
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
            var pictures = wall.childNodes
            pictures.sort(by: { $0.position.x < $1.position.x })
            var previousX = -wallSize.width / 2.0
            var previousY: CGFloat?
            for picture in pictures {
                drawPicture(picture, referencex: previousX, attributes: attributes)
                // Draw a line from the center of the previous picture to the center of the current one.
                if let previousy = previousY {
                    NSBezierPath.strokeLine(from: NSPoint(x: previousX, y: previousy),
                        to: NSPoint(x: picture.position.x, y: picture.position.y))
                }
                previousX = picture.position.x
                previousY = picture.position.y
            }
        }
        
        // DrawScene begins.
        let walls = scene!.rootNode.childNodes(passingTest: { x, yes in x.name == "Wall"})
        if walls.isEmpty { return }
        let pageHeight: CGFloat = bounds.height / CGFloat(pageRange.length)
        NSBezierPath.defaultLineWidth = 0.01
        NSColor.black.setStroke()
        
        // `dTransform` is the transform delta, which prepares `transform` to print the next page.
        let dTransform = NSAffineTransform()
        dTransform.translateX(by: 0, yBy: pageHeight)

        // `transform` puts {0, 0} at the center of the page.
        let transform = NSAffineTransform()
        transform.translateX(by: bounds.width / 2.0, yBy: pageHeight / 2.0)
        transform.concat()
        for (i, wall) in walls.enumerated() {
            if i == currentPageNumber - 1 {
                drawWall(wall)
            }
            let inverse: NSAffineTransform = transform.copy() as! NSAffineTransform
            inverse.invert()
            inverse.concat()
            transform.append(dTransform as AffineTransform)
            transform.concat()
        }
        transform.invert()
        (transform as NSAffineTransform).concat()
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
