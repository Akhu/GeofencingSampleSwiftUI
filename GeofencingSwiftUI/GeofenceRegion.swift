//
//  GeofenceRegion.swift
//  AnnecyPaysages
//
//  Created by Killian Sowa on 23/07/2021.
//

import CoreLocation

struct GeofenceRegion: Hashable {
    var region: CLCircularRegion
    var location: CLLocation
    
    init(region: CLCircularRegion, location: CLLocation) {
        self.region = region
        self.location = location
    }
}


