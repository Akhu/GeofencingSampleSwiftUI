//
//  Extensions.swift
//  GeofencingSwiftUI
//
//  Created by Anthony Da cruz on 09/08/2021.
//

import Foundation
import CoreLocation
import UserNotifications
import Combine

extension CLLocationManager {
    func getLocalizationPermissionStatus() -> Future<CLAuthorizationStatus, Never> {
        return Future { promise in
            promise(.success(self.authorizationStatus))
        }
    }
    
    
}


extension UNAuthorizationStatus {
    func toString() -> String {
        switch self {
        case .authorized:
            return "Authorized"
        case .ephemeral:
            return "Ephemeral (AppClip)"
        case .notDetermined:
            return "Not determined"
        case .provisional:
            return "Provisional"
        case .denied:
            return "denied"
        @unknown default:
            return "Unknown case"
        }
    }
}

extension CLAuthorizationStatus {
    func toString() -> String {
        switch self {
        case .authorizedAlways:
            return "Authorized always"
        case .authorizedWhenInUse:
            return "Authorized when in use"
        case .notDetermined:
            return "Not determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "denied"
        @unknown default:
            return "Unknown case"
        }
    }
}


extension UNUserNotificationCenter {
    func getNotificationSettings() -> Future<UNNotificationSettings,
                                             Never> {
        return Future { promise in
            self.getNotificationSettings { settings in promise(.success(settings))
            } }
    }
    func requestAuthorization(options: UNAuthorizationOptions) ->
    Future<Bool, Error> { return Future { promise in
        self.requestAuthorization(options: options) { result, error in if let error = error {
            promise(.failure(error)) } else {
                promise(.success(result))
            }
        } }
    } }
