//
//  ContentView.swift
//  zhixing
//
//  Created by 曹骁凡 on 2024/9/7.
//

import SwiftUI
import AVFoundation
import Photos

class CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var image: UIImage?
    @Published var captureSession: AVCaptureSession?
    @Published var currentCameraPosition: AVCaptureDevice.Position = .back
    var photoOutput: AVCapturePhotoOutput?
    
    var overlayInfo: (time: String, date: String, location: String)?
    var overlayPosition: CGPoint?
    @Published var deviceOrientation: UIDeviceOrientation = .portrait
    
    @Published var zoomFactor: CGFloat = 1.0
    
    @Published var isTakingPhoto = false
    
    override init() {
        super.init()
        setupCamera()
    }
    
    func setupCamera() {
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            let output = AVCapturePhotoOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
                self.photoOutput = output
            }
            
            if let connection = output.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait // 确保输出方向为竖直
                }
                
                // 设置4:3比例
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = false
                }
                connection.videoScaleAndCropFactor = 1.0
            }
            
            // 设置片输出格式为4:3
            if let photoOutputConnection = output.connection(with: .video) {
                photoOutputConnection.videoRotationAngle = .zero
            }
            output.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])], completionHandler: nil)
            
            session.commitConfiguration()
            self.captureSession = session
            DispatchQueue.global(qos: .background).async {
                self.captureSession?.startRunning()
            }
        } catch {
            print("Failed to set up camera: \(error.localizedDescription)")
        }
    }
    
    func takePhoto(time: String, date: String, location: String, position: CGPoint, orientation: UIDeviceOrientation) {
        guard let photoOutput = self.photoOutput, !isTakingPhoto else { return }
        
        isTakingPhoto = true
        
        self.overlayInfo = (time, date, location)
        self.overlayPosition = position
        self.deviceOrientation = orientation
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer { isTakingPhoto = false }
        
        if let error = error {
            print("拍照出错: \(error.localizedDescription)")
            return
        }
        
        if let imageData = photo.fileDataRepresentation(),
           var image = UIImage(data: imageData),
           let overlayInfo = self.overlayInfo,
           let overlayPosition = self.overlayPosition {
            
            // 正图像方向
            if let cgImage = image.cgImage {
                image = UIImage(cgImage: cgImage, scale: image.scale, orientation: .right)
            }
            
            // 在后台线程处理图像
            DispatchQueue.global(qos: .userInitiated).async {
                let processedImage = self.addOverlayToImage(image, info: overlayInfo, position: overlayPosition)
                DispatchQueue.main.async {
                    self.image = processedImage
                }
            }
        }
    }
    
    private func addOverlayToImage(_ image: UIImage, info: (time: String, date: String, location: String), position: CGPoint) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: image.size))
            
            let scaleFactor = image.size.width / UIScreen.main.bounds.width
            let fontSize = 20.0 * scaleFactor
            let padding: CGFloat = 10.0 * scaleFactor
            let lineSpacing: CGFloat = 5.0 * scaleFactor
            let cornerRadius: CGFloat = 10.0 * scaleFactor
            
            let timeAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize * 1.3, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
                .foregroundColor: UIColor.white
            ]
            let locationAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize * 0.8),
                .foregroundColor: UIColor.white
            ]
            
            let timeSize = (info.time as NSString).size(withAttributes: timeAttributes)
            let dateSize = (info.date as NSString).size(withAttributes: dateAttributes)
            let locationSize = (info.location as NSString).size(withAttributes: locationAttributes)
            
            let totalHeight = timeSize.height + dateSize.height + locationSize.height + padding * 2 + lineSpacing * 2
            let maxWidth = max(timeSize.width, dateSize.width, locationSize.width) + padding * 2
            
            context.cgContext.saveGState()
            
            // 根据设备方向调整位置和旋转
            let rotationAngle: CGFloat
            var adjustedPosition: CGPoint
            switch deviceOrientation {
            case .landscapeLeft:
                rotationAngle = .pi / 2
                context.cgContext.translateBy(x: image.size.width, y: 0)
                adjustedPosition = CGPoint(x: position.y * scaleFactor, y: image.size.width - position.x * scaleFactor)
            case .landscapeRight:
                rotationAngle = -.pi / 2
                context.cgContext.translateBy(x: 0, y: image.size.height)
                adjustedPosition = CGPoint(x: image.size.height - position.y * scaleFactor, y: position.x * scaleFactor)
            default:
                rotationAngle = 0
                adjustedPosition = CGPoint(x: position.x * scaleFactor, y: position.y * scaleFactor)
            }
            context.cgContext.rotate(by: rotationAngle)
            
            let rect = CGRect(x: adjustedPosition.x - maxWidth / 2,
                              y: adjustedPosition.y - totalHeight / 2,
                              width: maxWidth,
                              height: totalHeight)
            
            // 创建圆角矩形路径
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            context.cgContext.addPath(path.cgPath)
            
            // 设置半透明黑色充
            context.cgContext.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
            context.cgContext.drawPath(using: .fill)
            
            let timePoint = CGPoint(x: rect.midX - timeSize.width / 2,
                                    y: rect.minY + padding)
            let datePoint = CGPoint(x: rect.midX - dateSize.width / 2,
                                    y: timePoint.y + timeSize.height + lineSpacing)
            let locationPoint = CGPoint(x: rect.midX - locationSize.width / 2,
                                        y: datePoint.y + dateSize.height + lineSpacing)
            
            // 绘制文本
            (info.time as NSString).draw(at: timePoint, withAttributes: timeAttributes)
            (info.date as NSString).draw(at: datePoint, withAttributes: dateAttributes)
            (info.location as NSString).draw(at: locationPoint, withAttributes: locationAttributes)
            
            context.cgContext.restoreGState()
        }
    }
    
    func switchCamera() {
        //print("开始切换摄像头")
        guard let session = captureSession else { return }
        
        session.beginConfiguration()
        
        // 移除当前的视频输入
        session.inputs.forEach { input in
            if let videoInput = input as? AVCaptureDeviceInput {
                session.removeInput(videoInput)
            }
        }
        
        // 切换摄像头位置
        currentCameraPosition = currentCameraPosition == .back ? .front : .back
        
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition) else {
            session.commitConfiguration()
            print("无法获取新的摄像头")
            return
        }
        
        do {
            let newInput = try AVCaptureDeviceInput(device: newCamera)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
            }
            
            session.commitConfiguration()
            //print("摄像头切换完成")
        } catch {
            print("切换摄像头失败: \(error.localizedDescription)")
            session.commitConfiguration()
        }
    }
    
    func setZoom(_ factor: CGFloat) {
        guard let device = (self.captureSession?.inputs.first as? AVCaptureDeviceInput)?.device else { return }
        
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = max(1.0, min(factor, device.maxAvailableVideoZoomFactor))
            device.unlockForConfiguration()
        } catch {
            print("无法设置相机焦距: \(error.localizedDescription)")
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        setupPreviewLayer(view)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer,
           previewLayer.session != cameraManager.captureSession {
            setupPreviewLayer(uiView)
        }
    }
    
    private func setupPreviewLayer(_ view: UIView) {
        view.layer.sublayers?.removeAll()
        
        guard let captureSession = cameraManager.captureSession else { return }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait // 确保预览层始终为竖直方向
        
        let screenSize = UIScreen.main.bounds.size
        let previewHeight = screenSize.width * 4 / 3
        let yOffset = (screenSize.height - previewHeight) / 2
        let upwardShift: CGFloat = 25
        previewLayer.frame = CGRect(x: 0, y: yOffset - upwardShift, width: screenSize.width, height: previewHeight)
        
        view.layer.addSublayer(previewLayer)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: CameraPreview
        
        init(_ parent: CameraPreview) {
            self.parent = parent
        }
    }
}

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var cameraManager = CameraManager()
    @State private var currentTime = Date()
    @State private var cameraPosition = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
    @State private var showingPhotoPreview = false
    @State private var infoSize: CGSize = .zero
    @State private var deviceOrientation: UIDeviceOrientation = .portrait
    @State private var zoomFactor: CGFloat = 1.0
    
    @State private var showingNotesList = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                CameraPreview(cameraManager: cameraManager)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    Spacer()
                    
                    TimeInfoView(
                        formattedTime: formattedTime,
                        formattedDate: formattedDate,
                        locationInfo: locationManager.formattedAddress,
                        deviceOrientation: deviceOrientation
                    )
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: SizePreferenceKey.self, value: proxy.size)
                    })
                    .onPreferenceChange(SizePreferenceKey.self) { size in
                        self.infoSize = size
                    }
                    .position(cameraPosition)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newPosition = value.location
                                let previewWidth = geometry.size.width
                                let previewHeight = previewWidth * 4 / 3
                                let yOffset = (geometry.size.height - previewHeight) / 2
                                let upwardShift: CGFloat = 30 // 与CameraPreview中的值保持一致
                                
                                let isLandscape = deviceOrientation.isLandscape
                                let rotatedInfoSize = isLandscape ? CGSize(width: infoSize.height, height: infoSize.width) : infoSize
                                
                                let minX = rotatedInfoSize.width / 2
                                let maxX = previewWidth - rotatedInfoSize.width / 2
                                let minY = yOffset - upwardShift + rotatedInfoSize.height / 2
                                let maxY = minY + previewHeight - rotatedInfoSize.height
                                
                                self.cameraPosition = CGPoint(
                                    x: min(max(newPosition.x, minX), maxX),
                                    y: min(max(newPosition.y, minY), maxY)
                                )
                            }
                    )
                    
                    Slider(value: $zoomFactor, in: 1...5, step: 0.1)
                        .padding(.horizontal, 40)
                        .accentColor(.white)
                        .onChange(of: zoomFactor) { _, newValue in
                            cameraManager.setZoom(newValue)
                        }
                    
                    HStack {
                        Button(action: {
                            showingNotesList = true
                        }) {
                            Image(systemName: "note.text")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 30, height: 30)
                                .foregroundColor(.white)
                                .rotationEffect(rotationAngle)
                                .padding(20) // 增加内边距，扩大可点击区域
                                .background(Color.black.opacity(0.5)) // 添加背景，提供视觉反馈
                                .cornerRadius(15) // 圆角效果
                        }
                        .buttonStyle(PlainButtonStyle()) // 使用PlainButtonStyle以保持自定义外观
                        .contentShape(Rectangle()) // 确保整个区域都可点击

                        Spacer()
                        
                        Button(action: {
                            cameraManager.takePhoto(
                                time: formattedTime,
                                date: formattedDate,
                                location: locationManager.formattedAddress,
                                position: cameraPosition,
                                orientation: deviceOrientation
                            )
                        }) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black, lineWidth: 2)
                                        .frame(width: 70, height: 70)
                                )
                                .rotationEffect(rotationAngle)
                        }
                        .disabled(cameraManager.isTakingPhoto)
                        
                        Spacer()
                        
                        Button(action: {
                            cameraManager.switchCamera()
                        }) {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 30, height: 30)
                                .foregroundColor(.white)
                                .rotationEffect(rotationAngle)
                        }
                    }
                    .padding(.horizontal, 20) // 减小水平内边距，给按钮更多空间
                    .padding(.bottom, 40)
                }
            }
        }
        .statusBar(hidden: true)
        .onAppear {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            AppDelegate.orientationLock = .portrait
            locationManager.startUpdatingLocation()
            startOrientationObserver()
        }
        .onDisappear {
            stopOrientationObserver()
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .onChange(of: cameraManager.image) { _, newImage in
            if newImage != nil {
                showingPhotoPreview = true
            }
        }
        .fullScreenCover(isPresented: $showingPhotoPreview) {
            if let image = cameraManager.image {
                PhotoPreviewView(image: image, isPresented: $showingPhotoPreview)
            }
        }
        .sheet(isPresented: $showingNotesList) {
            NotesListView()
        }
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: currentTime)
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentTime)
    }
    
    // 添加个计算属性来获取旋转角度
    var rotationAngle: Angle {
        switch UIDevice.current.orientation {
        case .landscapeLeft:
            return .degrees(90)
        case .landscapeRight:
            return .degrees(-90)
        default:
            return .degrees(0)
        }
    }
    
    private func startOrientationObserver() {
        NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main) { _ in
            self.deviceOrientation = UIDevice.current.orientation
        }
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }
    
    private func stopOrientationObserver() {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
}

