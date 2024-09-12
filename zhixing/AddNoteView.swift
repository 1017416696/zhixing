//
//  AddNoteView.swift
//  zhixing
//
//  Created by 曹骁凡 on 2024/9/8.
//

import SwiftUI

struct AddNoteView: View {
    @Binding var notes: [Note]
    @State private var content = ""
    @State private var image: UIImage?
    @State private var showingImagePicker = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("图片")) {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 200)
                    }
                    Button(image == nil ? "选择图片" : "更换图片") {
                        showingImagePicker = true
                    }
                }

                Section(header: Text("内容")) {
                    TextEditor(text: $content)
                        .frame(height: 200)
                }
            }
            .navigationTitle("添加新笔记")
            .navigationBarItems(trailing: Button("保存") {
                if let image = image {
                    let newNote = Note(content: content, image: image, date: Date())
                    notes.append(newNote)
                    presentationMode.wrappedValue.dismiss()
                }
            })
        }
        .sheet(isPresented: $showingImagePicker) {
            CustomImagePicker(image: $image)
        }
    }
}

struct CustomImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode

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
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
