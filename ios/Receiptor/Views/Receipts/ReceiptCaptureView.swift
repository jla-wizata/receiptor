import SwiftUI
import PhotosUI
import UIKit

struct ReceiptCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: ReceiptListViewModel

    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var showCamera = false
    @State private var previewImage: UIImage? = nil
    @State private var showConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let image = previewImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .padding()
                        .frame(maxHeight: 400)
                } else {
                    placeholder
                }

                VStack(spacing: 12) {
                    PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)

                    Button {
                        showCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)

                    if previewImage != nil {
                        Button(action: upload) {
                            Label("Upload Receipt", systemImage: "arrow.up.doc")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.top)
            .navigationTitle("Add Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                guard let newItem else { return }
                Task { await loadPickerItem(newItem) }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPickerView { image in
                    previewImage = image
                    showCamera = false
                }
                .ignoresSafeArea()
            }
        }
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            Text("Select or photograph a receipt")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: 300)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding()
    }

    private func loadPickerItem(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        await MainActor.run { previewImage = image }
    }

    private func upload() {
        guard let image = previewImage,
              let jpeg = image.jpegData(compressionQuality: 0.85) else { return }
        dismiss()
        Task { await viewModel.upload(imageData: jpeg) }
    }
}

// MARK: - Camera UIKit wrapper

struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                onCapture(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
