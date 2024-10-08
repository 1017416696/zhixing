//
//  LocationManager.swift
//  zhixing
//
//  Created by 曹骁凡 on 2024/9/7.
//

import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocationCoordinate2D?
    @Published var formattedAddress: String = "位置未知"
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // 每10米更新一次
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            self.location = location.coordinate
            reverseGeocode(location: location)
        }
    }
    
    private func reverseGeocode(location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
            guard let self = self, let placemark = placemarks?.first else { return }
            self.formattedAddress = self.formatAddress(from: placemark)
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
