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

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

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

enum CustomMapStyle: Int, Hashable {
    case standard
    case satellite
    case hybrid
    
    var mapStyle: MapStyle {
        switch self {
        case .standard:
            return .standard
        case .satellite:
            return .imagery
        case .hybrid:
            return .hybrid
        }
    }
    
    var name: String {
        switch self {
        case .standard:
            return "标准"
        case .satellite:
            return "卫星"
        case .hybrid:
            return "混合"
        }
    }
}

struct NoteMapView: View {
    let notes: [Note]
    @StateObject private var locationManager = LocationManager()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 23.1291, longitude: 113.2644), // 广州市中心坐标
        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005) // 调整这个值以获得合适的缩放级别
    )
    @State private var selectedMapStyle: CustomMapStyle = .standard
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var isLocating: Bool = false
    @State private var showCompass: Bool = false
    @State private var mapRotation: Double = 0 // 新增：跟踪地图旋转角度

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MapViewRepresentable(region: $region, 
                                 mapType: $selectedMapStyle, 
                                 annotations: annotationItems, 
                                 showCompass: $showCompass, // 添加 showCompass 参数
                                 mapRotation: $mapRotation,
                                 userLocation: locationManager.location, // 添加 userLocation 参数
                                 isLocating: $isLocating) // 添加 isLocating 参数
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                ForEach([CustomMapStyle.standard, .satellite, .hybrid], id: \.self) { style in
                    Button(action: {
                        selectedMapStyle = style
                    }) {
                        Text(style.name)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .frame(width: 60)
                            .background(selectedMapStyle == style ? Color.blue : Color.gray.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                
                Button(action: {
                    centerOnUserLocation()
                    isLocating = true
                }) {
                    Image(systemName: "location.fill")
                        .foregroundColor(.white)
                        .frame(width: 60, height: 30)
                        .background(isLocating ? Color.blue : Color.gray.opacity(0.7))
                        .cornerRadius(8)
                }
                
                if showCompass {
                    CompassView(rotation: mapRotation)
                        .frame(width: 40, height: 40)
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.6))
            .cornerRadius(12)
            .padding([.top, .trailing], 16)
        }
        .onAppear {
            locationManager.startUpdatingLocation()
        }
        .onChange(of: locationManager.location) { newLocation in
            if let location = newLocation {
                region.center = location
            }
        }
    }
    
    private var annotationItems: [AnnotationItem] {
        var items = notes.map { AnnotationItem(coordinate: $0.location ?? CLLocationCoordinate2D(latitude: 0, longitude: 0), note: $0, isUserLocation: false) }
        if let userLocation = userLocation {
            items.append(AnnotationItem(coordinate: userLocation, note: Note(content: "当前位置", image: UIImage(systemName: "scope") ?? UIImage(), date: Date(), location: userLocation), isUserLocation: true))
        }
        return items
    }
    
    private func centerOnUserLocation() {
        if let location = locationManager.location {
            region = MKCoordinateRegion(
                center: location,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01) // 调整这个值以获得合适的缩放级别
            )
            userLocation = location
            isLocating = true
        }
    }
}

struct MapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var mapType: CustomMapStyle
    let annotations: [AnnotationItem]
    @Binding var showCompass: Bool // 添加 showCompass 绑定
    @Binding var mapRotation: Double
    let userLocation: CLLocationCoordinate2D?
    @Binding var isLocating: Bool // 添加 isLocating 绑定

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsCompass = true
        mapView.showsBuildings = true
        mapView.showsTraffic = true
        mapView.isRotateEnabled = true
        mapView.isZoomEnabled = true
        mapView.isPitchEnabled = true
        mapView.isScrollEnabled = true
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 更新地图类型
        uiView.mapType = mapType.mapType
        
        // 更新注释
        uiView.removeAnnotations(uiView.annotations)
        let mkAnnotations = annotations.map { item -> MKPointAnnotation in
            let annotation = MKPointAnnotation()
            annotation.coordinate = item.coordinate
            annotation.title = item.isUserLocation ? "当前位置" : nil
            return annotation
        }
        uiView.addAnnotations(mkAnnotations)
        
        // 只在 isLocating 为 true 时更新地图中心
        if isLocating {
            uiView.setRegion(region, animated: true)
            isLocating = false
        }
        
        // 更新地图旋转角度
        mapRotation = uiView.camera.heading
        
        // 确保地图交互性始终启用
        uiView.isRotateEnabled = true
        uiView.isZoomEnabled = true
        uiView.isPitchEnabled = true
        uiView.isScrollEnabled = true
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation.title == "当前位置" {
                let view = MKAnnotationView(annotation: annotation, reuseIdentifier: "userLocation")
                
                // 创建一个更美观的定位标识
                let size: CGFloat = 30
                UIGraphicsBeginImageContextWithOptions(CGSize(width: size, height: size), false, 0)
                let context = UIGraphicsGetCurrentContext()!
                
                // 绘制外圈
                context.setFillColor(UIColor.white.cgColor)
                context.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
                
                // 绘制内圈，使用更柔和的蓝色
                context.setFillColor(UIColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1.0).cgColor) // 柔和蓝色
                context.fillEllipse(in: CGRect(x: 4, y: 4, width: size - 8, height: size - 8))
                
                // 制中心点
                context.setFillColor(UIColor.white.cgColor)
                context.fillEllipse(in: CGRect(x: size/2 - 2, y: size/2 - 2, width: 4, height: 4))
                
                let image = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                view.image = image
                view.frame = CGRect(x: 0, y: 0, width: size, height: size)
                view.centerOffset = CGPoint(x: 0, y: -size / 2)
                return view
            }
            return nil
        }

        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            parent.region = mapView.region
            parent.showCompass = mapView.camera.heading != 0
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
            parent.showCompass = mapView.camera.heading != 0
            parent.mapRotation = mapView.camera.heading
        }
    }
}

extension CustomMapStyle {
    var mapType: MKMapType {
        switch self {
        case .standard:
            return .standard
        case .satellite:
            return .satellite
        case .hybrid:
            return .hybrid
        }
    }
}

struct AnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let note: Note
    let isUserLocation: Bool
}

struct CompassView: View {
    let rotation: Double
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.8))
                .frame(width: 40, height: 40)
            
            Image(systemName: "location.north.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundColor(.red)
                .rotationEffect(.degrees(-rotation))
        }
    }
}


