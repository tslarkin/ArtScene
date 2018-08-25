//
//  SceneRendererDelegate.swift
//  Art Scene
//
//  Created by Timothy Larkin on 8/25/18.
//  Copyright © 2018 Timothy Larkin. All rights reserved.
//

import SceneKit

class SceneRendererDelegate: NSObject, SCNSceneRendererDelegate
{
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        glLineWidth(20)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        glLineWidth(20)
    }
}
