//
//  SCNVector Extensions.swift
//  Art Scene
//
//  Created by Timothy Larkin on 11/15/15.
//  Copyright © 2015 Timothy Larkin. All rights reserved.
//

import SceneKit

func + (u: SCNVector3, v: SCNVector3) -> SCNVector3 {
    return SCNVector3(x: u.x + v.x, y: u.y + v.y, z: u.z + v.z)
}

func - (u: SCNVector3, v: SCNVector3) -> SCNVector3 {
    return SCNVector3(x: u.x - v.x, y: u.y - v.y, z: u.z - v.z)
}

func == (u: SCNVector3, v: SCNVector3) -> Bool {
    return u.x == v.x && u.y == v.y && u.z == v.z
}

func != (u: SCNVector3, v: SCNVector3) -> Bool {
    return !(u == v)
}

infix operator × : MultiplicationPrecedence

func × (a: SCNVector3, b: SCNVector3) -> SCNVector3
{
    return SCNVector3(x: a.y * b.z - a.z * b.y, y: a.z * b.x - a.x * b.z, z: a.x * b.y - a.y * b.x)    
}

precedencegroup DotProductPrecedence {
    lowerThan: AdditionPrecedence
    associativity: left
}

infix operator •: DotProductPrecedence
func • (a: SCNVector3, b: SCNVector3)->CGFloat
{
    return a.x * b.x + a.y * b.y + a.z * b.z
}

func *(a: CGFloat, b: SCNVector3)->SCNVector3
{
    return SCNVector3Make(a * b.x, a * b.y, a * b.z)
}

// https://stackoverflow.com/questions/45966373/rotate-scnvector3-around-an-axis
// Rodrigues' rotation formula.
func rotate(vector v: SCNVector3, axis k: SCNVector3, angle theta: CGFloat)->SCNVector3
{
    let vr1 = (cos(theta) * v)
    let vr2 = (sin(theta) * (k × v))
    let vr3 = (1 - cos(theta)) * ((k • v) * k )
    return vr1 + vr2 + vr3
}

// CGFloat Math
infix operator ^: BitwiseShiftPrecedence
func ^(a: CGFloat, b: CGFloat)->CGFloat {
    return pow(a, b)
}

// CGSize Math

func +(a: CGSize, b: CGSize)->CGSize
{
    return CGSize(width: a.width + b.width, height: a.height + b.height)
}

func -(a: CGSize, b: CGSize)->CGSize
{
    return CGSize(width: a.width - b.width, height: a.height - b.height)
}

// CGPoint Math

func +(a: CGPoint, b: CGPoint)->CGPoint
{
    return CGPoint(x: a.x + b.x, y: a.y + b.y)
}

func -(a: CGPoint, b: CGPoint)->CGPoint
{
    return CGPoint(x: a.x - b.x, y: a.y - b.y)
}

func ×(a: CGPoint, b: CGPoint)->CGFloat
{
    return a.x * b.y - a.y * b.x
}

func *(a: CGFloat, b: CGPoint)->CGPoint
{
    return CGPoint(x: a * b.x, y: a * b.y)
}
