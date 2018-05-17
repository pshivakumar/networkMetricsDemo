//
//  NetReachalility.swift
//  networkMetricsDemo
//
//  Created by shiva  kumar on 21/08/17.
//  Copyright © 2017 shiva  kumar. All rights reserved.
//

import SystemConfiguration
import Foundation

public enum ReachabilityError: Error {
    case failedToCreateWithAddress(sockaddr_in)
    case failedToCreateWithHostname(String)
    case unableToSetCallback
    case unableToSetDispatchQueue
}

public let ReachabilityChangedNotification = "ReachabilityChangedNotification"

func callback(_ reachability:SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutableRawPointer) {
    let reachability = Unmanaged<CoreDataNetworkReachability>.fromOpaque(info).takeUnretainedValue()
    
    DispatchQueue.main.async {
        reachability.reachabilityChanged(flags)
    }
}


open class CoreDataNetworkReachability: NSObject {
    
    public typealias NetworkReachable = (CoreDataNetworkReachability) -> ()
    public typealias NetworkUnreachable = (CoreDataNetworkReachability) -> ()
    
    public enum NetworkStatus: CustomStringConvertible {
        
        case notReachable, reachableViaWiFi, reachableViaWWAN
        
        public var description: String {
            switch self {
            case .reachableViaWWAN:
                return "Cellular"
            case .reachableViaWiFi:
                return "WiFi"
            case .notReachable:
                return "No Connection"
            }
        }
    }
    
    // MARK: - *** Public properties ***
    open var whenReachable: NetworkReachable?
    open var whenUnreachable: NetworkUnreachable?
    open var reachableOnWWAN: Bool
    open var notificationCenter = NotificationCenter.default
    
    open var currentReachabilityStatus: NetworkStatus {
        if isReachable() {
            if isReachableViaWiFi() {
                return .reachableViaWiFi
            }
            if isRunningOnDevice {
                return .reachableViaWWAN
            }
        }
        return .notReachable
    }
    
    open var currentReachabilityString: String {
        return "\(currentReachabilityStatus)"
    }
    
    fileprivate var previousFlags: SCNetworkReachabilityFlags?
    
    // MARK: - *** Initialisation methods ***
    
    required public init(reachabilityRef: SCNetworkReachability) {
        reachableOnWWAN = true
        self.reachabilityRef = reachabilityRef
    }
    
    public convenience init(hostname: String) throws {
        
        let nodename = (hostname as NSString).utf8String
        guard let ref = SCNetworkReachabilityCreateWithName(nil, nodename!) else { throw ReachabilityError.failedToCreateWithHostname(hostname) }
        
        self.init(reachabilityRef: ref)
    }
    
    open class func reachabilityForInternetConnection() throws -> CoreDataNetworkReachability {
        
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let ref = withUnsafePointer(to: &zeroAddress, {
            //SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0))
            return $0.withMemoryRebound(to: sockaddr.self, capacity: MemoryLayout<sockaddr>.size) {
                return SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
            
        }) else { throw ReachabilityError.failedToCreateWithAddress(zeroAddress) }
        
        return CoreDataNetworkReachability(reachabilityRef: ref)
    }
    
    open class func reachabilityForLocalWiFi() throws -> CoreDataNetworkReachability {
        
