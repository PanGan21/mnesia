import Photos

enum PhotoAuthorizationState: Equatable {
  case notDetermined
  case limited
  case authorized
  case denied
  case restricted

  init(status: PHAuthorizationStatus) {
    switch status {
    case .notDetermined:
      self = .notDetermined
    case .limited:
      self = .limited
    case .authorized:
      self = .authorized
    case .denied:
      self = .denied
    case .restricted:
      self = .restricted
    @unknown default:
      self = .denied
    }
  }

  var canBrowseLibrary: Bool {
    self == .authorized || self == .limited
  }

  var title: String {
    switch self {
    case .notDetermined:
      return "Photo access needed"
    case .limited:
      return "Limited photo access"
    case .authorized:
      return "Photo access granted"
    case .denied:
      return "Photo access denied"
    case .restricted:
      return "Photo access restricted"
    }
  }

  var detail: String {
    switch self {
    case .notDetermined:
      return "Grant access to your photo library so mnesia can build an on-device index."
    case .limited:
      return "mnesia can search the assets you selected. You can expand access later in Settings."
    case .authorized:
      return "mnesia can read your local library and build a private index on this device."
    case .denied:
      return "Open Settings to allow access if you want mnesia to index and search your library."
    case .restricted:
      return "This device currently restricts photo access for the app."
    }
  }
}
