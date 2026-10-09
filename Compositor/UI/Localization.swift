import Foundation

/// Looks a display string up in the app's string tables.
///
/// Strings written straight into `Text`, `Button`, `Label` and `help` are
/// `LocalizedStringKey`s, so SwiftUI translates those on its own. Plenty of the
/// interface is built the other way: blend mode names and adjustment names
/// double as the identifiers stored in a `.comp`, tool labels and status hints
/// are assembled in code, and errors carry their own description. Those reach
/// the interface as plain `String`s, which SwiftUI draws verbatim, so they are
/// resolved here instead.
///
/// The English text stays the key, and a string with no entry in a table comes
/// back unchanged, so this is safe to call on anything.
func localizedUI(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: nil, table: nil)
}

/// Same, for a value that should keep its English identity in a project file.
func localizedUI(_ key: String, suffix: String) -> String {
    localizedUI(key) + suffix
}
