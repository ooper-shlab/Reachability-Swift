//
//  APLViewController.swift
//  Reachability
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/11/12.
//
//
/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 Application delegate class.
 */


import UIKit

@objc(APLViewController)
class APLViewController: UIViewController {
    
    
    @IBOutlet fileprivate weak var summaryLabel: UILabel!
    
    @IBOutlet fileprivate weak var remoteHostLabel: UITextField!
    @IBOutlet fileprivate weak var remoteHostImageView: UIImageView!
    @IBOutlet fileprivate weak var remoteHostStatusField: UITextField!
    
    @IBOutlet fileprivate weak var internetConnectionImageView: UIImageView!
    @IBOutlet fileprivate weak var internetConnectionStatusField: UITextField!
    
    fileprivate var hostReachability: Reachability!
    fileprivate var internetReachability: Reachability!
    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.summaryLabel.isHidden = true
        
        /*
        Observe the kNetworkReachabilityChangedNotification. When that notification is posted, the method reachabilityChanged will be called.
        */
        NotificationCenter.default.addObserver(self, selector: #selector(APLViewController.reachabilityChanged(_:)), name: NSNotification.Name(rawValue: kReachabilityChangedNotification), object: nil)
        
        //Change the host name here to change the server you want to monitor.
        let remoteHostName = "www.apple.com"
        let remoteHostLabelFormatString = NSLocalizedString("Remote Host: %@", comment: "Remote host label format string")
        self.remoteHostLabel.text = String(format: remoteHostLabelFormatString, remoteHostName)
        
        self.hostReachability = Reachability(hostName: remoteHostName)
        self.hostReachability.startNotifier()
        self.updateInterfaceWithReachability(self.hostReachability)
        
        self.internetReachability = Reachability(forInternetConnection: ())
        self.internetReachability.startNotifier()
        self.updateInterfaceWithReachability(self.internetReachability)
        
    }
    
    
    /*!
    * Called by Reachability whenever status changes.
    */
    @objc func reachabilityChanged(_ note: Notification) {
        let curReach = note.object as! Reachability
        self.updateInterfaceWithReachability(curReach)
    }
    
    
    fileprivate func updateInterfaceWithReachability(_ reachability: Reachability) {
        if reachability === self.hostReachability {
            self.configureTextField(self.remoteHostStatusField, imageView: self.remoteHostImageView, reachability: reachability)
            let netStatus = reachability.currentReachabilityStatus
            let connectionRequired = reachability.connectionRequired
            
            self.summaryLabel.isHidden = (netStatus != .reachableViaWWAN)
            var baseLabelText = ""
            
            if connectionRequired {
                baseLabelText = NSLocalizedString("Cellular data network is available.\nInternet traffic will be routed through it after a connection is established.", comment: "Reachability text if a connection is required")
            } else {
                baseLabelText = NSLocalizedString("Cellular data network is active.\nInternet traffic will be routed through it.", comment: "Reachability text if a connection is not required")
            }
            self.summaryLabel.text = baseLabelText
        }
        
        if reachability === self.internetReachability {
            self.configureTextField(self.internetConnectionStatusField, imageView: self.internetConnectionImageView, reachability: reachability)
        }
        
    }
    
    
    fileprivate func configureTextField(_ textField: UITextField, imageView: UIImageView, reachability: Reachability) {
        let netStatus = reachability.currentReachabilityStatus
        var connectionRequired = reachability.connectionRequired
        var statusString = ""
        
        switch netStatus {
        case .notReachable:
            statusString = NSLocalizedString("Access Not Available", comment: "Text field text for access is not available")
            imageView.image = UIImage(named: "stop-32.png")
            /*
            Minor interface detail- connectionRequired may return YES even when the host is unreachable. We cover that up here...
            */
            connectionRequired = false
            
        case .reachableViaWWAN:
            statusString = NSLocalizedString("Reachable WWAN", comment: "")
            imageView.image = UIImage(named: "WWAN5.png")
        case .reachableViaWiFi:
            statusString = NSLocalizedString("Reachable WiFi", comment: "")
            imageView.image = UIImage(named: "Airport.png")
        }
        
        if connectionRequired {
            let connectionRequiredFormatString = NSLocalizedString("%@, Connection Required", comment: "Concatenation of status string with connection requirement")
            statusString = String(format: connectionRequiredFormatString, statusString)
        }
        textField.text = statusString
    }
    
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: kReachabilityChangedNotification), object: nil)
    }
    
    
}