struct PhotoPreviewView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    @State private var isSaving = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // 顶部黑色区域
                    Color.black.frame(height: (geometry.size.height - geometry.size.width * 4 / 3) / 2 - 25)
                    
                    // 图片区域
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.width * 4 / 3)
                        .clipped()
                    
                    // 底部黑色区域
                    Color.black.frame(height: (geometry.size.height - geometry.size.width * 4 / 3) / 2 + 25)
                }
                
                // 按钮区域
                VStack {
                    Spacer()
                    ZStack {
                        // 载按钮（中心位）
                        Button(action: {
                            savePhoto()
                        }) {
                            Image(systemName: "arrow.down.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                                .foregroundColor(.white)
                                .overlay(
                                    Group {
                                        if isSaving {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                                .scaleEffect(1.5)
                                        }
                                    }
                                )
                        }
                        .disabled(isSaving)
                        
                        // 返回按钮（左侧）
                        HStack {
                            Button(action: {
                                isPresented = false
                            }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.white)
                                    .font(.system(size: 24))
                                    .frame(width: 60, height: 60)
                            }
                            .padding(.leading, 20)
                            Spacer()
                        }
                    }
                    .frame(height: (geometry.size.height - geometry.size.width * 4 / 3) / 2 + 25)
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    func savePhoto() {
        isSaving = true
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    isSaving = false
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    isSaving = false
                    if success {
                        isPresented = false // 保存成功后直接返回主页
                    } else if let error = error {
                        print("保存照片失败: \(error.localizedDescription)")
                        // 这里可以添加错误提示，如果需要
                    }
                }
            }
        }
    }
}

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct TimeInfoView: View {
    let formattedTime: String
    let formattedDate: String
    let locationInfo: String
    let deviceOrientation: UIDeviceOrientation

    var body: some View {
        VStack(spacing: 5) {
            Text(formattedTime)
                .font(.system(size: isLandscape ? 22 : 26, weight: .bold))
            Text(formattedDate)
                .font(.system(size: isLandscape ? 18 : 20, weight: .medium))
            Text(locationInfo)
                .font(.system(size: isLandscape ? 14 : 16))
        }
        .foregroundColor(.white)
        .padding()
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
        .rotationEffect(rotationAngle)
    }

    var isLandscape: Bool {
        deviceOrientation.isLandscape
    }

    var rotationAngle: Angle {
        switch deviceOrientation {
        case .landscapeLeft:
            return .degrees(90)
        case .landscapeRight:
            return .degrees(-90)
        default:
            return .degrees(0)
        }
    }
}

extension UIDeviceOrientation {
    var isLandscape: Bool {
        return self == .landscapeLeft || self == .landscapeRight
    }
}

// 添加这个扩展
extension AppDelegate {
    static var orientationLock = UIInterfaceOrientationMask.portrait
}





#Preview {
    ContentView()
}
