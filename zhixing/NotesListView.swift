//
//  NotesListView.swift
//  zhixing
//
//  Created by 曹骁凡 on 2024/9/8.
//

import SwiftUI
import UIKit

struct NotesListView: View {
    @State private var notes: [Note] = []
    @State private var showingAddNote = false
    @State private var selectedView = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Text("我的笔记")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Picker("View", selection: $selectedView) {
                            Text("列表").tag(0)
                            Text("地图").tag(1)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 180)
                    }
                    .frame(width: 180)
                    Spacer()
                    
                    Button(action: {
                        showingAddNote = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 30))
                    }
                    .padding(.leading, -30) // 调整按钮位置
                }
                .padding()
                
                if selectedView == 0 {
                    List(notes) { note in
                        NavigationLink(destination: NoteDetailView(note: note)) {
                            HStack {
                                Image(uiImage: note.image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(8)
                                VStack(alignment: .leading) {
                                    Text(note.content.prefix(50) + "...")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                } else {
                    NoteMapView(notes: notes)
                }
            }
        }
        .sheet(isPresented: $showingAddNote) {
            AddNoteView(notes: $notes)
        }
    }
}

struct NoteDetailView: View {
    let note: Note
    @State private var isImageFullscreen = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 图片部分
                ZStack(alignment: .bottomTrailing) {
                    Image(uiImage: note.image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 300)
                        .clipped()
                        .cornerRadius(12)
                        .onTapGesture {
                            isImageFullscreen = true
                        }
                    
                    // 日期覆盖在图片上
                    Text(formattedDate(note.date))
                        .font(.caption)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(12)
                }
                
                // 位置信息部分
                if let location = note.location {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("图片位置", systemImage: "mappin.and.ellipse")
                            .font(.headline)
                        
                        if !note.locationName.isEmpty {
                            Text(note.locationName)
                                .font(.subheadline)
                        }
                        
                        Text("经度: \(location.longitude, specifier: "%.6f")")
                            .font(.caption)
                        Text("纬度: \(location.latitude, specifier: "%.6f")")
                            .font(.caption)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // 内容部分
                VStack(alignment: .leading, spacing: 12) {
                    Text("笔记内容")
                        .font(.headline)
                    
                    Text(note.content)
                        .font(.body)
                        .lineSpacing(4)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .navigationTitle("笔记详情")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isImageFullscreen) {
            FullscreenImageView(image: note.image, isPresented: $isImageFullscreen)
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

struct FullscreenImageView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    @State private var offset = CGSize.zero
    
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .edgesIgnoringSafeArea(.all)
            .offset(y: offset.height)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        offset = gesture.translation
                    }
                    .onEnded { _ in
                        if abs(offset.height) > 100 {
                            isPresented = false
                        } else {
                            offset = .zero
                        }
                    }
            )
            .onTapGesture {
                isPresented = false
            }
    }
}
