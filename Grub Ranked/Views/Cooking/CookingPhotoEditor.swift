import PhotosUI
import SwiftUI
import UIKit

struct CookingPhotoEditor: View {
    @Binding var draft: CookingDraft
    @State private var selection: PhotosPickerItem?
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        let hasPhoto = draft.hasPhoto
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            DishPhoto(media: draft.removeExistingPhoto ? nil : draft.existingPhoto,
                      prepared: draft.pendingPhoto, name: draft.cleanDishName.isEmpty ? "dish" : draft.cleanDishName)
                .frame(maxWidth: .infinity).frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: SGTheme.Radius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: SGTheme.Radius.card, style: .continuous)
                        .stroke(SGTheme.ColorToken.border)
                }
            HStack {
                PhotosPicker(selection: $selection, matching: .images) {
                    Label(hasPhoto ? "Replace Photo" : "Choose Photo",
                          systemImage: hasPhoto ? "photo.badge.arrow.down" : "photo.badge.plus")
                        .frame(minHeight: SGTheme.Size.minimumTap)
                }
                .disabled(loading)
                if hasPhoto {
                    Button("Remove", role: .destructive) {
                        draft.pendingPhoto = nil
                        draft.removeExistingPhoto = true
                        selection = nil
                    }.frame(minHeight: SGTheme.Size.minimumTap)
                }
                if loading { ProgressView().accessibilityLabel("Preparing photo") }
            }
        }
        .task(id: selection) {
            guard let selection else { return }
            loading = true; defer { loading = false }
            do {
                guard let data = try await selection.loadTransferable(type: Data.self) else {
                    throw LocalPhotoStore.PhotoError.unreadableImage
                }
                let prepared = try await Task.detached { try LocalPhotoStore.prepare(data: data) }.value
                draft.pendingPhoto = prepared
                draft.removeExistingPhoto = false
            } catch { self.error = error.localizedDescription }
        }
        .alert("Couldn't use that photo", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }
}
