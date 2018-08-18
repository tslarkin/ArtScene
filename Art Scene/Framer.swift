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
    func makeFrame(_ size: CGSize) -> SCNNode {
        let segmentDepth: CGFloat = 1.0 / 12.0
        let segmentWidth: CGFloat = segmentDepth / 4.0
        let top = SCNBox(width: size.width, height: segmentWidth, length: segmentDepth, chamferRadius: 0)
        let blackMaterial = SCNMaterial()
        blackMaterial.diffuse.contents = NSColor.black
        blackMaterial.specular.contents = NSColor.white
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
    func makeMatt(_ size: CGSize) -> SCNNode {
        let matt = SCNPlane(width: size.width - 0.02, height: size.height - 0.02)
        let material = SCNMaterial()
        material.isDoubleSided = true
        matt.materials = [material]
        let mattNode = SCNNode(geometry: matt)
        mattNode.name = "Matt"
        return mattNode
    }
    
    /// Make the picture's image.
    func makeImage(_ image: NSImage) ->SCNNode
    {
        let size = image.size
        let picture = SCNPlane(width: size.width, height: size.height)
        let pictureMaterial = SCNMaterial()
        pictureMaterial.diffuse.contents = image
        pictureMaterial.locksAmbientWithDiffuse = true
        pictureMaterial.ambient.contents = NSColor.black
        pictureMaterial.isDoubleSided = true
        picture.materials = [pictureMaterial]
        let imageNode = SCNNode(geometry: picture)
        imageNode.name = "Image"
        return imageNode
    }
    
    /// Make the picture's glass. This is a transparent plane; its only function is to be
    /// found by `hitTest`.
    func makeGlass(_ size: CGSize) -> SCNPlane
    {
        let plane = SCNPlane(width: size.width, height: size.height)
        let planeMaterial = SCNMaterial()
        planeMaterial.transparency = 0.0
        plane.materials = [planeMaterial]
        return plane
    }
    
    /// Make the entire picture from frame, matt, image, and glass.
    func makePicture(thumbnail: NSImage, size _size: CGSize)->SCNNode
    {
        let front: CGFloat = 0.9 * (1.0 / 12.0)
        var size = _size == CGSize.zero ? defaultFrameSize : _size
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
    
    func makePicture(_ path: String, size _size: CGSize = CGSize.zero) -> SCNNode? {
        guard let image = NSImage(byReferencingFile: path) else {
            return nil
        }
        let size = image.size
        let scale:CGFloat = 512.0 / max(size.width, size.height)
        var width = round(size.width * scale)
        if isPrime(Int(width)) {
            width += 1
        }
        var height = round(size.height * scale)
        if isPrime(Int(height)) {
            height += 1
        }
        let thumbnail = NSImage(size: CGSize(width: width, height: height))
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: CGPoint.zero, size: thumbnail.size),
            from: NSRect(origin: CGPoint.zero, size: image.size),
            operation: NSCompositingOperation.copy, fraction: 1.0)
        thumbnail.unlockFocus()
        thumbnail.size = image.size
        thumbnail.size.width /= (12 * 72)
        thumbnail.size.height /= (12 * 72)
        
        let picture = makePicture(thumbnail: thumbnail, size: defaultFrameSize)
        picture.geometry!.name = path
        return picture
    }

    /// Reframe a picture to a new size. The size cannot be smaller than the image.
    func reframePictureWithSize(_ picture: SCNNode, newsize: CGSize)
    {
        let image = picture.childNode(withName: "Image", recursively: true)!
        let oldPlane = image.geometry as! SCNPlane
        var size = newsize
        if size.width < oldPlane.width {
            size.width =  oldPlane.width
        }
        if size.height < oldPlane.height {
            size.height = oldPlane.height
        }
        size = snapToGrid(size)
        let oldMatt = picture.childNode(withName: "Matt", recursively: true)
        if let geometry = oldMatt?.geometry as? SCNPlane {
            geometry.width = size.width - 0.02
            geometry.height = size.height - 0.02
        }
        let oldFrame = picture.childNode(withName: "Frame", recursively: true)
        let frameIsHidden = oldFrame!.isHidden
        picture.replaceChildNode(oldFrame!, with: makeFrame(size))
        if frameIsHidden {
            _hideFrame(picture)
        }
        let glass = makeGlass(size)
        glass.name = picture.geometry?.name
        picture.geometry = glass
    }
    
    /// Resize an image and its frame
    func reframeImageWithSize(_ picture: SCNNode, newsize: CGSize)
    {
        let image = picture.childNode(withName: "Image", recursively: true)!
        let oldSize = image.size()!
        let scale = CGSize(width: newsize.width / oldSize.width,
                           height: newsize.height / oldSize.height)
        let newImage: NSImage
        let data1 = image.geometry!.materials[0].diffuse.contents! as? NSImage
        if data1 != nil {
            newImage = data1!
        } else {
            let data2 = image.geometry!.materials[0].diffuse.contents! as! Data
            newImage = NSImage(data: data2)!
        }
        newImage.size = newsize
        let isHidden = picture.childNode(withName: "Frame", recursively: false)!.isHidden
        let oldName = picture.geometry!.name!
        let oldPictureSize = picture.size()!
        let newPictureSize = CGSize(width: oldPictureSize.width * scale.width,
                                    height: oldPictureSize.height * scale.height)
        for child in picture.childNodes {
            child.removeFromParentNode()
        }
        let newPicture = makePicture(thumbnail: newImage, size: newPictureSize)
        newPicture.geometry!.name = oldName
        if isHidden {
            _hideFrame(newPicture)
        }
        for child in newPicture.childNodes {
            picture.addChildNode(child)
        }
        picture.geometry = newPicture.geometry
    }
    
}
