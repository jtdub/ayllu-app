import UIKit
import CoreLocation
import ImageIO
import UniformTypeIdentifiers

/// Service for saving photos with GPS EXIF metadata and generating thumbnails
struct PhotoStorageService {
    // MARK: - Configuration

    private let photosDirectory: URL
    private let thumbnailsDirectory: URL
    private let thumbnailSize: CGFloat = 256

    // MARK: - Initialization

    init() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        photosDirectory = documentsURL.appendingPathComponent("Photos", isDirectory: true)
        thumbnailsDirectory = documentsURL.appendingPathComponent("Thumbnails", isDirectory: true)

        // Create directories if needed
        try? FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public Methods

    /// Saves a photo with GPS EXIF metadata and generates a thumbnail
    /// - Parameters:
    ///   - image: The captured image
    ///   - location: GPS location to embed
    ///   - heading: Compass heading at capture time
    ///   - projectId: Project ID for organizing photos
    /// - Returns: Tuple of (photo file path, thumbnail file path)
    func savePhoto(
        image: UIImage,
        location: CLLocation?,
        heading: CLHeading?,
        projectId: Int64
    ) throws -> (photoPath: String, thumbnailPath: String) {
        let timestamp = Date()
        let fileName = generateFileName(projectId: projectId, timestamp: timestamp)

        // Save main photo with EXIF
        let photoPath = try saveMainPhoto(
            image: image,
            fileName: fileName,
            location: location,
            heading: heading,
            timestamp: timestamp
        )

        // Generate and save thumbnail
        let thumbnailPath = try saveThumbnail(image: image, fileName: fileName)

        return (photoPath, thumbnailPath)
    }

    /// Deletes photo files from disk
    func deletePhoto(photoPath: String, thumbnailPath: String?) {
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: photoPath) {
            try? fileManager.removeItem(atPath: photoPath)
        }

        if let thumbnailPath = thumbnailPath, fileManager.fileExists(atPath: thumbnailPath) {
            try? fileManager.removeItem(atPath: thumbnailPath)
        }
    }

    // MARK: - Private Methods

    private func generateFileName(projectId: Int64, timestamp: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = formatter.string(from: timestamp)
        return "photo_\(projectId)_\(dateString)_\(UUID().uuidString.prefix(8))"
    }

    private func saveMainPhoto(
        image: UIImage,
        fileName: String,
        location: CLLocation?,
        heading: CLHeading?,
        timestamp: Date
    ) throws -> String {
        let photoURL = photosDirectory.appendingPathComponent("\(fileName).jpg")

        // Get image data with EXIF
        guard let imageData = createJPEGWithEXIF(
            image: image,
            location: location,
            heading: heading,
            timestamp: timestamp
        ) else {
            throw PhotoStorageError.encodingFailure
        }

        try imageData.write(to: photoURL)
        return photoURL.path
    }

    private func saveThumbnail(image: UIImage, fileName: String) throws -> String {
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent("\(fileName)_thumb.jpg")

        guard let thumbnail = createThumbnail(from: image) else {
            throw PhotoStorageError.thumbnailFailure
        }

        guard let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) else {
            throw PhotoStorageError.encodingFailure
        }

        try thumbnailData.write(to: thumbnailURL)
        return thumbnailURL.path
    }

    private func createThumbnail(from image: UIImage) -> UIImage? {
        let size = image.size
        let aspectRatio = size.width / size.height

        let thumbnailWidth: CGFloat
        let thumbnailHeight: CGFloat

        if aspectRatio > 1 {
            thumbnailWidth = thumbnailSize
            thumbnailHeight = thumbnailSize / aspectRatio
        } else {
            thumbnailHeight = thumbnailSize
            thumbnailWidth = thumbnailSize * aspectRatio
        }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: thumbnailWidth, height: thumbnailHeight))
        return renderer.image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: thumbnailWidth, height: thumbnailHeight))
        }
    }

    private func createJPEGWithEXIF(
        image: UIImage,
        location: CLLocation?,
        heading: CLHeading?,
        timestamp: Date
    ) -> Data? {
        guard let cgImage = image.cgImage else { return nil }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }

        // Build EXIF metadata
        var metadata: [String: Any] = [:]

        // EXIF dictionary
        var exifDict: [String: Any] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        exifDict[kCGImagePropertyExifDateTimeOriginal as String] = dateFormatter.string(from: timestamp)
        exifDict[kCGImagePropertyExifDateTimeDigitized as String] = dateFormatter.string(from: timestamp)

        metadata[kCGImagePropertyExifDictionary as String] = exifDict

        // GPS dictionary
        if let location = location {
            var gpsDict: [String: Any] = [:]

            // Latitude
            let latitude = location.coordinate.latitude
            gpsDict[kCGImagePropertyGPSLatitude as String] = abs(latitude)
            gpsDict[kCGImagePropertyGPSLatitudeRef as String] = latitude >= 0 ? "N" : "S"

            // Longitude
            let longitude = location.coordinate.longitude
            gpsDict[kCGImagePropertyGPSLongitude as String] = abs(longitude)
            gpsDict[kCGImagePropertyGPSLongitudeRef as String] = longitude >= 0 ? "E" : "W"

            // Altitude
            if location.verticalAccuracy >= 0 {
                gpsDict[kCGImagePropertyGPSAltitude as String] = abs(location.altitude)
                gpsDict[kCGImagePropertyGPSAltitudeRef as String] = location.altitude >= 0 ? 0 : 1
            }

            // Accuracy
            if location.horizontalAccuracy >= 0 {
                gpsDict[kCGImagePropertyGPSHPositioningError as String] = location.horizontalAccuracy
            }

            // Timestamp
            let gpsDateFormatter = DateFormatter()
            gpsDateFormatter.dateFormat = "yyyy:MM:dd"
            gpsDateFormatter.timeZone = TimeZone(identifier: "UTC")
            gpsDict[kCGImagePropertyGPSDateStamp as String] = gpsDateFormatter.string(from: location.timestamp)

            let gpsTimeFormatter = DateFormatter()
            gpsTimeFormatter.dateFormat = "HH:mm:ss"
            gpsTimeFormatter.timeZone = TimeZone(identifier: "UTC")
            gpsDict[kCGImagePropertyGPSTimeStamp as String] = gpsTimeFormatter.string(from: location.timestamp)

            // Heading (direction of camera)
            if let heading = heading, heading.trueHeading >= 0 {
                gpsDict[kCGImagePropertyGPSImgDirection as String] = heading.trueHeading
                gpsDict[kCGImagePropertyGPSImgDirectionRef as String] = "T"
            }

            metadata[kCGImagePropertyGPSDictionary as String] = gpsDict
        }

        // Add image with metadata
        CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)

        guard CGImageDestinationFinalize(destination) else { return nil }

        return data as Data
    }
}

// MARK: - Photo Storage Errors

enum PhotoStorageError: LocalizedError {
    case encodingFailure
    case thumbnailFailure
    case writeFailure

    var errorDescription: String? {
        switch self {
        case .encodingFailure:
            return "Failed to encode image"
        case .thumbnailFailure:
            return "Failed to create thumbnail"
        case .writeFailure:
            return "Failed to write file"
        }
    }
}
