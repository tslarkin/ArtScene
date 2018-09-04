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
    let controller: ArtSceneViewController!
    
    init(size: CGSize, controller: ArtSceneViewController, items: [(String, String)]) {
        self.controller = controller
        super.init(size: size)
        scaleMode = .resizeFill
        
        
        var maxLabelSize: CGFloat = 0.0
        var rowDataSizes: Dictionary<String, CGFloat> = [:]
        let fontSize: CGFloat = 24
        let font = NSFont(name: "Lucida Grande", size: fontSize)
        let attributes: [NSAttributedStringKey: AnyObject] = [.font: font!]
        for(key, value) in items {
            let keysize = (key as NSString).size(withAttributes: attributes)
            let ksize: CGFloat = keysize.width
            maxLabelSize = max(ksize, maxLabelSize)
            let vsize: CGFloat = (value as NSString).size(withAttributes: attributes).width
            rowDataSizes[value] = vsize
        }
        
        let lineHeight: CGFloat = 29
        let margin: CGFloat = 10
        let displaySize = CGSize(width: 175.0, height: lineHeight * (CGFloat(items.count) + 1))
        let display = SKShapeNode(rectOf: displaySize)
        display.fillColor = NSColor.gray
        let color = NSColor(calibratedWhite: 0.05, alpha: 0.98)
        display.fillColor = color
        display.position = CGPoint(x: size.width / 3.0 - displaySize.width / 2.0, y: size.height / 2.0)
        self.addChild(display)

        var y: CGFloat = CGFloat(items.count - 1) * lineHeight / 2.0
        for (key, value) in items {
            let keyNode = SKLabelNode(text: key)
            keyNode.fontName = "Lucida Grande"
            keyNode.fontSize = fontSize
            keyNode.fontColor = NSColor.white
            keyNode.position = CGPoint(x: -displaySize.width / 2.0 + margin, y: y)
            keyNode.horizontalAlignmentMode = .left
            display.addChild(keyNode)
            let dataNode = SKLabelNode(text: value)
            dataNode.fontName = "Lucida Grande"
            dataNode.fontSize = fontSize
            dataNode.fontColor = NSColor.white
            dataNode.position = CGPoint(x: displaySize.width / 2.0 - margin, y: y)
            dataNode.horizontalAlignmentMode = .right
            display.addChild(dataNode)
            y -= lineHeight
        }
        display.run(SKAction.sequence([SKAction.wait(forDuration: 2.0), SKAction.fadeOut(withDuration: 1.0)]))
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
