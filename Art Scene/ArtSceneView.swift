//
//  GameView.swift
//  Art Scene
//
//  Created by Timothy Larkin on 10/8/15.
//  Copyright (c) 2015 Timothy Larkin. All rights reserved.
//

import SceneKit
import SpriteKit

/**
Hosts the Art Scene. It also handles mouse events (including keeping track of the selection),
and printing.
*/
class ArtSceneView: SCNView {
    
    override var frame: NSRect {
        didSet {
            frameSizeChanged = true
        }
    }

	/// The standard frame sizes.
	let frameSizes = ["16x16":  CGSize(width: 16, height: 16),
					  "16x20":  CGSize(width: 16, height: 20),
					  "20x16":  CGSize(width: 20, height: 16),
					  "20x20":  CGSize(width: 20, height: 20),
					  "20x24":  CGSize(width: 20, height: 24),
					  "24x20":  CGSize(width: 24, height: 20),
					  "24x24":  CGSize(width: 24, height: 24)]
	
	/// Set during `mouseMoved` based on which node the mouse is over, as determined by
	/// `hitTest`.
	var editMode = EditMode.none {
		willSet(newMode) {
			if case EditMode.none = newMode {
				if undoer.groupingLevel == 1 {
					undoer.endUndoGrouping()
				}
				if editMode == .moving(.Picture) {
					let wall = selectedNode!.parent!
					for node in wall.childNodes.filter({ nodeType($0) != .Back && nodeType($0) != .Grid  && $0.name != nil}) {
						unflattenPicture(node)
					}
				}
			}
		}
	}
	
	var defaultFrameSize: CGSize = CGSize(width: 2, height: 2)
	/// The target of key-based editing, either a picture or a wall.
	var defaultWallSize = CGSize(width: 20, height: 10)
	/// The user selected wall color, which is the same for all walls
	var wallColor: NSColor = NSColor.white {
		didSet {
			let walls = scene!.rootNode.childNodes(passingTest: { x, yes in x.name == "Wall" })
			for wall in walls {
				wall.geometry?.firstMaterial?.diffuse.contents = wallColor
			}
			
		}
	}
	
	var hudUpdate: SKNode?
	var cameraHidden: Bool = false
	var wantsCameraHelp: Bool = true
	var cameraHelp: SKNode!
	var frameSizeChanged: Bool = false
    /// A reference to its controller
//    @IBOutlet weak var controller: ArtSceneViewController!
    /// The alignment functions use a master node as a reference.
    weak var masterNode: SCNNode? = nil
    /// The node under the mouse, set during `mouseMoved`.
    weak var selectedNode: SCNNode? = nil
    
    /// The Art Scene document
    @IBOutlet weak var document: Document!
    /// The location of the last mouse click that generated a contextual menu.
    var mouseClickLocation: SCNVector3? = nil
    /// The documents undo manager
    var undoer:UndoManager {
        get { return document!.undoManager! }
    }
    
    /// The Heads Up Display hosted in an SKScene
    var hud: HUD!
    
    /// The set of selected pictures. The first picture selected is always the `masterNode`.
    var selection: Array<SCNNode>  = []
    
    /// Accumulate deltas here.
    var deltaSum: CGPoint!
	var wallsLocked = false
	
//	var scene:SCNScene {
//		return scene!
//	}
	
    /// Indicates whether the user is currently in a drag operation.
    var inDrag = false
    
    /// The cursor for Get Info.
    let questionCursor: NSCursor
    /// The cursor that appears when the mouse is over the bottom of a wall.
    let rotateCursor: NSCursor
    /// The resize uniformly cursor.
    let resizeCursor: NSCursor
    /// The chair curson
    let chairCursor: NSCursor
    var currentCursor: NSCursor?
    /// Returns the ambient light node
    @objc var ambientLight: SCNNode {
        get {
           return scene!.rootNode.childNode(withName: "Ambient", recursively: false)!
        }
    }
            
    /// Returns the omni light node
    @objc var omniLight: SCNNode {
        get {
            return scene!.rootNode.childNode(withName: "Omni", recursively: false)!
        }
    }
    
