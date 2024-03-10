//
//  Array+Distance.swift
//
//
//  Created by Alexey Ivanov on 10/3/24.
//

import Foundation

extension Array where Element == Float {
    func isNear(to other: [Float], distance: Float = 0.001) -> Bool {
        enumerated()
            .map { (index, element) in
                abs(element.distance(to: other[index])) < distance
            }
            .allSatisfy({$0 == true})
    }
}
