//
//  LocalNotificationEmitter.swift
//  GeofencingSwiftUI
//
//  Created by Anthony Da cruz on 09/08/2021.
//  Created by Killian Sowa on 13/07/2021.
//

import UserNotifications

class LocalNotificationEmitter
{
    var notifications = [LocalNotification]()
    
    func launchNotification(_ notification: LocalNotification) {
        consoleManager.print("will launch notification \(notification.id)")
        print("will launch notification \(notification.id)")
        let content = UNMutableNotificationContent()
        
        content.title = notification.title
        content.body = notification.body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: notification.triggerDelay, repeats: false)
        
        let request = UNNotificationRequest(identifier: notification.id, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            guard error == nil else { return }
            
            print("Notification scheduled! --- ID = \(notification.id)")
        }
    }
}

struct LocalNotification {
    var id: String
    var title: String
    var body: String
    var triggerDelay: TimeInterval
}
