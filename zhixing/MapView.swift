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
    let id = UUID()
    var coordinate: CLLocationCoordinate2D
    var notes: [Note]
    var count: Int
    
    var thumbnailImage: UIImage? {
        notes.first?.image
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
        center: CLLocationCoordinate2D(latitude: 23.1291, longitude: 113.2644),
        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
    )
    @State private var selectedMapStyle: CustomMapStyle = .standard
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var isLocating: Bool = false
    @State private var showCompass: Bool = false
    @State private var mapRotation: Double = 0
    @State private var selectedNote: Note? // 新增：跟踪选中的笔记
    @State private var showingNoteDetail = false // 新增：控制是否显示笔记详情

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MapViewRepresentable(region: $region, 
                                 mapType: $selectedMapStyle, 
                                 annotations: annotationItems, 
                                 showCompass: $showCompass,
                                 mapRotation: $mapRotation,
                                 userLocation: locationManager.location,
                                 isLocating: $isLocating,
                                 onAnnotationTapped: { note in // 新增：处理标注点击
                                     selectedNote = note
                                     showingNoteDetail = true
                                 })
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
        .sheet(isPresented: $showingNoteDetail) { // 新增：显示笔记详情的 sheet
            if let note = selectedNote {
                NoteDetailView(note: note)
            }
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
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
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
    @Binding var showCompass: Bool
    @Binding var mapRotation: Double
    let userLocation: CLLocationCoordinate2D?
    @Binding var isLocating: Bool
    var onAnnotationTapped: (Note) -> Void // 新增：回调函数

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
                // 保留现有的用户位置标识代码
                // ... 现有代码 ...
            } else {
                let identifier = "noteAnnotation"
                var view: MKAnnotationView
                
                if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) {
                    view = dequeuedView
                } else {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                }
                
                if let annotationCoordinate = annotation.coordinate as? CLLocationCoordinate2D,
                   let matchingNote = parent.annotations.first(where: { $0.coordinate == annotationCoordinate })?.note {
                    
                    if let thumbnailImage = matchingNote.image {
                        let size: CGFloat = 40
                        let imageSize = thumbnailImage.size
                        let aspectRatio = imageSize.width / imageSize.height
                        
                        var newSize: CGSize
                        if aspectRatio > 1 {
                            newSize = CGSize(width: size, height: size / aspectRatio)
                        } else {
                            newSize = CGSize(width: size * aspectRatio, height: size)
                        }
                        
                        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
                        thumbnailImage.draw(in: CGRect(origin: .zero, size: newSize))
                        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
                        UIGraphicsEndImageContext()
                        
                        // 创建一个新的容器视图
                        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height + 10))
                        
                        // 添加图片视图
                        let imageView = UIImageView(image: resizedImage)
                        imageView.frame = CGRect(origin: .zero, size: newSize)
                        imageView.layer.cornerRadius = 4
                        imageView.layer.masksToBounds = true
                        imageView.layer.borderWidth = 2
                        imageView.layer.borderColor = UIColor.white.cgColor
                        containerView.addSubview(imageView)
                        
                        // 添加三角形
                        let triangleView = TriangleView(frame: CGRect(x: (newSize.width - 10) / 2, y: newSize.height, width: 10, height: 10))
                        triangleView.backgroundColor = .clear
                        containerView.addSubview(triangleView)
                        
                        view.addSubview(containerView)
                        view.frame = containerView.frame
                    }
                }
                
                view.backgroundColor = .clear
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

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let annotation = view.annotation,
               let coordinate = annotation.coordinate as? CLLocationCoordinate2D,
               let matchingNote = parent.annotations.first(where: { $0.coordinate == coordinate })?.note {
                parent.onAnnotationTapped(matchingNote)
            }
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

// 添加一个新的 TriangleView 类
class TriangleView: UIView {
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        context.beginPath()
        context.move(to: CGPoint(x: rect.minX, y: rect.minY))
        context.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        context.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        context.closePath()
        
        UIColor.white.setFill()
        context.fillPath()
    }
}


