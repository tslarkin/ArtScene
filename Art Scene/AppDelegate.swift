//
//  AppDelegate.swift
//  Art Scene
//
//  Created by Timothy Larkin on 10/16/15.
//  Copyright © 2015 Timothy Larkin. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var lightsPanel: NSPanel?
    var application: NSApplication!
    @objc dynamic var ambientLightIntensity: CGFloat = 0.0
    
    @objc dynamic var omniLightIntensity: CGFloat = 0.0
    
    func setOmniLightIntensity(_ intensity: CGFloat)
    {
        omniLightIntensity = intensity
    }
    
    func setAmbientLightIntensity(_ intensity: CGFloat)
    {
        ambientLightIntensity = intensity
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        application = aNotification.object as? NSApplication
        
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    @IBAction func showLightsPanel(_ sender: AnyObject?)
    {
        if lightsPanel == nil {
            var topLevelObjects: NSArray?
            
            Bundle.main.loadNibNamed(NSNib.Name(rawValue: "Lights"), owner: self, topLevelObjects: &topLevelObjects)
            lightsPanel = topLevelObjects!.filter({ $0 is NSPanel })[0] as? NSPanel
        }
        lightsPanel?.setIsVisible(true)
        (application.mainWindow?.delegate as! Document).windowDidBecomeMain()
    }
    
}

