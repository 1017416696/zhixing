//
//  Note.swift
//  zhixing
//
//  Created by 曹骁凡 on 2024/9/8.
//

import SwiftUI
import CoreLocation

struct Note: Identifiable {
    let id = UUID()
    var content: String
    var image: UIImage
    var date: Date
    var location: CLLocationCoordinate2D?
    let locationName: String

    init(content: String, image: UIImage, date: Date, location: CLLocationCoordinate2D?, locationName: String = "") {
        self.content = content
        self.image = image
        self.date = date
        self.location = location
        self.locationName = locationName
    }
}
