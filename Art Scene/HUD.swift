//
//  HUD.swift
//  Art Scene
//
//  Created by Timothy Larkin on 9/4/18.
//  Copyright © 2018 Timothy Larkin. All rights reserved.
//

import SpriteKit

class HUD: SKScene
{
    open var labelNode: SKLabelNode?
    open var display: SKShapeNode?
    let controller: ArtSceneViewController
    
    init(size: CGSize, controller: ArtSceneViewController) {
        self.controller = controller
        super.init(size: size)
        self.delegate = controller
        scaleMode = .resizeFill
    }
    
    override func keyDown(with event: NSEvent) {
        controller.keyDown(with: event)
    }
    
    override func flagsChanged(with event: NSEvent) {
        controller.artSceneView.flagsChanged(with: event)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
