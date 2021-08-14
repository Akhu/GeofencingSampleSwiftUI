//
//  ContentView.swift
//  GeofencingSwiftUI
//
//  Created by Anthony Da cruz on 09/08/2021.
//

import SwiftUI
import CoreLocation


//Impérial 45.90321919886301, 6.143944298920628
//Jardin Botanic, 45.90399263666884, 6.141582419475836
//Debut du paquier, 45.90324336895755, 6.1367544600225115
//Sculpture Paquier, 45.90176897379019, 6.134218913041331
//Oeuvre JE1, 45.89971442362796, 6.1307802944378835
//Oeuvre JE2, 45.899061785901296, 6.13196123416028
//Oeuvre JE3, 45.89993196783216, 6.129390953588006

let rawRegions = [
    ("Pont des amours",45.91044837855673, 6.143521781870996),
    ("Impérial",45.90321919886301, 6.143944298920628),
    ("Debut du paquier", 45.90324336895755, 6.1367544600225115),
    ("Sculpture Paquier", 45.90176897379019, 6.134218913041331),
    ("Oeuvre JE1", 45.89971442362796, 6.1307802944378835),
    ("Oeuvre JE2", 45.899061785901296, 6.13196123416028),
    ("Oeuvre JE3", 45.89993196783216, 6.129390953588006),
    ("Oeuvre JE4", 45.89846507020296, 6.130153050894414),
    ("Oeuvre JE5", 45.89912813616961, 6.130445031782466),
    ("Lotus", 45.899491749638024, 6.128739248690086),
    ("Vieille Ville 1", 45.89948105514886, 6.1256503982523345)
]

let regions = rawRegions.map({ (identifier, lat, lon) in
    GeofenceRegion(region:
                CLCircularRegion(center: CLLocationCoordinate2DMake(lat, lon),
                                 radius: 80,
                                 identifier: identifier),
               location: CLLocation(latitude: lat,
                                    longitude: lon))
})

struct ContentView: View {
    
    @EnvironmentObject var geofenceState: GeofenceState
     
    @State var latitude: String = ""
    @State var longitude : String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Map")){
                    MapKitWithLocation(annotationsItems: annotationItemsFromRawRegion)
                        .frame(height: 400, alignment: .center)
                }
                Section(header: Text("Launching")) {
                    Toggle(isOn: $geofenceState.canLaunch, label: {
                        Text("CanLaunch")
                    }).onChange(of: geofenceState.canLaunch, perform: { value in
                        geofenceState.loadPermissions()
                    })
                    
                    Button(action: {
                        if geofenceState.notificationPermissionState == .denied {
                            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString + Bundle.main.bundleIdentifier!)!, options: [:], completionHandler: nil)
                        }
                        
                        if geofenceState.notificationPermissionState == .notDetermined {
                            geofenceState.askForNotificationPermission()
                        }
                        
                        if geofenceState.localizationPermissionState == .denied {
                            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString + Bundle.main.bundleIdentifier!)!, options: [:], completionHandler: nil)
                        }
                        
                        if geofenceState.localizationPermissionState == .notDetermined {
                            geofenceState.askForLocalizationPermission()
                        }
                        
                    }, label: {
                        if geofenceState.notificationPermissionState != .authorized {
                            Text("Ask for Permissions")
                        } else {
                            Text("Permissions Granted !")
                        }
                    })
                    .onAppear {
                        geofenceState.loadPermissions()
                    }
                }
                Section(header: Text("Start Geofencing")) {
                    if geofenceState.canLaunch {
                        DisclosureGroup("Add custom region?") {
                            Group {
                                TextField("Coordinates from Maps", text: $geofenceState.customRegionCoordinates)
                            }
                        }
                        Button(action: {
                            geofenceState.isGeofencingRunning ? geofenceState.stopGeofencing(): geofenceState.startGeofencing(regionsToMonitor: regions)
                        }, label: {
                            Text(geofenceState.isGeofencingRunning ? "Stop monitoring" : "Start Monitoring")
                        })
                    }
                }
                
                Section(header: Text("Permissions State")) {
                    Group {
                        Text("Location permission State:\n \(geofenceState.localizationPermissionState.toString())")
                        Text("Notification permission State:\n \(geofenceState.notificationPermissionState.toString())")
                    }
                }
                if geofenceState.isGeofencingRunning {
                    Section(header: Text("Geofences monitored")) {
                        
                        List {
                            ForEach(Array(geofenceState.monitoredRegions), id: \.region.identifier) { region in
                                Text("[Region] : \(region.region.identifier)")
                            }
                        }
                        
                    }
                }
            }
            .environmentObject(geofenceState)
            .navigationTitle("Geofence Tester")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
