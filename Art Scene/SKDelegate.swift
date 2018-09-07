//
//  SKDelegate.swift
//  Art Scene
//
//  Created by Timothy Larkin on 9/6/18.
//  Copyright © 2018 Timothy Larkin. All rights reserved.
//

import SpriteKit

let standardFontSize: CGFloat = 24.0
let fontSize: CGFloat = 18.0
let fontScaler: CGFloat = fontSize / standardFontSize

extension ArtSceneViewController: SKSceneDelegate
{
    func makeCameraHelp()->SKNode
    {
        let items: [(String, String)] = [
            ("↑", "forward"),
            ("↓", "backwards"),
            ("←", "left"),
            ("→", "right"),
            ("⌥↑", "tilt up"),
            ("⌥↓", "tilt down"),
            ("⌥←", "rotate left"),
            ("⌥→", "rotate right"),
            ("⌃⌥←", "↰"),
            ("⌃⌥→", "↱"),
            ("c", "hide/show HUD"),
            ("h", "hide/show help")
        ]
        let help = makeDisplay(title: "Camera Help", items: items, fontSize: 16)
        help.name = "Help"
        return help
    }
    
    func updateCameraStatus() {
        if (cameraHidden) { return }
        let camera = artSceneView.camera()
        let x = convertToFeetAndInches(camera.position.x)
        let y = convertToFeetAndInches(camera.position.y)
        let z = convertToFeetAndInches(camera.position.z)
        let rotY = (camera.eulerAngles.y * r2d).truncatingRemainder(dividingBy: 360.0)
        let rot1 = String(format: "%.0f°", rotY < 0 ? rotY + 360 : rotY)
        let rotX = (camera.eulerAngles.x * r2d).truncatingRemainder(dividingBy: 360.0)
        let rot2 = String(format: "%.0f°", rotX < 0 ? rotX + 360 : rotX)
        let fov: Int
        if #available(OSX 10.13, *) {
            fov = Int(camera.camera!.fieldOfView)
        } else {
            fov = Int(camera.camera!.xFov)
        }
        
        let hudDictionary: [(String, String)] = [("x", x), ("y", y), ("z", z), ("y°", rot1), ("x°", rot2), ("fov", String(format: "%2d", fov))]
        hudUpdate = makeDisplay(title: "Camera", items: hudDictionary, width: fontScaler * 175)
        hudUpdate!.run(SKAction.sequence([SKAction.wait(forDuration: 2.0), SKAction.fadeOut(withDuration: 1.0)]))
    }
    
    func makeDisplay(title aTitle: String,
                     items: [(String, String)],
                     fontSize: CGFloat = 18,
                     width: CGFloat? = nil)->SKNode
    {
        
        func makeTextNode(text: String,
                          position: CGPoint,
                          fontSize: CGFloat,
                          alignment: SKLabelHorizontalAlignmentMode)->SKLabelNode
        {
            let node = SKLabelNode(text: text)
            node.fontName = "LucidaGrande"
            node.fontSize = fontSize
            node.fontColor = NSColor.white
            node.position = position
            node.horizontalAlignmentMode = alignment
            return node
        }
        
        var maxLabelSize: CGFloat = 0.0
        var rowDataSizes: Dictionary<String, CGFloat> = [:]
        let font = NSFont(name: "LucidaGrande", size: fontSize)!
        let lineHeight: CGFloat = ceil(font.ascender - font.descender) + 2
        let attributes: [NSAttributedStringKey: AnyObject] = [.font: font]
        for(key, value) in items {
            let keysize = (key as NSString).size(withAttributes: attributes)
            let ksize: CGFloat = keysize.width
            maxLabelSize = max(ksize, maxLabelSize)
            let vsize: CGFloat = (value as NSString).size(withAttributes: attributes).width
            rowDataSizes[value] = vsize
        }
        let maxDataSize: CGFloat = rowDataSizes.values.reduce(0.0, { max($0, $1) })
        let colsep: CGFloat = 20
        let margin: CGFloat = 10
        let flexibleWidth = maxDataSize + maxLabelSize + colsep + margin * 2.0
        var title = aTitle
        let titleWidth = width != nil ? width! - 2 * margin : flexibleWidth
        title = title.truncate(maxWidth: titleWidth, attributes: attributes)
        let displayWidth = width ?? flexibleWidth
        let displaySize = CGSize(width: displayWidth, height: lineHeight * (CGFloat(items.count + 2)))
        let displayRect = CGRect(origin: CGPoint.zero, size: displaySize)
        let path = CGPath(roundedRect: displayRect, cornerWidth: 10, cornerHeight: 10, transform: nil)
        let display = SKShapeNode(path: path, centered: true)
        display.fillColor = NSColor.gray
        let color = NSColor(calibratedWhite: 0.05, alpha: 0.98)
        display.fillColor = color
        let size = artSceneView.frame.size
        display.position = CGPoint(x: size.width / 3.0 - displaySize.width / 2.0, y: size.height / 2.0)
        display.name = "HUD Display"
        
        var y: CGFloat = CGFloat(items.count) * lineHeight / 2.0
        let titleNode = makeTextNode(text: title,
                                     position: CGPoint(x: 0.0, y: y),
                                     fontSize: fontSize, alignment: .center)
        titleNode.fontColor = NSColor.systemYellow
        display.addChild(titleNode)
        y -= lineHeight + 8.0
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
        return display
    }
    
    func update(_ currentTime: TimeInterval, for scene: SKScene)
    {
        if let update = hudUpdate {
            if let display = scene.childNode(withName: "HUD Display") {
                display.removeAllActions()
                display.removeFromParent()
            }
            scene.addChild(update)
        }
        hudUpdate = nil
        
        if wantsCameraHelp {
            if scene.childNode(withName: "Help") == nil {
                scene.addChild(cameraHelp)
            }
            let sceneSize = scene.size
            let helpSize = cameraHelp.frame.size
            cameraHelp.position.x = helpSize.width / 2.0 + 20
            cameraHelp.position.y = sceneSize.height - helpSize.height / 2.0 - 20
            cameraHelp.alpha = 1.0
        } else  {
            cameraHelp.alpha = 0.0
        }
    }
}
