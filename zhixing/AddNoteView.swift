//
//  AddNoteView.swift
//  zhixing
//
//  Created by 曹骁凡 on 2024/9/8.
//

import SwiftUI
import CoreLocation

struct AddNoteView: View {
    @Binding var notes: [Note]
    @State private var content = ""
    @State private var image: UIImage?
    @State private var showingImagePicker = false
    @State private var showingFullScreenImage = false
    @State private var location: CLLocationCoordinate2D?
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
                                Text("点击选择图片")
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
                            HStack {
                                Text("纬度: \(location.latitude, specifier: "%.4f")")
                                Spacer()
                                Text("经度: \(location.longitude, specifier: "%.4f")")
                            }
                            .font(.caption)
                            .foregroundColor(.gray)
                        }
                        Button(location == nil ? "添加图片位置" : "更改图片位置") {
                            getImageLocation()
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
            CustomImagePicker(image: $image, location: $location)
        }
        .fullScreenCover(isPresented: $showingFullScreenImage) {
            if let image = image {
                FullScreenImageView(image: image, isPresented: $showingFullScreenImage)
            }
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

// CustomImagePicker 需要更新以支持返回位置信息
struct CustomImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var location: CLLocationCoordinate2D?
    
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
        
        init(_ parent: CustomImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
                // 这里应该尝试从图片中提取位置信息
                if let location = extractLocationFromImage(image) {
                    parent.location = location
                }
            }
            picker.dismiss(animated: true)
        }
        
        func extractLocationFromImage(_ image: UIImage) -> CLLocationCoordinate2D? {
            // 这里应该实现从图片EXIF数据中提取位置信息的逻辑
            // 返回 CLLocationCoordinate2D 或 nil
            return nil
        }
    }
}
