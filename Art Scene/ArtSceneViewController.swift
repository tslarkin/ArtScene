//
//  GameViewController.swift
//  Art Scene
//
//  Created by Timothy Larkin on 10/8/15.
//  Copyright (c) 2015 Timothy Larkin. All rights reserved.
//

import SceneKit
import SpriteKit
import Quartz

/**
The view controller for an ArtSceneView. Handles moving, resizing, and rotating by
using the arrow keys.
*/
class ArtSceneViewController: NSViewController {
    
    @IBOutlet weak var artSceneView: ArtSceneView!
    @IBOutlet weak var document: Document!
    /// The documents undo manager
    var undoer:UndoManager {
        get { return document.undoManager! }
    }
    
     
}
