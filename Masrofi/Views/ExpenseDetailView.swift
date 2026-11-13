import SwiftUI
import SwiftData
import MapKit
import PhotosUI

struct ExpenseDetailView: View {
    @Bindable var expense: Expense
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var photoItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingReceipt = false
    @State private var confirmDelete = false

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    CategoryBadge(category: expense.category, size: 56)
                    Text(expense.formattedAmount)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(expense.displayMerchant)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(expense.date, format: .dateTime.weekday(.wide).day().month(.wide).year().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if expense.isApplePay {
                        Label(expense.card.isEmpty ? "Apple Pay" : "Apple Pay • \(expense.card)", systemImage: "apple.logo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }

            if let coordinate = expense.coordinate {
                Section("المكان") {
                    Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 700, longitudinalMeters: 700))) {
                        Marker(expense.displayMerchant, systemImage: expense.category.icon, coordinate: coordinate)
                            .tint(expense.category.color)
                    }
                    .frame(height: 200)
                    .listRowInsets(EdgeInsets())
                    if !expense.placeName.isEmpty {
                        Label(expense.placeName, systemImage: "mappin.and.ellipse")
                    }
                    Button {
                        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                        item.name = expense.displayMerchant
                        item.openInMaps()
                    } label: {
                        Label("افتح في الخرائط", systemImage: "arrow.up.forward.app")
                    }
                }
            }

            Section("الفاتورة") {
                if let data = expense.receiptImage, let image = UIImage(data: data) {
                    Button { showingReceipt = true } label: {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 260)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    Button("حذف صورة الفاتورة", role: .destructive) { expense.receiptImage = nil }
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button { showingCamera = true } label: {
                        Label("صوّر الفاتورة", systemImage: "camera.fill")
                    }
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("اختر من الصور", systemImage: "photo.on.rectangle")
                }
            }

            Section("التفاصيل") {
                LabeledContent("المبلغ") {
                    TextField("0", value: $expense.amount, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("المتجر") {
                    TextField("اسم المتجر", text: $expense.merchant)
                        .multilineTextAlignment(.trailing)
                }
                Picker("التصنيف", selection: $expense.category) {
                    ForEach(ExpenseCategory.allCases) { c in
                        Label(c.title, systemImage: c.icon).tag(c)
                    }
                }
                DatePicker("التاريخ", selection: $expense.date)
                TextField("ملاحظة", text: $expense.note, axis: .vertical)
                    .lineLimit(1...5)
            }

            Section {
                Button("حذف العملية", role: .destructive) { confirmDelete = true }
            }
        }
        .navigationTitle(expense.displayMerchant)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    expense.receiptImage = ImageTools.compressedJPEG(image)
                }
                photoItem = nil
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in
                expense.receiptImage = ImageTools.compressedJPEG(image)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingReceipt) {
            if let data = expense.receiptImage, let image = UIImage(data: data) {
                ReceiptViewer(image: image)
            }
        }
        .confirmationDialog("متأكد تبي تحذف العملية؟", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("حذف", role: .destructive) {
                context.delete(expense)
                try? context.save()
                dismiss()
            }
        }
    }
}

struct ReceiptViewer: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: UIScreen.main.bounds.width * scale)
                    .gesture(MagnifyGesture().onChanged { scale = max(1, min(4, $0.magnification)) })
            }
            .background(Color.black)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إغلاق") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: Image(uiImage: image), preview: SharePreview("الفاتورة", image: Image(uiImage: image)))
                }
            }
        }
    }
}

enum ImageTools {
    static func compressedJPEG(_ image: UIImage, maxSide: CGFloat = 1800) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let ratio = longest > maxSide ? maxSide / longest : 1
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
