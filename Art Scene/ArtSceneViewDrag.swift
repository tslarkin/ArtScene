//
//  ArtSceneViewDrag.swift
//  Art Scene
//
//  Created by Timothy Larkin on 6/25/19.
//  Copyright © 2019 Timothy Larkin. All rights reserved.
//

import Cocoa
import SceneKit

extension ArtSceneView {
	// MARK: Interapplication dragging.
	
	override func wantsPeriodicDraggingUpdates() -> Bool {
		return true
	}
	
	override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
		let hits: [SCNHitTestResult]
		if #available(OSX 10.13, *) {
			hits = hitTest(sender.draggingLocation, options: [SCNHitTestOption.searchMode:  NSNumber(value: SCNHitTestSearchMode.all.rawValue)])
		} else {
			hits = hitTest(sender.draggingLocation, options: nil)
		}
		
		deltaSum = CGPoint.zero
		if hitOfType(hits, type: .Wall) == nil {
			return NSDragOperation()
		} else {
			return NSDragOperation.copy
		}
//		let target = wallHit.localCoordinates
//		let plane = wallHit.node.geometry as! SCNPlane
//		let (x1, y1) = snapToGrid(d1: target.x + plane.width / 2, d2: target.y + plane.height / 2, snap: gridFactor)
//		let x = convertToFeetAndInches(x1)
//		let y = convertToFeetAndInches(y1)
	}
	
	override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
		if NSImage.canInit(with: sender.draggingPasteboard) {
			return NSDragOperation.copy
		} else {
			return NSDragOperation()
		}
	}
	
	override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
		return NSImage.canInit(with: sender.draggingPasteboard)
	}
	
	override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
		var result = false
		let pasteboard = sender.draggingPasteboard
		if let plist = pasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray
		{
			let path = plist[0] as! String
			var point = sender.draggingLocation
			point = convert(point, from: nil)
			let hitResults: [SCNHitTestResult]
			if #available(OSX 10.13, *) {
				hitResults = hitTest(point, options: [SCNHitTestOption.searchMode:  NSNumber(value: SCNHitTestSearchMode.all.rawValue)])
			} else {
				hitResults = hitTest(point, options: nil)
			}
			if hitResults.count > 0 {
				if let pictureHit = hitOfType(hitResults, type: .Picture) {
					result = true
					replacePicture(pictureHit.node, path: path)
				} else if let wallHit = hitOfType(hitResults, type: .Wall) {
					result = true
					deltaSum = CGPoint.zero
					var coordinates = wallHit.localCoordinates
					let (x, y) = snapToGrid(d1: coordinates.x, d2: coordinates.y, snap: gridFactor)
					coordinates.x = x
					coordinates.y = y
					addPicture(wallHit.node, path: path, point: coordinates)
				}
				
			}
		}
		
		return result
	}
}
