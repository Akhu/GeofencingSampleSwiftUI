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
    
    @Published var customRegionCoordinates: String = ""
    
    @Published var canLaunch: Bool = false
    
    @Published var isGeofencingRunning : Bool = false
    
    @Published var customRegion: CLCircularRegion?
    
    @Published var monitoredLocationAsAnnotationItem = [AnnotationItem]()
    
    var allRegions = Set<CLCircularRegion>()
    
    @Published var monitoredRegions = Set<CLCircularRegion>()
    
    @Published var radius: CLLocationDistance = 100
    
    private let maximumRegionsToMonitorAtSameTime = 5

    //Date actuelle
    
    private let defaults = UserDefaults.standard
    var locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    private var notificationManager = LocalNotificationEmitter()
    
    
    @Published var remainingTimeAsString: String?
    
    
    /**
     - ‼️ If walkdeadline is already passed then we stop the geofencing if there was one running on.
     - ‼️ If no deadline then we still stop geofencing in case of
     - ✅ If the walkdeadline exists and is still valid, then we just tell the app that the geofencing is running and adapt UI
     */
    private func checkDeadlineOnStartup() {
        if let walkDeadline = defaults.object(forKey: "walkDeadline") as? Date {
            if walkDeadline < Date() {
                self.stopGeofencing()
            } else {
                self.isGeofencingRunning = true
            }
        } else {
            self.stopGeofencing()
        }
    }
    
    override init() {
        super.init()

        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.delegate = self
        
        self.checkDeadlineOnStartup()
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
                        return CLCircularRegion(center: CLLocationCoordinate2DMake(latitude, longitude),
                                                 radius: self.radius,
                                                 identifier: "Custom Region")
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
            self.monitoredRegions = Set(allRegions
                                            .sorted(by: { currentLocation.distance(from: $0.center.toCLLocation() ) < currentLocation.distance(from: $1.center.toCLLocation() )})
                                            .prefix(maximumRegionsToMonitorAtSameTime))
            
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
        
        //ON veut démarrer avec les 20 geofences les plus proches de la position actuelle, il faut fail si la position est pas determinée
        
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
        UserDefaults.standard.set(nil, forKey: "walkDeadline")
        
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
    /**
     * Quand on entre dans une region on doit recalculer les les 20 points les plus proches, supprimer les plus loins, et monitorer de nouveaux les 20 plus proches
     */
    func updateRegionToMonitor(location: CLLocation) {
        monitoredRegions.forEach { regionMonitored in
            print("Monitored: \(regionMonitored.identifier)")
            consoleManager.print("Monitored: \(regionMonitored.identifier)")
        }
        
        let chunkedSortedRegionsCloser = allRegions
            .sorted(by: { location.distance(from: $0.center.toCLLocation() ) < location.distance(from: $1.center.toCLLocation()  )})
            .prefix(maximumRegionsToMonitorAtSameTime)
        
        chunkedSortedRegionsCloser.forEach { region in
            consoleManager.print("Closes region: \(region.identifier)")
            print("Closes region: \(region.identifier)")
        }
        
        let regionToKeepMonitoring = Set(chunkedSortedRegionsCloser).intersection(self.monitoredRegions)
        
        regionToKeepMonitoring.forEach { region in
            consoleManager.print("Intersect: \(region.identifier)")
            print("Intersect: \(region.identifier)")
        }
        
        let newRegionToMonitor = Set(chunkedSortedRegionsCloser).symmetricDifference(regionToKeepMonitoring)
        
        newRegionToMonitor.forEach { region in
            consoleManager.print("newRegionToMonitor: \(region.identifier)")
            print("newRegionToMonitor: \(region.identifier)")
        }
        
        let newList = newRegionToMonitor.union(regionToKeepMonitoring)
        let toRemove = Set(self.monitoredRegions).symmetricDifference(regionToKeepMonitoring)
        
        newList.forEach { region in
            consoleManager.print("newList: \(region.identifier)")
            print("newList: \(region.identifier)")
        }
        
        toRemove.forEach { region in
            consoleManager.print("toRemove: \(region.identifier)")
            print("toRemove: \(region.identifier)")
        }
        
        //Start Monitoring new Regions
        newRegionToMonitor.forEach { geoRegion in
            self.locationManager.startMonitoring(for: geoRegion)
        }
        
        //Stop Monitoring old Regions
        toRemove.forEach { geoRegion in
            if let regionToStopMonitor = self.locationManager.monitoredRegions.first(where: { $0.identifier == geoRegion.identifier })
            {
                self.locationManager.stopMonitoring(for: regionToStopMonitor)
            }
        }
        
        self.monitoredRegions = newList
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
        if let currentLocation = manager.location {
            self.updateRegionToMonitor(location: currentLocation)
        }
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
        
        if let currentLocation = manager.location {
            self.updateRegionToMonitor(location: currentLocation)
        }
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
