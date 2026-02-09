// lib/store/istamil.dart

class LanguageStore {
  // Static variable to store the state globally
  static bool isTamil = false;

  // Optional: Function to update the state
  static void setLanguage(String language) {
    isTamil = (language == "தமிழ்");
  }
}
