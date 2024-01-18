//
//  GeofencingState.swift
//
//  Created by Anthony Da cruz on 08/08/2021.
//

import Foundation
import SwiftUI
import Combine
import NotificationCenter
import CoreLocation

//What I need to make geofence works ?
/**
 - User permissions (Ask, Know the state, Send to settings)
 - Dispense to my views the state of the geofence feeature for the user
 - Ability to create notification
 - Monitor time of the geofence feature
 - Start - Stop Geofencing
 */
class GeofenceState: NSObject, ObservableObject {
    
    @Published var notificationPermissionState : UNAuthorizationStatus = .notDetermined
    @Published var localizationPermissionState : CLAuthorizationStatus = .notDetermined
    
    // Custom region
    @Published var customRegionCoordinates: String = ""
    @Published var customRegion: CLCircularRegion?
    
    // Permissions ok ?
    @Published var canLaunch: Bool = false
    
    
    @Published var isGeofencingRunning : Bool = false
    
    @Published var monitoredLocationAsAnnotationItem = [AnnotationItem]()
    
    var allRegions = Set<CLCircularRegion>()
    @Published var monitoredRegions = Set<CLCircularRegion>()
    
    @Published var radius: CLLocationDistance = 100
    
    var locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    private var notificationManager = LocalNotificationEmitter()
    
    
    override init() {
        super.init()

        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.delegate = self
        
        print("MonitoredRegions: \(self.locationManager.monitoredRegions.count)")
        
        $monitoredRegions
            .compactMap { regions in
                regions.map { region in
                    AnnotationItem(id: region.identifier, lat: region.center.latitude, lon: region.center.longitude)
                }
            }
            .assign(to: \.monitoredLocationAsAnnotationItem, on: self)
            .store(in: &cancellables)
        
        $customRegionCoordinates
            .compactMap { coordinatesString -> CLCircularRegion? in
                let trimmedString = coordinatesString.trimmingCharacters(in: CharacterSet(charactersIn: "( )"))
                let splited = trimmedString.split(separator: ",")
                if splited.count > 0 {
                    if let latitude = Double(String(splited[0])), let longitude = Double(String(splited[1])) {
                        return CLCircularRegion(center: CLLocationCoordinate2DMake(latitude, longitude),radius: self.radius, identifier: "Custom Region")
                        }
                        return nil
                    }
                    return nil
                }
                .assign(to: \.customRegion, on: self)
                .store(in: &cancellables)
        
        Publishers.CombineLatest($notificationPermissionState, $localizationPermissionState)
            .map { (notificationStatus, localizationStatus) -> Bool in
                if notificationStatus == .notDetermined || notificationStatus == .denied {
                    return false
                }
                
                if localizationStatus == .denied || localizationStatus == .notDetermined {
                    return false
                }
                
                return true
            }
            .receive(on: DispatchQueue.main)
            .assign(to: \.canLaunch, on: self)
            .store(in: &cancellables)
        
        loadPermissions()
    }
    private func startMonitoringRegions(){
        
        self.monitoredRegions.removeAll()
        if let currentLocation = locationManager.location {
            self.monitoredRegions = allRegions
            
            self.monitoredRegions.forEach { region in
                region
                    .notifyOnEntry = true
                region
                    .notifyOnExit = true
                locationManager
                    .startMonitoring(for:region)
            }
            
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            //Todo: Handle location error here
        }
    }
    
    /**
     * Start geofencing with an array of regions to monitor
     */
    func startGeofencing(regionsToMonitor regions: [CLCircularRegion]) {
        locationManager.startUpdatingLocation()
        
        if let unwrappedCustomRegion = self.customRegion {
            
            unwrappedCustomRegion.notifyOnEntry = true
            unwrappedCustomRegion.notifyOnExit = true
            
            self.allRegions.insert(unwrappedCustomRegion)
            
            locationManager.startMonitoring(for: unwrappedCustomRegion)
        }
        
        self.allRegions = self.allRegions.union(Set(regions))
        self.startMonitoringRegions()
    
        isGeofencingRunning = true
    }
    
    func stopGeofencing() {
    
        locationManager.stopUpdatingLocation()
        
        for geofenceRegion in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: geofenceRegion)
            consoleManager.print("Stop monitoring for region: \(geofenceRegion.identifier)")
        }
        
        monitoredRegions.removeAll()
        allRegions.removeAll()
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        isGeofencingRunning = false
        
        self.monitoredLocationAsAnnotationItem.removeAll()
    }
}

extension GeofenceState: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        loadPermissions()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        consoleManager.print("Location Manager failed with the following error: \(error)")
        print("Location Manager failed with the following error: \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        consoleManager.print("Exited region \(region.identifier)")
        print("Exited region \(region.identifier)")
    }
    
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        consoleManager.print("Start monitoring for region \(region.identifier)")
        print("Start monitoring for region \(region.identifier)")
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        consoleManager.print(["Monitoring did failed for region \(region?.identifier)", error.localizedDescription])
        print(["Monitoring did failed for region \(region?.identifier)", error.localizedDescription])
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        consoleManager.print("did entered region \(region.identifier)")
        print("did entered region \(region.identifier)")
        let notification = LocalNotification(
            id: region.identifier,
            title: "⭐️ Region monitored reached !",
            body: "You have reached a geofence: \(region.identifier)",
            triggerDelay: 1
        )
        notificationManager.launchNotification(notification)
    }
}

//Permissions related code
extension GeofenceState {
    func loadPermissions(){
        UNUserNotificationCenter.current()
            .getNotificationSettings()
            .flatMap { settings -> AnyPublisher<UNAuthorizationStatus, Never> in
                return Just(settings.authorizationStatus).eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .assign(to: \.notificationPermissionState, on: self)
            .store(in: &cancellables)
        
        locationManager
            .getLocalizationPermissionStatus()
            .assign(to: \.localizationPermissionState, on: self)
            .store(in: &cancellables)
    }
    
    func askForLocalizationPermission() {
        self.locationManager.requestAlwaysAuthorization()
    }
    
    func askForNotificationPermission(){
        UNUserNotificationCenter.current().getNotificationSettings()
            .flatMap { settings -> AnyPublisher<UNAuthorizationStatus, Never> in
                switch settings.authorizationStatus {
                case .notDetermined:
                    return UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                        .replaceError(with: false)
                        .map({ askingResult in
                            if askingResult {
                                return UNAuthorizationStatus.authorized
                            } else {
                                return UNAuthorizationStatus.denied
                            }
                        })
                        .eraseToAnyPublisher()
                default:
                    return Just(settings.authorizationStatus)
                        .eraseToAnyPublisher()
                }
            }.receive(on: DispatchQueue.main)
            .assign(to: \.notificationPermissionState, on: self)
            .store(in: &cancellables)
    }
    
    func askForAllPermissions(){
        self.askForNotificationPermission()
        self.askForLocalizationPermission()
    }
}
