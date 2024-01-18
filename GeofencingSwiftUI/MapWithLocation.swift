//
//  MapKitWithLocation.swift
//  SwiftUIPlayground
//
//  Created by Anthony Da cruz on 13/08/2021.
//

import SwiftUI
import CoreLocation
import MapKit

struct AnnotationItem: Identifiable {
    var id: String
    var lat: Double
    var lon: Double
    var isMonitored: Bool = false
}

var annotationItemsFromRawRegion : [AnnotationItem] {
    get {
        return rawRegions.map({ AnnotationItem(id: $0.0, lat: $0.1, lon: $0.2) })
    }
}

struct MapKitWithLocation: View {
    
    @EnvironmentObject var geofenceState:GeofenceState
    
    // Marks on map
    var annotationsItems: [AnnotationItem]
    
    @State private var userTrackingMode: MapUserTrackingMode = .none
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(
            latitude: 25.7617,
            longitude: 80.1918
        ),
        span: MKCoordinateSpan(
            latitudeDelta: 10,
            longitudeDelta: 10
        )
    )
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            
            Map(
                coordinateRegion: $region,
                interactionModes: MapInteractionModes.all,
                showsUserLocation: true,
                userTrackingMode: $userTrackingMode,
                annotationItems: annotationsItems
            ) { item -> MapAnnotation<AnyView> in
                let monitored = geofenceState.monitoredLocationAsAnnotationItem.contains{ $0.id == item.id }
                return MapAnnotation(
                    coordinate: CLLocationCoordinate2D(latitude: item.lat, longitude: item.lon),
                    anchorPoint: CGPoint(x: 0.5, y: 0.5)
                ) {
                    AnyView(Image(systemName: monitored ? "circle.fill" : "circle.dashed")
                       .frame(width: 5, height: 5, alignment: .center)
                       .foregroundColor(monitored ? .blue : .orange))
                }
            }
            Button(action: {
                if geofenceState.notificationPermissionState == .denied {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString + Bundle.main.bundleIdentifier!)!, options: [:], completionHandler: nil)
                } else {
                    geofenceState.askForLocalizationPermission()
                    withAnimation(.spring()) {
                        centerRegionOnUser()
                    }
                }
            }, label: {
                Image(systemName: "location.fill.viewfinder")
                    .foregroundColor(.white)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous))
            })
            .padding()
            .frame(alignment: .topLeading)
        }.onReceive(geofenceState.$localizationPermissionState, perform: { _ in
            centerRegionOnUser()
        })
    }
    
    func centerRegionOnUser() {
        if geofenceState.localizationPermissionState != .denied || geofenceState.localizationPermissionState == .notDetermined {
            userTrackingMode = .follow
            if let currentLocation = geofenceState.locationManager.location {
                region = MKCoordinateRegion(center: currentLocation.coordinate, span: MKCoordinateSpan(
                    latitudeDelta: 10,
                    longitudeDelta: 10
                ))
            }
        }
    }
}

struct MapKitWithLocation_Previews: PreviewProvider {
    static var previews: some View {
        MapKitWithLocation( annotationsItems: annotationItemsFromRawRegion)
            .environmentObject(GeofenceState())
    }
}
