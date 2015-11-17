//
//  Framer.swift
//  Art Scene
//
//  Created by Timothy Larkin on 10/8/15.
//  Copyright © 2015 Timothy Larkin. All rights reserved.
//

import Cocoa
import SceneKit
import CoreGraphics

/**
 Logic for framing pictures.
*/
extension ArtSceneViewController {
    
    /// Make a black picture frame, one inch deep, of a given height and width.
    func makeFrame(size: CGSize) -> SCNNode {
        let segmentDepth: CGFloat = 1.0 / 12.0
        let segmentWidth: CGFloat = segmentDepth / 4.0
        let top = SCNBox(width: size.width, height: segmentWidth, length: segmentDepth, chamferRadius: 0)
        let blackMaterial = SCNMaterial()
        blackMaterial.diffuse.contents = NSColor.blackColor()
        blackMaterial.specular.contents = NSColor.whiteColor()
        blackMaterial.shininess = 1.0
        top.materials = [blackMaterial]
        let topNode = SCNNode(geometry: top)
        topNode.castsShadow = true
        topNode.name = "Top"
        topNode.position = SCNVector3(x: 0, y: size.height / 2.0 - segmentWidth / 2.0, z: 0)
        let bottomNode = topNode.copy() as! SCNNode
        bottomNode.position.y = -bottomNode.position.y
        bottomNode.name = "Bottom"
        
        let left = SCNBox(width: segmentWidth, height: size.height, length: segmentDepth, chamferRadius: 0)
        left.materials = [blackMaterial]
        let leftNode = SCNNode(geometry: left)
        leftNode.position = SCNVector3(x: size.width / 2.0 - segmentWidth / 2.0, y: 0, z: 0)
        leftNode.name = "Right"
        
        let rightNode = leftNode.copy() as! SCNNode
        rightNode.position.x = -rightNode.position.x
        rightNode.name = "Left"
        
        let node = SCNNode()
        node.addChildNode(topNode)
        node.addChildNode(bottomNode)
        node.addChildNode(leftNode)
        node.addChildNode(rightNode)
        node.name = "Frame"
        node.position.z += segmentDepth / 2.0
        return node
    }
    
    /// Make a picture's matt.
    func makeMatt(size: CGSize) -> SCNNode {
        let matt = SCNPlane(width: size.width - 0.02, height: size.height - 0.02)
        let material = SCNMaterial()
        material.doubleSided = true
        matt.materials = [material]
        let mattNode = SCNNode(geometry: matt)
        mattNode.name = "Matt"
        return mattNode
    }
    
    /// Make the picture's image.
    func makeImage(image: NSImage) ->SCNNode
    {
        let size = image.size
        let picture = SCNPlane(width: size.width, height: size.height)
        let pictureMaterial = SCNMaterial()
        pictureMaterial.diffuse.contents = image
//        pictureMaterial.locksAmbientWithDiffuse = false
//        pictureMaterial.ambient.contents = NSColor.blackColor()
        picture.materials = [pictureMaterial]
        let imageNode = SCNNode(geometry: picture)
        imageNode.name = "Image"
        return imageNode
    }
    
    /// Make the picture's glass. This is a transparent plane; its only function is to be
    /// found by `hitTest`.
    func makeGlass(size: CGSize) -> SCNPlane
    {
        let plane = SCNPlane(width: size.width, height: size.height)
        let planeMaterial = SCNMaterial()
        planeMaterial.transparency = 0.0
        plane.materials = [planeMaterial]
        return plane
    }
    
    /// Make the entire picture from frame, matt, image, and glass.
    func makePicture(path: String, size _size: CGSize = CGSize.zero) -> SCNNode? {
        guard let image = NSImage(byReferencingFile: path) else {
            return nil
        }
        var size = image.size
        let scale = 256.0 / max(size.width, size.height)
        let thumbnail = NSImage(size: CGSize(width: size.width * scale, height: size.height * scale))
        thumbnail.lockFocus()
        image.drawInRect(NSRect(origin: CGPoint.zero, size: thumbnail.size),
            fromRect: NSRect(origin: CGPoint.zero, size: image.size),
            operation: NSCompositingOperation.CompositeCopy, fraction: 1.0)
        thumbnail.unlockFocus()
        thumbnail.size = image.size
        let front: CGFloat = 0.9 * (1.0 / 12.0)
        size = _size == CGSize.zero ? defaultFrameSize : _size
        thumbnail.size.width /= (12 * 72)
        thumbnail.size.height /= (12 * 72)
        if size.width < thumbnail.size.width {
            size.width = thumbnail.size.width
        }
        if size.height < thumbnail.size.height {
            size.height = thumbnail.size.height
        }
        let imageNode = makeImage(thumbnail)
        imageNode.position.z += front
        imageNode.renderingOrder = 1
        let mattNode = makeMatt(size)
        mattNode.position.z += front - 0.01
        let frameNode = makeFrame(size)
        let glass = makeGlass(size)
        glass.name = path
        let pictureNode = SCNNode(geometry: glass)
        pictureNode.position.z += 0.1
        pictureNode.name = "Picture"
        pictureNode.addChildNode(frameNode)
        pictureNode.addChildNode(mattNode)
        pictureNode.addChildNode(imageNode)
        if let (name, thumbnail) = makeThumbnail(pictureNode) {
            artSceneView.imageCacheForPrint?[name] = thumbnail
        }
        return pictureNode
    }

    /// Reframe a picture to a new size. The size cannot be smaller than the image.
    func reframePictureWithSize(picture: SCNNode, newsize: CGSize)
    {
        let image = picture.childNodeWithName("Image", recursively: true)!
        let oldPlane = image.geometry as! SCNPlane
        var size = newsize
        if size.width < oldPlane.width {
            size.width =  oldPlane.width
        }
        if size.height < oldPlane.height {
            size.height = oldPlane.height
        }
//        size.width = roundToQuarterInch(size.width)
//        size.height = roundToQuarterInch(size.height)
        let oldMatt = picture.childNodeWithName("Matt", recursively: true)
        if let geometry = oldMatt?.geometry as? SCNPlane {
            geometry.width = size.width - 0.02
            geometry.height = size.height - 0.02
        }
        let oldFrame = picture.childNodeWithName("Frame", recursively: true)
        picture.replaceChildNode(oldFrame!, with: makeFrame(size))
        let glass = makeGlass(size)
        glass.name = picture.geometry?.name
        picture.geometry = glass
    }

}
