//
//  Reachability.swift
//  Reachability
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/11/12.
//
//
/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 Basic demonstration of how to use the SystemConfiguration Reachablity APIs.
 */

import Foundation
import SystemConfiguration


enum NetworkStatus: Int {
    case notReachable = 0
    case reachableViaWiFi
    case reachableViaWWAN
}

//MARK: IPv6 Support
//Reachability fully support IPv6.  For full details, see ReadMe.md.


let kReachabilityChangedNotification = "kNetworkReachabilityChangedNotification"



private func PrintReachabilityFlags(_ flags: SCNetworkReachabilityFlags, _ comment: String) {
    #if kShouldPrintReachabilityFlags
        
        NSLog("Reachability Flag Status: %@%@ %@%@%@%@%@%@%@ %@\n",
            flags.contains(.IsWWAN)		? "W" : "-",
            flags.contains(.Reachable)          ? "R" : "-",
            
            flags.contains(.TransientConnection)  ? "t" : "-",
            flags.contains(.ConnectionRequired)   ? "c" : "-",
            flags.contains(.ConnectionOnTraffic)  ? "C" : "-",
            flags.contains(.InterventionRequired) ? "i" : "-",
            flags.contains(.ConnectionOnDemand)   ? "D" : "-",
            flags.contains(.IsLocalAddress)       ? "l" : "-",
            flags.contains(.IsDirect)             ? "d" : "-",
            comment
        )
    #endif
}


private func  ReachabilityCallback(_ target: SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutableRawPointer?) {
    assert(info != nil, "info was NULL in ReachabilityCallback")
    assert(unsafeBitCast(info, to: NSObject.self) is Reachability, "info was wrong class in ReachabilityCallback")
    
    let noteObject = unsafeBitCast(info, to: Reachability.self)
    // Post a notification to notify the client that the network reachability changed.
    NotificationCenter.default.post(name: Notification.Name(rawValue: kReachabilityChangedNotification), object: noteObject)
}


//MARK: - Reachability implementation

@objc(Reachability)
class Reachability: NSObject {
    fileprivate var _reachabilityRef: SCNetworkReachability?
    
    /*!
    * Use to check the reachability of a given host name.
    */
    convenience init?(hostName: String) {
        if let reachability =  SCNetworkReachabilityCreateWithName(nil, hostName) {
            self.init()
            self._reachabilityRef = reachability
        } else {
            return nil
        }
    }
    
    
    /*!
    * Use to check the reachability of a given IP address.
    */
    convenience init?(address hostAddress: UnsafePointer<sockaddr>) {
        
        if let reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, hostAddress) {
            self.init()
            self._reachabilityRef = reachability
        } else {
            return nil
        }
    }
    
    
    
    /*!
    * Checks whether the default route is available. Should be used by applications that do not connect to a particular host.
    */
    convenience init?(forInternetConnection: ()) {
        let zeroAddress = UnsafeMutablePointer<sockaddr_in>.allocate(capacity: 1)
        bzero(zeroAddress, MemoryLayout<sockaddr_in>.size)
        zeroAddress.pointee.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.pointee.sin_family = sa_family_t(AF_INET)
        
        self.init(address: UnsafeRawPointer(zeroAddress).assumingMemoryBound(to: sockaddr.self))
        zeroAddress.deallocate(capacity: 1)
    }
    
    
    //MARK: reachabilityForLocalWiFi
    //reachabilityForLocalWiFi has been removed from the sample.  See ReadMe.md for more information.
    //convenience init?(forLocalWiFi: ())
    
    
    //MARK: - Start and stop notifier
    
    /*!
    * Start listening for reachability notifications on the current run loop.
    */
    @discardableResult
    func startNotifier() -> Bool {
        var returnValue: Bool = false
        var context = SCNetworkReachabilityContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        
        if SCNetworkReachabilitySetCallback(_reachabilityRef!, ReachabilityCallback, &context) {
            if SCNetworkReachabilityScheduleWithRunLoop(_reachabilityRef!, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue) {
                returnValue = true
            }
        }
        
        return returnValue
    }
    
    
    func stopNotifier() {
        if _reachabilityRef != nil {
            SCNetworkReachabilityUnscheduleFromRunLoop(_reachabilityRef!, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        }
    }
    
    
    deinit {
        self.stopNotifier()
    }
    
    
    //MARK: - Network Flag Handling
    
    func networkStatusForFlags(_ flags: SCNetworkReachabilityFlags) -> NetworkStatus {
        PrintReachabilityFlags(flags, "networkStatusForFlags")
        if !flags.contains(.reachable) {
            // The target host is not reachable.
            return .notReachable
        }
        
        var returnValue = NetworkStatus.notReachable
        
        if !flags.contains(.connectionRequired) {
            /*
            If the target host is reachable and no connection is required then we'll assume (for now) that you're on Wi-Fi...
            */
            returnValue = .reachableViaWiFi
        }
        
        if flags.contains(.connectionOnDemand) || flags.contains(.connectionOnTraffic) {
            /*
            ... and the connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs...
            */
            
            if !flags.contains(.interventionRequired) {
                /*
                ... and no [user] intervention is needed...
                */
                returnValue = .reachableViaWiFi
            }
        }
        
        if flags.contains(.isWWAN) {
            /*
            ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.
            */
            returnValue = .reachableViaWWAN
        }
        
        return returnValue
    }
    
    
    /*!
    * WWAN may be available, but not active until a connection has been established. WiFi may require a connection for VPN on Demand.
    */
    var connectionRequired: Bool {
        assert(_reachabilityRef != nil, "connectionRequired called with NULL reachabilityRef")
        var flags: SCNetworkReachabilityFlags = []
        
        if SCNetworkReachabilityGetFlags(_reachabilityRef!, &flags) {
            return flags.contains(.connectionRequired)
        }
        
        return false
    }
    
    
    var currentReachabilityStatus: NetworkStatus {
        assert(_reachabilityRef != nil, "currentNetworkStatus called with NULL SCNetworkReachabilityRef")
        var returnValue: NetworkStatus = .notReachable
        var flags: SCNetworkReachabilityFlags = []
        
        if SCNetworkReachabilityGetFlags(_reachabilityRef!, &flags) {
            returnValue = self.networkStatusForFlags(flags)
        }
        
        return returnValue
    }
    
    
}
