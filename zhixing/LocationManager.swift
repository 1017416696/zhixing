//
//  LocationManager.swift
//  zhixing
//
//  Created by 曹骁凡 on 2024/9/7.
//

import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocationCoordinate2D?
    @Published var formattedAddress: String = "位置未知"
    private let locationManager = CLLocationManager()
    private var geocoder = CLGeocoder()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            self.location = location.coordinate
            reverseGeocode(location: location)
        }
    }
    
    private func reverseGeocode(location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
            guard let self = self else { return }
            if let placemark = placemarks?.first {
                self.formattedAddress = self.formatAddress(from: placemark)
            } else {
                self.formattedAddress = "位置未知"
            }
        }
    }
    
    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        if let administrativeArea = placemark.administrativeArea { components.append(administrativeArea) }
        if let locality = placemark.locality { components.append(locality) }
        if let subLocality = placemark.subLocality { components.append(subLocality) }
        if let name = placemark.name { components.append(name) }
        
        return components.joined(separator: "")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("获取位置失败: \(error.localizedDescription)")
    }
}