    @objc var ambientLightIntensity: CGFloat {
        set {
            ambientLight.light?.color = NSColor(white: newValue, alpha: 1.0)
        }
        get {
            var color = (ambientLight.light?.color as! NSColor)
            if #available(OSX 10.14, *) {
                color = color.usingColorSpaceName(NSColorSpaceName.calibratedWhite)!
            }
            return color.whiteComponent
        }
    }
    
    @objc var omniLightIntensity: CGFloat {
        set {
            omniLight.light?.color = NSColor(white: newValue, alpha: 1.0)
        }
        get {
            var color = (omniLight.light?.color as! NSColor)
            if #available(OSX 10.14, *) {
                color = color.usingColorSpaceName(NSColorSpaceName.calibratedWhite)!
            }
            return color.whiteComponent
        }
    }
    
    @objc var spotlightIntensity: CGFloat = -1.0 {
        didSet {
            scene?.rootNode.enumerateChildNodes({ (node: SCNNode, stop) in
                if node.light != nil && node.light!.type == .spot {
                    node.light!.color = NSColor(white: spotlightIntensity, alpha: 1.0)
                }
                
            })
        }
    }
    
    /// Makes the `questionCursor` and `rotateCursor`, then calls `super.init()`
    required init?(coder: NSCoder) {
        var size: CGFloat = 24
        let font = NSFont.boldSystemFont(ofSize: size)
        let q = "?"
        let attributes: [NSAttributedString.Key: AnyObject] = [.font: font, .strokeColor: NSColor.white,
                                                              .foregroundColor: NSColor.black, .strokeWidth: NSNumber(value: -2)]
        let qSize = (q as NSString).size(withAttributes: attributes)
        var image: NSImage = NSImage(size: NSSize(width: qSize.width + 2, height: qSize.height + 2))
        image.lockFocus()
        q.draw(in: NSRect(x: 1, y: -7, width: qSize.width, height: qSize.height), withAttributes:attributes)
        image.unlockFocus()
        questionCursor = NSCursor.init(image: image, hotSpot: NSPoint(x: qSize.width / 2.0, y: qSize.height))
        
        size = 24
        let rotate = NSImage(named: (("rotate-icon.png" as NSString) as NSImage.Name))!
        image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        rotate.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        image.unlockFocus()
        rotateCursor = NSCursor.init(image: image, hotSpot: NSPoint(x: 12, y: 12))
        
        let resize = NSImage(named: (("4way-arrow.png" as NSString) as NSImage.Name))!
        image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        resize.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        image.unlockFocus()
        resizeCursor = NSCursor.init(image: image, hotSpot: NSPoint(x: 12, y: 12))
        
        let chair = NSImage(named: (("noun_Chair_138821.png" as NSString) as NSImage.Name))!
        image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        chair.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        image.unlockFocus()
        chairCursor = NSCursor.init(image: image, hotSpot: NSPoint(x: 12, y: 12))
        
        super.init(coder: coder)
    }
	
	override func awakeFromNib(){
		
		let defaults = UserDefaults.standard
		defaults.register(defaults: ["cameraHidden": false, "wantsCameraHelp": true])
		cameraHidden = defaults.bool(forKey: "cameraHidden")
		wantsCameraHelp = defaults.bool(forKey: "wantsCameraHelp")
		
		// create a new scene
		
		// allows the user to manipulate the camera
		allowsCameraControl = false
		
		// show statistics such as fps and timing information
		showsStatistics = false
		
		// configure the view
		backgroundColor = NSColor.black
		
		if let window = window {
			window.acceptsMouseMovedEvents = true;
			window.makeFirstResponder(self)
		}
		
		cameraHelp = makeCameraHelp()
		hud = HUD(size: frame.size, controller: self)
		overlaySKScene = hud
		registerForDraggedTypes([NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")])
		
		//        NotificationCenter.default.addObserver(self, selector: #selector(ArtSceneViewController.undoStarted(_:)), name: NSNotification.Name.NSUndoManagerDidOpenUndoGroup, object: nil)
	}
	

    
	/// Returns the single scene camera node.
	var camera: SCNNode {
		get {
			return scene!.rootNode.childNode(withName: "Camera", recursively: false)!
		}
	}
	
    /// Returns the grid
	var grid: SCNNode {
		get {
			return scene!.rootNode.childNode(withName: "Grid", recursively: false)!
		}
	}
	
    /// Returns the floor
	var floor: SCNNode {
		get {
			return scene!.rootNode.childNode(withName: "Floor", recursively: false)!
		}
	}
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(ArtSceneView.shadows(_:)) {
            if omniLight.light?.castsShadow == true {
                menuItem.title = "No Shadows"
            } else {
                menuItem.title = "Shadows"
            }
			return true
        }
		if menuItem.tag == 0 {
			return true
		} else if undoer.canUndo {
			menuItem.title = "Undo \(undoer.undoActionName)"
			return true
		} else {
			menuItem.title = "Undo"
			return false
		}
    }

}
