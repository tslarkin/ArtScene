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
        scaleMode = .resizeFill
    }
    
    @discardableResult func addDisplay(title: String,
                                       items: [(String, String)],
                                       width: CGFloat? = nil)->SKNode
    {
        
        func makeTextNode(text: String,
                          position: CGPoint,
                          fontSize: CGFloat,
                          alignment: SKLabelHorizontalAlignmentMode)->SKLabelNode
        {
            let node = SKLabelNode(text: text)
            node.fontName = "Lucida Grande"
            node.fontSize = fontSize
            node.fontColor = NSColor.white
            node.position = position
            node.horizontalAlignmentMode = alignment
            return node
        }
        
        if let old = childNode(withName: "HUD Display") {
            old.removeFromParent()
        }
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
        let maxDataSize: CGFloat = rowDataSizes.values.reduce(0.0, { max($0, $1) })
        let colsep: CGFloat = 20
        let lineHeight: CGFloat = 29
        let margin: CGFloat = 10
        let titlesize: CGFloat = (title as NSString).size(withAttributes: attributes).width
        let flexibleWidth = max(titlesize + 2 * margin, maxDataSize + maxLabelSize + colsep + margin * 2.0)
        let displayWidth = width ?? flexibleWidth
        let displaySize = CGSize(width: displayWidth, height: lineHeight * (CGFloat(items.count + 2)))
        let display = SKShapeNode(rectOf: displaySize)
        display.fillColor = NSColor.gray
        let color = NSColor(calibratedWhite: 0.05, alpha: 0.98)
        display.fillColor = color
        display.position = CGPoint(x: size.width / 3.0 - displaySize.width / 2.0, y: size.height / 2.0)
        display.name = "HUD Display"
        self.addChild(display)
        
        var y: CGFloat = CGFloat(items.count) * lineHeight / 2.0
        let titleNode = makeTextNode(text: title,
                                     position: CGPoint(x: 0.0, y: y),
                                     fontSize: fontSize, alignment: .center)
        display.addChild(titleNode)
        y -= lineHeight
        for (key, value) in items {
            let keyNode = makeTextNode(text: key,
                                       position: CGPoint(x: -displaySize.width / 2.0 + margin, y: y),
                                       fontSize: fontSize, alignment: .left)
            display.addChild(keyNode)
            let dataNode = makeTextNode(text: value,
                                        position: CGPoint(x: displaySize.width / 2.0 - margin, y: y),
                                        fontSize: fontSize, alignment: .right)
            display.addChild(dataNode)
            y -= lineHeight
        }
        display.run(SKAction.fadeIn(withDuration: 1.0))
        return display
    }
    
    func updateDisplay(with: SKNode) {
        if let old = childNode(withName: "HUD Display") {
            old.removeFromParent()
        }
        addChild(with)
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
