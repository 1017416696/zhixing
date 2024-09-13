//
//  AddNoteView.swift
//  zhixing
//
//  Created by 曹骁凡 on 2024/9/8.
//

import SwiftUI
import CoreLocation
import Photos

struct AddNoteView: View {
    @Binding var notes: [Note]
    @State private var content = ""
    @State private var image: UIImage?
    @State private var showingImagePicker = false
    @State private var showingFullScreenImage = false
    @State private var location: CLLocationCoordinate2D?
    @State private var locationName: String = ""
    @State private var isCopying = false
    @State private var showingLocationInput = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("图片")) {
                    ZStack {
                        if let image = image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                                .cornerRadius(10)
                                .onTapGesture {
                                    showingFullScreenImage = true
                                }
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 200)
                            
                            VStack {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text("选择图片")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .onTapGesture {
                        if image == nil {
                            showingImagePicker = true
                        }
                    }
                    
                    if image != nil {
                        Button("更换图片") {
                            showingImagePicker = true
                        }
                    }
                }
                
                if image != nil {
                    Section(header: Text("图片位置")) {
                        if let location = location {
                            if !locationName.isEmpty {
                                Text(locationName)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.5)
                                    .contextMenu {
                                        Button(action: {
                                            UIPasteboard.general.string = locationName
                                            isCopying = true
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                                isCopying = false
                                            }
                                        }) {
                                            Label("复制地址", systemImage: "doc.on.doc")
                                        }
                                    }
                                    .overlay(
                                        Group {
                                            if isCopying {
                                                Text("已复制")
                                                    .padding(6)
                                                    .background(Color.black.opacity(0.7))
                                                    .foregroundColor(.white)
                                                    .cornerRadius(8)
                                            }
                                        }
                                    )
                            }
                            
                            HStack {
                                Text("经度: \(location.longitude, specifier: "%.6f")")
                                Spacer()
                                Text("纬度: \(location.latitude, specifier: "%.6f")")
                            }
                            .font(.caption)
                            .foregroundColor(.gray)
                        }
                        Button(location == nil ? "添加图片位置" : "更改图片位置") {
                            showingLocationInput = true
                        }
                    }
                }
                
                Section(header: Text("内容")) {
                    TextEditor(text: $content)
                        .frame(height: 200)
                }
            }
            .navigationTitle("添加新笔记")
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("保存") {
                    saveNote()
                }
                .disabled(image == nil || content.isEmpty)
            )
        }
        .sheet(isPresented: $showingImagePicker) {
            CustomImagePicker(image: $image, location: $location, locationName: $locationName)
        }
        .fullScreenCover(isPresented: $showingFullScreenImage) {
            if let image = image {
                FullScreenImageView(image: image, isPresented: $showingFullScreenImage)
            }
        }
        .sheet(isPresented: $showingLocationInput) {
            LocationInputView(locationName: $locationName, location: $location)
        }
    }
    
    private func saveNote() {
        let newNote = Note(content: content, image: image!, date: Date(), location: location)
        notes.append(newNote)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func getImageLocation() {
        // 实现获取图片位置的逻辑
    }
}

struct FullScreenImageView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    @State private var offset = CGSize.zero
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .edgesIgnoringSafeArea(.all)
                .offset(y: offset.height)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            self.offset = gesture.translation
                        }
                        .onEnded { _ in
                            if self.offset.height > 100 {
                                self.isPresented = false
                            } else {
                                self.offset = .zero
                            }
                        }
                )
        }
        .animation(.spring())
        .overlay(
            Button(action: {
                isPresented = false
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .clipShape(Circle())
            }
            .padding(),
            alignment: .topTrailing
        )
    }
}

struct CustomImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var location: CLLocationCoordinate2D?
    @Binding var locationName: String
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CustomImagePicker
        let geocoder = CLGeocoder()
        
        init(_ parent: CustomImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
                
                if let asset = info[.phAsset] as? PHAsset {
                    extractLocationFromAsset(asset)
                } else if let imageURL = info[.imageURL] as? URL {
                    extractLocationFromImageURL(imageURL)
                }
            }
            picker.dismiss(animated: true)
        }
        
        func extractLocationFromAsset(_ asset: PHAsset) {
            asset.location.map { location in
                DispatchQueue.main.async {
                    self.parent.location = location.coordinate
                    self.reverseGeocode(location: location.coordinate)
                }
            }
        }
        
        func extractLocationFromImageURL(_ url: URL) {
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return }
            
            guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else { return }
            
            if let gpsInfo = imageProperties[kCGImagePropertyGPSDictionary as String] as? [String: Any],
               let latitude = gpsInfo[kCGImagePropertyGPSLatitude as String] as? Double,
               let longitude = gpsInfo[kCGImagePropertyGPSLongitude as String] as? Double {
                
                let latitudeRef = gpsInfo[kCGImagePropertyGPSLatitudeRef as String] as? String ?? "N"
                let longitudeRef = gpsInfo[kCGImagePropertyGPSLongitudeRef as String] as? String ?? "E"
                
                let finalLatitude = latitudeRef == "N" ? latitude : -latitude
                let finalLongitude = longitudeRef == "E" ? longitude : -longitude
                
                DispatchQueue.main.async {
                    self.parent.location = CLLocationCoordinate2D(latitude: finalLatitude, longitude: finalLongitude)
                    self.reverseGeocode(location: CLLocationCoordinate2D(latitude: finalLatitude, longitude: finalLongitude))
                }
            }
        }
        
        func reverseGeocode(location: CLLocationCoordinate2D) {
            let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
            geocoder.reverseGeocodeLocation(clLocation) { placemarks, error in
                if let error = error {
                    print("反向地理编码错误: \(error.localizedDescription)")
                    return
                }
                
                if let placemark = placemarks?.first {
                    let addressComponents = [
                        placemark.administrativeArea,  // 省
                        placemark.locality,            // 市
                        placemark.subLocality,         // 区
                        placemark.thoroughfare,        // 街道
                        placemark.subThoroughfare      // 门牌号
                    ]
                    
                    let name = addressComponents
                        .compactMap { $0 }
                        .joined(separator: "")
                    
                    DispatchQueue.main.async {
                        self.parent.locationName = name
                    }
                }
            }
        }
    }
}
