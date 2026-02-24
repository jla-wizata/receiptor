import SwiftUI
import AVFoundation
import PhotosUI

// MARK: - Camera Controller

@Observable
final class CameraController: NSObject {
    private(set) var session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var device: AVCaptureDevice?
    private var captureCompletion: ((UIImage) -> Void)?

    var isAuthorized = false
    var minZoom: CGFloat = 1.0
    var maxZoom: CGFloat = 5.0

    func setup() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        } else {
            isAuthorized = (status == .authorized)
        }
        guard isAuthorized else { return }
        configureSession()
    }

    private func configureSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let input = try? AVCaptureDeviceInput(device: device),
                self.session.canAddInput(input)
            else {
                self.session.commitConfiguration()
                return
            }

            self.device = device
            self.session.addInput(input)
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }
            self.session.commitConfiguration()

            let minZ = device.minAvailableVideoZoomFactor
            let maxZ = min(device.maxAvailableVideoZoomFactor, 5.0)
            DispatchQueue.main.async {
                self.minZoom = minZ
                self.maxZoom = maxZ
            }
            self.session.startRunning()
        }
    }

    func start() {
        guard isAuthorized else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stop() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func setZoom(_ factor: CGFloat) {
        guard let device else { return }
        let clamped = max(device.minAvailableVideoZoomFactor,
                         min(device.maxAvailableVideoZoomFactor, factor))
        try? device.lockForConfiguration()
        device.videoZoomFactor = clamped
        device.unlockForConfiguration()
    }

    func capturePhoto(completion: @escaping (UIImage) -> Void) {
        captureCompletion = completion
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        let completion = captureCompletion
        captureCompletion = nil
        DispatchQueue.main.async { completion?(image) }
    }
}

// MARK: - Camera Preview

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView { PreviewView() }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = bounds
        }
    }
}

// MARK: - Capture Tab View

struct CaptureTabView: View {
    @State private var camera = CameraController()
    @State private var capturedImage: UIImage? = nil
    @State private var zoom: CGFloat = 1.0
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var isUploading = false
    @State private var uploadedReceipt: Receipt? = nil
    @State private var showDateCorrection = false
    @State private var errorMessage: String? = nil

    private let service = ReceiptsService()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image = capturedImage {
                reviewView(image)
            } else {
                cameraView
            }
        }
        .task { await camera.setup() }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await loadPickerImage(item) }
        }
        .sheet(isPresented: $showDateCorrection) {
            if let receipt = uploadedReceipt {
                DateCorrectionSheet(receipt: receipt, viewModel: nil) { updated in
                    uploadedReceipt = updated
                }
            }
        }
    }

    // MARK: Camera view

    private var cameraView: some View {
        ZStack {
            if camera.isAuthorized {
                CameraPreview(session: camera.session)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "camera.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Camera Access Required")
                        .font(.headline)
                    Text("Go to Settings → Receiptor → Camera to enable access.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            VStack {
                Spacer()

                // Zoom slider
                HStack(spacing: 12) {
                    Image(systemName: "minus.magnifyingglass").foregroundColor(.white)
                    Slider(
                        value: $zoom,
                        in: camera.minZoom...max(camera.minZoom + 0.1, camera.maxZoom)
                    )
                    .tint(.white)
                    .onChange(of: zoom) { _, val in camera.setZoom(val) }
                    Image(systemName: "plus.magnifyingglass").foregroundColor(.white)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .cornerRadius(14)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

                // Shutter row: library picker left, shutter button center
                ZStack {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 48)

                    Button {
                        camera.capturePhoto { image in
                            capturedImage = image
                            zoom = camera.minZoom
                            camera.stop()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 80, height: 80)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 64, height: 64)
                        }
                    }
                    .disabled(!camera.isAuthorized)
                }
                .padding(.bottom, 48)
            }
        }
    }

    // MARK: Review view

    private func reviewView(_ image: UIImage) -> some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .background(Color.black)

            VStack {
                Spacer()

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.85))
                        .cornerRadius(8)
                        .padding(.bottom, 8)
                }

                HStack(spacing: 16) {
                    Button { capturedImage = nil; errorMessage = nil; camera.start() } label: {
                        Label("Retake", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .disabled(isUploading)

                    Button { upload(image) } label: {
                        Group {
                            if isUploading {
                                HStack(spacing: 8) {
                                    ProgressView().tint(.white)
                                    Text("Uploading...")
                                }
                            } else {
                                Label("Upload", systemImage: "arrow.up.doc")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isUploading)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }

    // MARK: Helpers

    private func upload(_ image: UIImage) {
        isUploading = true
        errorMessage = nil
        Task {
            let jpeg = await Task.detached(priority: .userInitiated, operation: {
                image.jpegData(compressionQuality: 0.85)
            }).value
            guard let jpeg else {
                await MainActor.run { isUploading = false }
                return
            }
            do {
                let receipt = try await service.upload(imageData: jpeg)
                await MainActor.run {
                    uploadedReceipt = receipt
                    isUploading = false
                    capturedImage = nil
                    if receipt.ocrStatus != "success" {
                        showDateCorrection = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isUploading = false
                }
            }
        }
    }

    private func loadPickerImage(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        await MainActor.run {
            capturedImage = image
            pickerItem = nil
        }
    }
}
