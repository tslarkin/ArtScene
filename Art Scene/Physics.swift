//
//  Physics.swift
//  Art Scene
//
//  Created by Timothy Larkin on 9/9/18.
//  Copyright © 2018 Timothy Larkin. All rights reserved.
//

import SceneKit

extension ArtSceneViewController: SCNPhysicsContactDelegate
{
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        NSSound.beep()
//        let boxNode = nodeType(contact.nodeA) == .Box ? contact.nodeA : contact.nodeB
//        let scale = contact.penetrationDistance
//        let normal = contact.contactNormal
//        var position = boxNode.position
//        position.x += normal.x * scale
//        position.y += normal.y * scale
//        position.z += normal.z * scale
//        boxNode.position = position
    }
}
