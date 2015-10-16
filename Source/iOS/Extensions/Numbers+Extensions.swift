//
//  Numbers+Extensions.swift
//  ChouTi
//
//  Created by Honghao Zhang on 2015-09-05.
//

import Foundation

public extension Bool {
	public static func random() -> Bool {
		return Int.random() % 2 == 0
	}
}

public extension Int {
	public static func random(lower: Int = 0, _ upper: Int = 100) -> Int {
		return lower + Int(arc4random_uniform(UInt32(upper - lower + 1)))
	}
}

public extension Double {
	public var dispatchTime: dispatch_time_t {
		get {
			return dispatch_time(DISPATCH_TIME_NOW,Int64(self * Double(NSEC_PER_SEC)))
		}
	}
	
	public static func random(lower: Double = 0, _ upper: Double = 100) -> Double {
		return (Double(arc4random()) / 0xFFFFFFFF) * (upper - lower) + lower
	}
}

public extension Float {
	public static func random(lower: Float = 0, _ upper: Float = 100) -> Float {
		return (Float(arc4random()) / 0xFFFFFFFF) * (upper - lower) + lower
	}
}

public extension CGFloat {
	/// Get a radian degree
	public var radianDegree: CGFloat {
		return CGFloat(M_PI / 180) * self
	}
	
	public static func random(lower: CGFloat = 0, _ upper: CGFloat = 1) -> CGFloat {
		return CGFloat(Float(arc4random()) / Float(UINT32_MAX)) * (upper - lower) + lower
	}
}
