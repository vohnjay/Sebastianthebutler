//
//  WeatherService.swift
//  Sebastianthebutler
//
//  Created by DeVohn Jackson on 3/2/26.
//

import Foundation
import CoreLocation

// MARK: - Models

struct WeatherData {
    let temperature: Double          // Fahrenheit
    let weatherCode: Int
    let windSpeed: Double            // mph (10 m wind)

    var conditionLabel: String       { WeatherService.conditionLabel(for: weatherCode) }
    var symbolName: String           { WeatherService.symbolName(for: weatherCode) }
    var symbolColor: String          { WeatherService.symbolColor(for: weatherCode) }
    var clothingAdvice: String       { WeatherService.clothingAdvice(temp: temperature, code: weatherCode) }
    var outfitEmoji: String          { WeatherService.outfitEmoji(temp: temperature, code: weatherCode) }
}

// MARK: - Location Manager

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    var coordinate: CLLocationCoordinate2D?
    var authStatus: CLAuthorizationStatus = .notDetermined
    var locationError: String?

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
        authStatus = manager.authorizationStatus
    }

    // Returns the current location, requesting permission if needed.
    func fetchLocation() async throws -> CLLocationCoordinate2D {
        if let existing = coordinate { return existing }
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            default:
                cont.resume(throwing: LocationError.denied)
                self.continuation = nil
            }
        }
    }

    // MARK: CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        coordinate = loc.coordinate
        continuation?.resume(returning: loc.coordinate)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = error.localizedDescription
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            continuation?.resume(throwing: LocationError.denied)
            continuation = nil
        default:
            break
        }
    }
}

enum LocationError: LocalizedError {
    case denied
    var errorDescription: String? {
        "Location access was denied. Enable it in Settings to see weather."
    }
}

// MARK: - Open-Meteo Response

private struct OpenMeteoResponse: Codable {
    struct Current: Codable {
        let temperature2m: Double
        let weatherCode: Int
        let windSpeed10m: Double

        enum CodingKeys: String, CodingKey {
            case temperature2m   = "temperature_2m"
            case weatherCode     = "weather_code"
            case windSpeed10m    = "wind_speed_10m"
        }
    }
    let current: Current
}

// MARK: - Service

final class WeatherService {
    static let shared = WeatherService()
    private init() {}

    func fetch(latitude: Double, longitude: Double) async throws -> WeatherData {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            .init(name: "latitude",         value: String(latitude)),
            .init(name: "longitude",        value: String(longitude)),
            .init(name: "current",          value: "temperature_2m,weather_code,wind_speed_10m"),
            .init(name: "temperature_unit", value: "fahrenheit"),
            .init(name: "wind_speed_unit",  value: "mph"),
            .init(name: "timezone",         value: "auto"),
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        return WeatherData(
            temperature: decoded.current.temperature2m,
            weatherCode: decoded.current.weatherCode,
            windSpeed:   decoded.current.windSpeed10m
        )
    }

    // MARK: - Lookup tables

    static func conditionLabel(for code: Int) -> String {
        switch code {
        case 0:       return "Clear skies"
        case 1:       return "Mostly clear"
        case 2:       return "Partly cloudy"
        case 3:       return "Overcast"
        case 45, 48:  return "Foggy"
        case 51, 53, 55: return "Light drizzle"
        case 56, 57:  return "Freezing drizzle"
        case 61, 63:  return "Rain"
        case 65:      return "Heavy rain"
        case 66, 67:  return "Freezing rain"
        case 71, 73:  return "Snow"
        case 75:      return "Heavy snow"
        case 77:      return "Snow grains"
        case 80, 81:  return "Rain showers"
        case 82:      return "Heavy rain showers"
        case 85, 86:  return "Snow showers"
        case 95:      return "Thunderstorm"
        case 96, 99:  return "Severe thunderstorm"
        default:      return "Variable conditions"
        }
    }

    static func symbolName(for code: Int) -> String {
        switch code {
        case 0, 1:       return "sun.max.fill"
        case 2:          return "cloud.sun.fill"
        case 3:          return "cloud.fill"
        case 45, 48:     return "cloud.fog.fill"
        case 51...55:    return "cloud.drizzle.fill"
        case 56, 57:     return "cloud.sleet.fill"
        case 61...67:    return "cloud.rain.fill"
        case 71...77:    return "cloud.snow.fill"
        case 80...82:    return "cloud.heavyrain.fill"
        case 85, 86:     return "cloud.snow.fill"
        case 95...99:    return "cloud.bolt.rain.fill"
        default:         return "cloud.fill"
        }
    }

    /// Returns a SwiftUI Color name string for use in the view.
    static func symbolColor(for code: Int) -> String {
        switch code {
        case 0, 1:    return "yellow"
        case 2:       return "orange"
        case 3:       return "gray"
        case 45, 48:  return "gray"
        case 51...82: return "blue"
        case 71...77: return "cyan"
        case 85, 86:  return "cyan"
        case 95...99: return "purple"
        default:      return "secondary"
        }
    }

    static func clothingAdvice(temp: Double, code: Int) -> String {
        let rain   = (code >= 51 && code <= 67) || (code >= 80 && code <= 82)
        let snow   = (code >= 71 && code <= 77) || code == 85 || code == 86
        let storm  = code >= 95

        var base: String
        switch temp {
        case ..<32:  base = "A heavy coat and gloves are a must, I'm afraid"
        case 32..<46: base = "A proper warm coat is in order"
        case 46..<58: base = "A light jacket would serve you well"
        case 58..<72: base = "Comfortable attire is just right"
        case 72..<85: base = "Light clothing is the order of the day"
        default:     base = "Something very light — it's rather warm out there"
        }

        if storm   { return base + ", and I'd advise staying indoors if possible" }
        if snow    { return base + ", and do mind the footpaths" }
        if rain    { return base + ", and an umbrella is strongly advised" }
        return base
    }

    static func outfitEmoji(temp: Double, code: Int) -> String {
        let rain  = (code >= 51 && code <= 67) || (code >= 80 && code <= 82)
        let snow  = (code >= 71 && code <= 77) || code == 85 || code == 86
        if snow             { return "🧥" }
        if rain             { return "☂️" }
        if temp < 46        { return "🧥" }
        if temp < 60        { return "🧣" }
        return "👕"
    }
}