        var localWifiAddress: sockaddr_in = sockaddr_in(sin_len: __uint8_t(0), sin_family: sa_family_t(0), sin_port: in_port_t(0), sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        localWifiAddress.sin_len = UInt8(MemoryLayout.size(ofValue: localWifiAddress))
        localWifiAddress.sin_family = sa_family_t(AF_INET)
        
        // IN_LINKLOCALNETNUM is defined in <netinet/in.h> as 169.254.0.0
        let address: UInt32 = 0xA9FE0000
        localWifiAddress.sin_addr.s_addr = in_addr_t(address.bigEndian)
        
        guard let ref = withUnsafePointer(to: &localWifiAddress, {
            //SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0))
            return $0.withMemoryRebound(to: sockaddr.self, capacity: MemoryLayout<sockaddr>.size) {
                return SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else { throw ReachabilityError.failedToCreateWithAddress(localWifiAddress) }
        
        return CoreDataNetworkReachability(reachabilityRef: ref)
    }
    
    // MARK: - *** Notifier methods ***
    open func startNotifier() throws {
        
        guard !notifierRunning else { return }
        
        var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        if !SCNetworkReachabilitySetCallback(reachabilityRef!, {(_, flags, info) in
            let reachability = Unmanaged<CoreDataNetworkReachability>.fromOpaque(info!).takeUnretainedValue()
            DispatchQueue.main.async {
                reachability.reachabilityChanged(flags)
            }}, &context) {
            stopNotifier()
            throw ReachabilityError.unableToSetCallback
        }
        
        if !SCNetworkReachabilitySetDispatchQueue(reachabilityRef!, reachabilitySerialQueue) {
            stopNotifier()
            throw ReachabilityError.unableToSetDispatchQueue
        }
        
        // Perform an intial check
        reachabilitySerialQueue.async { () -> Void in
            let flags = self.reachabilityFlags
            self.reachabilityChanged(flags)
        }
        
        notifierRunning = true
    }
    
    open func stopNotifier() {
        defer { notifierRunning = false }
        guard let reachabilityRef = reachabilityRef else { return }
        
        SCNetworkReachabilitySetCallback(reachabilityRef, nil, nil)
        SCNetworkReachabilitySetDispatchQueue(reachabilityRef, nil)
    }
    
    // MARK: - *** Connection test methods ***
    open func isReachable() -> Bool {
        let flags = reachabilityFlags
        return isReachableWithFlags(flags)
    }
    
    open func isReachableViaWWAN() -> Bool {
        
        let flags = reachabilityFlags
        
        // Check we're not on the simulator, we're REACHABLE and check we're on WWAN
        return isRunningOnDevice && isReachable(flags) && isOnWWAN(flags)
    }
    
    open func isReachableViaWiFi() -> Bool {
        
        let flags = reachabilityFlags
        
        // Check we're reachable
        if !isReachable(flags) {
            return false
        }
        
        // Must be on WiFi if reachable but not on an iOS device (i.e. simulator)
        if !isRunningOnDevice {
            return true
        }
        
        // Check we're NOT on WWAN
        return !isOnWWAN(flags)
    }
    
    // MARK: - *** Private methods ***
    fileprivate var isRunningOnDevice: Bool = {
        #if (arch(i386) || arch(x86_64)) && os(iOS)
            return false
        #else
            return true
        #endif
    }()
    
    fileprivate var notifierRunning = false
    fileprivate var reachabilityRef: SCNetworkReachability?
    fileprivate let reachabilitySerialQueue = DispatchQueue(label: "uk.co.ashleymills.reachability", attributes: [])
    
    fileprivate func reachabilityChanged(_ flags: SCNetworkReachabilityFlags) {
        
        guard previousFlags != flags else { return }
        
        if isReachableWithFlags(flags) {
            if let block = whenReachable {
                block(self)
            }
        } else {
            if let block = whenUnreachable {
                block(self)
            }
        }
        
        notificationCenter.post(name: Notification.Name(rawValue: ReachabilityChangedNotification), object:self)
        
        previousFlags = flags
    }
    
    fileprivate func isReachableWithFlags(_ flags: SCNetworkReachabilityFlags) -> Bool {
        
        if !isReachable(flags) {
            return false
        }
        
        if isConnectionRequiredOrTransient(flags) {
            return false
        }
        
        if isRunningOnDevice {
            if isOnWWAN(flags) && !reachableOnWWAN {
                // We don't want to connect when on 3G.
                return false
            }
        }
        
        return true
    }
    
    // WWAN may be available, but not active until a connection has been established.
    // WiFi may require a connection for VPN on Demand.
    fileprivate func isConnectionRequired() -> Bool {
        return connectionRequired()
    }
    
    fileprivate func connectionRequired() -> Bool {
        let flags = reachabilityFlags
        return isConnectionRequired(flags)
    }
    
    // Dynamic, on demand connection?
    fileprivate func isConnectionOnDemand() -> Bool {
        let flags = reachabilityFlags
        return isConnectionRequired(flags) && isConnectionOnTrafficOrDemand(flags)
    }
    
    // Is user intervention required?
    fileprivate func isInterventionRequired() -> Bool {
        let flags = reachabilityFlags
        return isConnectionRequired(flags) && isInterventionRequired(flags)
    }
    
    fileprivate func isOnWWAN(_ flags: SCNetworkReachabilityFlags) -> Bool {
        #if os(iOS)
            return flags.contains(.isWWAN)
        #else
            return false
        #endif
    }
    fileprivate func isReachable(_ flags: SCNetworkReachabilityFlags) -> Bool {
        return flags.contains(.reachable)
    }
    fileprivate func isConnectionRequired(_ flags: SCNetworkReachabilityFlags) -> Bool {
        return flags.contains(.connectionRequired)
    }
    fileprivate func isInterventionRequired(_ flags: SCNetworkReachabilityFlags) -> Bool {
        return flags.contains(.interventionRequired)
    }
    fileprivate func isConnectionOnTraffic(_ flags: SCNetworkReachabilityFlags) -> Bool {
        return flags.contains(.connectionOnTraffic)
    }
    fileprivate func isConnectionOnDemand(_ flags: SCNetworkReachabilityFlags) -> Bool {
        return flags.contains(.connectionOnDemand)
    }
    func isConnectionOnTrafficOrDemand(_ flags: SCNetworkReachabilityFlags) -> Bool {
        return !flags.intersection([.connectionOnTraffic, .connectionOnDemand]).isEmpty
    }
    fileprivate func isTransientConnection(_ flags: SCNetworkReachabilityFlags) -> Bool {
        return flags.contains(.transientConnection)
    }
    fileprivate func isLocalAddress(_ flags: SCNetworkReachabilityFlags) -> Bool {
        return flags.contains(.isLocalAddress)
    }
    fileprivate func isDirect(_ flags: SCNetworkReachabilityFlags) -> Bool {
        return flags.contains(.isDirect)
    }
    fileprivate func isConnectionRequiredOrTransient(_ flags: SCNetworkReachabilityFlags) -> Bool {
        let testcase:SCNetworkReachabilityFlags = [.connectionRequired, .transientConnection]
        return flags.intersection(testcase) == testcase
    }
    
    fileprivate var reachabilityFlags: SCNetworkReachabilityFlags {
        
        guard let reachabilityRef = reachabilityRef else { return SCNetworkReachabilityFlags() }
        
        var flags = SCNetworkReachabilityFlags()
        let gotFlags = withUnsafeMutablePointer(to: &flags) {
            SCNetworkReachabilityGetFlags(reachabilityRef, UnsafeMutablePointer($0))
        }
        
        if gotFlags {
            return flags
        } else {
            return SCNetworkReachabilityFlags()
        }
    }
    
    override open var description: String {
        
        var W: String
        if isRunningOnDevice {
            W = isOnWWAN(reachabilityFlags) ? "W" : "-"
        } else {
            W = "X"
        }
        let R = isReachable(reachabilityFlags) ? "R" : "-"
        let c = isConnectionRequired(reachabilityFlags) ? "c" : "-"
        let t = isTransientConnection(reachabilityFlags) ? "t" : "-"
        let i = isInterventionRequired(reachabilityFlags) ? "i" : "-"
        let C = isConnectionOnTraffic(reachabilityFlags) ? "C" : "-"
        let D = isConnectionOnDemand(reachabilityFlags) ? "D" : "-"
        let l = isLocalAddress(reachabilityFlags) ? "l" : "-"
        let d = isDirect(reachabilityFlags) ? "d" : "-"
        
        return "\(W)\(R) \(c)\(t)\(i)\(C)\(D)\(l)\(d)"
    }
    
    deinit {
        stopNotifier()
        
        reachabilityRef = nil
        whenReachable = nil
        whenUnreachable = nil
    }
    
}
