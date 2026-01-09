//
//  OpenPort.swift
//  NetStick
//
//  Created by conv3 on 2026-01-06.
//

import Foundation
import SwiftUI

/// Represents an open port found during port scan
struct OpenPort: Identifiable, Hashable {
    let id = UUID()
    let number: Int
    let service: String
    let banner: String?
    
    /// Port risk level based on common dangerous ports
    var riskLevel: PortRiskLevel {
        switch number {
        // Critical - often targeted
        case 23:    // Telnet
            return .critical
        case 21:    // FTP
            return .high
        case 3389:  // RDP
            return .high
        case 445:   // SMB
            return .high
        case 135, 137, 138, 139:  // NetBIOS
            return .high
            
        // Medium - commonly used but can be risky
        case 22:    // SSH
            return .medium
        case 3306:  // MySQL
            return .medium
        case 5432:  // PostgreSQL
            return .medium
        case 27017: // MongoDB
            return .medium
        case 6379:  // Redis
            return .medium
            
        // Low - generally safe
        case 80, 443, 8080, 8443:  // HTTP/HTTPS
            return .low
        case 53:    // DNS
            return .low
        case 25, 587, 465:  // SMTP
            return .low
            
        default:
            return .unknown
        }
    }
    
    /// Color for the port badge
    var color: Color {
        switch riskLevel {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .green
        case .unknown: return .gray
        }
    }
    
    static func == (lhs: OpenPort, rhs: OpenPort) -> Bool {
        lhs.number == rhs.number
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(number)
    }
}

/// Risk level for ports
enum PortRiskLevel: Int {
    case unknown = 0
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
}
