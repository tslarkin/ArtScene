//
//  SCNRenderDelegate.swift
//  Art Scene
//
//  Created by Timothy Larkin on 9/20/18.
//  Copyright © 2018 Timothy Larkin. All rights reserved.
//

import SceneKit

// https://stackoverflow.com/questions/46843254/scenekit-physicsworld-setup-to-prevent-kinematic-nodes-to-intersect

extension ArtSceneView : SCNSceneRendererDelegate
{
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval)
    {
        let artView = renderer as! ArtSceneView
        
        guard let node = artView.mouseNode, let transform = artView.nodeTransform else { return }
        node.transform = transform
        // contactTest
        let pw = scene.physicsWorld
        var physicsBody: SCNPhysicsBody?
        switch nodeType(node)! {
        case .Chair, .Table:
            physicsBody = node.childNodes[0].physicsBody!
        case .Box:
            physicsBody = node.physicsBody!
        default:
            ()
        }
        if physicsBody != nil {
            let contacts = pw.contactTest(with: physicsBody!, options: nil)
            if contacts.count > 0 {
                let contact = contacts[0]
                let normal = contact.contactNormal
                let d = abs(contact.penetrationDistance)
                let transform = SCNMatrix4MakeTranslation( normal.x * d,
                                                           0.0,
                                                           normal.z * d)
                node.transform = SCNMatrix4Mult(node.transform, transform)
                Swift.print(contact.penetrationDistance, normal)
            }
        }
        artView.isPlaying = false
        artView.nodeTransform = nil

    }
}
