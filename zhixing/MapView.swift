//
//  MapView.swift
//  zhixing
//
//  Created by 曹骁凡 on 2024/9/9.
//

import SwiftUI
import MapKit
import CoreLocation
import ImageIO

struct LocationKey: Hashable {
    let latitude: Double
    let longitude: Double
    
    init(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
}

struct NoteAnnotation: Identifiable {
    var coordinate: CLLocationCoordinate2D
    var note: Note
    var count: Int
    
    var id: String {
        "\(coordinate.latitude),\(coordinate.longitude)"
    }
}

struct NoteMapView: View {
    let notes: [Note]
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 23.1301, longitude: 113.2592),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: notes) { note in
            MapAnnotation(coordinate: note.location ?? CLLocationCoordinate2D(latitude: 23.1301, longitude: 113.2592)) {
                VStack {
                    Image(uiImage: note.image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .shadow(radius: 3)
                }
            }
        }
        .onAppear {
            if let firstNoteLocation = notes.first?.location {
                region.center = firstNoteLocation
            }
        }
    }
}


