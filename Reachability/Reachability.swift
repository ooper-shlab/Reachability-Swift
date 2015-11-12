//
//  Reachability.swift
//  Reachability
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/11/12.
//
//
/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 Basic demonstration of how to use the SystemConfiguration Reachablity APIs.
 */

import Foundation
import SystemConfiguration


enum NetworkStatus: Int {
    case NotReachable = 0
    case ReachableViaWiFi
    case ReachableViaWWAN
}


let kReachabilityChangedNotification = "kNetworkReachabilityChangedNotification"



private func PrintReachabilityFlags(flags: SCNetworkReachabilityFlags, _ comment: String) {
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


private func  ReachabilityCallback(target: SCNetworkReachabilityRef, flags: SCNetworkReachabilityFlags, info: UnsafeMutablePointer<Void>) {
    assert(info != nil, "info was NULL in ReachabilityCallback")
    assert(unsafeBitCast(info, NSObject.self) is Reachability, "info was wrong class in ReachabilityCallback")
    
    let noteObject = unsafeBitCast(info, Reachability.self)
    // Post a notification to notify the client that the network reachability changed.
    NSNotificationCenter.defaultCenter().postNotificationName(kReachabilityChangedNotification, object: noteObject)
}


//MARK: - Reachability implementation

@objc(Reachability)
class Reachability: NSObject {
    private var _alwaysReturnLocalWiFiStatus = false //default is NO
    private var _reachabilityRef: SCNetworkReachability?
    
    /*!
    * Use to check the reachability of a given host name.
    */
    convenience init?(hostName: String) {
        if let reachability =  SCNetworkReachabilityCreateWithName(nil, hostName) {
            self.init()
            self._reachabilityRef = reachability
            self._alwaysReturnLocalWiFiStatus = false
        } else {
            return nil
        }
    }
    
    
    /*!
    * Use to check the reachability of a given IP address.
    */
    convenience init?(address hostAddress: UnsafePointer<sockaddr_in>) {
        
        if let reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, UnsafePointer(hostAddress)) {
            self.init()
            self._reachabilityRef = reachability
            self._alwaysReturnLocalWiFiStatus = false
        } else {
            return nil
        }
    }
    
    
    
    /*!
    * Checks whether the default route is available. Should be used by applications that do not connect to a particular host.
    */
    convenience init?(forInternetConnection: ()) {
        var zeroAddress = sockaddr_in()
        bzero(&zeroAddress, sizeofValue(zeroAddress))
        zeroAddress.sin_len = UInt8(sizeofValue(zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        self.init(address: &zeroAddress)
    }
    
    
    /*!
    * Checks whether a local WiFi connection is available.
    */
    convenience init?(forLocalWiFi: ()) {
        var localWifiAddress = sockaddr_in()
        bzero(&localWifiAddress, sizeofValue(localWifiAddress))
        localWifiAddress.sin_len = UInt8(sizeofValue(localWifiAddress))
        localWifiAddress.sin_family = sa_family_t(AF_INET)
        
        // IN_LINKLOCALNETNUM is defined in <netinet/in.h> as 169.254.0.0.
        let IN_LINKLOCALNETNUM: UInt32 = 0xA9_FE_00_00
        localWifiAddress.sin_addr.s_addr = UInt32(bigEndian: IN_LINKLOCALNETNUM)
        
        self.init(address: &localWifiAddress)
        self._alwaysReturnLocalWiFiStatus = true
        
    }
    
    
    //MARK: - Start and stop notifier
    
    /*!
    * Start listening for reachability notifications on the current run loop.
    */
    func startNotifier() -> Bool {
        var returnValue: Bool = false
        var context = SCNetworkReachabilityContext(version: 0, info: UnsafeMutablePointer(unsafeAddressOf(self)), retain: nil, release: nil, copyDescription: nil)
        
        if SCNetworkReachabilitySetCallback(_reachabilityRef!, ReachabilityCallback, &context) {
            if SCNetworkReachabilityScheduleWithRunLoop(_reachabilityRef!, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode) {
                returnValue = true
            }
        }
        
        return returnValue
    }
    
    
    func stopNotifier() {
        if _reachabilityRef != nil {
            SCNetworkReachabilityUnscheduleFromRunLoop(_reachabilityRef!, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode)
        }
    }
    
    
    deinit {
        self.stopNotifier()
    }
    
    
    //MARK: - Network Flag Handling
    
    func localWiFiStatusForFlags(flags: SCNetworkReachabilityFlags) -> NetworkStatus {
        PrintReachabilityFlags(flags, "localWiFiStatusForFlags")
        var returnValue = NetworkStatus.NotReachable
        
        if flags.contains(.Reachable) && flags.contains(.IsDirect) {
            returnValue = .ReachableViaWiFi
        }
        
        return returnValue
    }
    
    
    func networkStatusForFlags(flags: SCNetworkReachabilityFlags) -> NetworkStatus {
        PrintReachabilityFlags(flags, "networkStatusForFlags")
        if !flags.contains(.Reachable) {
            // The target host is not reachable.
            return .NotReachable
        }
        
        var returnValue = NetworkStatus.NotReachable
        
        if !flags.contains(.ConnectionRequired) {
            /*
            If the target host is reachable and no connection is required then we'll assume (for now) that you're on Wi-Fi...
            */
            returnValue = .ReachableViaWiFi
        }
        
        if flags.contains(.ConnectionOnDemand) || flags.contains(.ConnectionOnTraffic) {
            /*
            ... and the connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs...
            */
            
            if !flags.contains(.InterventionRequired) {
                /*
                ... and no [user] intervention is needed...
                */
                returnValue = .ReachableViaWiFi
            }
        }
        
        if flags.contains(.IsWWAN) {
            /*
            ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.
            */
            returnValue = .ReachableViaWWAN
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
            return flags.contains(.ConnectionRequired)
        }
        
        return false
    }
    
    
    var currentReachabilityStatus: NetworkStatus {
        assert(_reachabilityRef != nil, "currentNetworkStatus called with NULL SCNetworkReachabilityRef")
        var returnValue: NetworkStatus = .NotReachable
        var flags: SCNetworkReachabilityFlags = []
        
        if SCNetworkReachabilityGetFlags(_reachabilityRef!, &flags) {
            if _alwaysReturnLocalWiFiStatus {
                returnValue = self.localWiFiStatusForFlags(flags)
            } else {
                returnValue = self.networkStatusForFlags(flags)
            }
        }
        
        return returnValue
    }
    
    
}