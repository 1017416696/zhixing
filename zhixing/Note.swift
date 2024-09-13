//
//  Note.swift
//  zhixing
//
//  Created by 曹骁凡 on 2024/9/8.
//

import SwiftUI
import CoreLocation

struct Note: Identifiable, Codable {
    let id: UUID
    var content: String
    var imageData: Data
    var date: Date
    var location: CLLocationCoordinate2D?
    var locationName: String  // 改为 var

    init(content: String, image: UIImage, date: Date, location: CLLocationCoordinate2D?, locationName: String = "") {
        self.id = UUID()
        self.content = content
        self.imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
        self.date = date
        self.location = location
        self.locationName = locationName
    }

    var image: UIImage? {  // 改为可选类型
        get {
            UIImage(data: imageData)
        }
        set {
            if let newImage = newValue {
                imageData = newImage.jpegData(compressionQuality: 0.8) ?? Data()
            }
        }
    }
}

extension CLLocationCoordinate2D: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(latitude)
        try container.encode(longitude)
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let latitude = try container.decode(Double.self)
        let longitude = try container.decode(Double.self)
        self.init(latitude: latitude, longitude: longitude)
    }
}
