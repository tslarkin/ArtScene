//
//  TruncatingString.swift
//  Art Scene
//
//  Created by Timothy Larkin on 9/4/18.
//  Copyright © 2018 Timothy Larkin. All rights reserved.
//

import Foundation

extension String
{
    func truncate(maxWidth: CGFloat, attributes: [NSAttributedStringKey: Any])->String
    {
        var s = self
        var width = (self as NSString).size(withAttributes: attributes).width
        let ellipses = width > maxWidth ? "…" : ""
        while width > maxWidth {
            s.removeLast()
            width = (s as NSString).size(withAttributes: attributes).width
        }
        if s.last == " " {
            s.removeLast()
        }
        return s + ellipses
    }
}
