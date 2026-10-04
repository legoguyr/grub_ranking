import SwiftUI

/// The form only exposes fields belonging to the selected source type.
struct DishSourceFields: View {
    @Binding var source: DishSourceDraft

    var body: some View {
        switch source.type {
        case .original:
            Text("Your own idea or recipe.").foregroundStyle(.secondary)
        case .cookbook:
            TextField("Cookbook title", text: $source.cookbookTitle).accessibilityIdentifier("source-cookbook-title")
            TextField("Author(s)", text: $source.cookbookAuthors)
            TextField("Recipe / dish name", text: $source.cookbookRecipeName)
            TextField("Page (optional)", text: $source.cookbookPage)
        case .restaurant:
            TextField("Restaurant name", text: $source.restaurantName).accessibilityIdentifier("source-restaurant-name")
            TextField("Original dish name", text: $source.restaurantDishName)
            TextField("Location (optional)", text: $source.restaurantLocation)
        case .onlineRecipe:
            TextField("Recipe name", text: $source.onlineRecipeName)
            TextField("Website / creator", text: $source.onlineWebsite)
            TextField("Recipe URL", text: $source.onlineURL)
                .keyboardType(.URL).textInputAutocapitalization(.never)
        case .socialMedia:
            TextField("Creator", text: $source.socialCreator)
            TextField("Platform", text: $source.socialPlatform)
            TextField("Post / video URL", text: $source.socialURL)
                .keyboardType(.URL).textInputAutocapitalization(.never)
            TextField("Dish name", text: $source.socialDishName)
        case .friendFamily:
            TextField("Person / source name", text: $source.friendName)
            TextField("Note (optional)", text: $source.friendNote, axis: .vertical)
        case .other:
            TextField("Source name", text: $source.otherName)
            TextField("Details (optional)", text: $source.otherDetails, axis: .vertical)
        }
    }
}
