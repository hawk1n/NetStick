//
//  Components.swift
//  NetStick
//
//  Created by conv3 on 2026-01-06.
//

import SwiftUI

// MARK: - Signal Strength Bar (for Wi-Fi RSSI)

struct SignalStrengthBar: View {
    let rssi: Int
    let maxBars: Int = 5
    
    private var filledBars: Int {
        switch rssi {
        case -50...0: return 5
        case -60...(-50): return 4
        case -70...(-60): return 3
        case -80...(-70): return 2
        case -90...(-80): return 1
        default: return 0
        }
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<maxBars, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < filledBars ? barColor : Color.gray.opacity(0.3))
                    .frame(width: 4, height: CGFloat(4 + index * 3))
            }
        }
    }
    
    private var barColor: Color {
        switch filledBars {
        case 4...5: return .green
        case 3: return .yellow
        case 2: return .orange
        default: return .red
        }
    }
}

// MARK: - Circular Progress

struct CircularProgress: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    var color: Color = .blue
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progress)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Pulsing Dot

struct PulsingDot: View {
    @State private var isAnimating = false
    let color: Color
    let size: CGFloat
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .scaleEffect(isAnimating ? 1.2 : 1.0)
            .opacity(isAnimating ? 0.6 : 1.0)
            .animation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Status Chip

struct StatusChip: View {
    let text: String
    let color: Color
    let icon: String?
    
    init(_ text: String, color: Color, icon: String? = nil) {
        self.text = text
        self.color = color
        self.icon = icon
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(8)
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    let message: String
    let progress: Double?
    
    var body: some View {
        VStack(spacing: 16) {
            if let progress = progress {
                CircularProgress(progress: progress, lineWidth: 4, size: 60)
                    .overlay {
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
            } else {
                ProgressView()
                    .scaleEffect(1.5)
            }
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(icon: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(title)
                .font(.title3)
                .fontWeight(.medium)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .fontWeight(.semibold)
                        .frame(width: 160)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.top)
            }
            
            Spacer()
        }
    }
}

// MARK: - Risk Level Badge

struct RiskLevelBadge: View {
    let level: RiskLevel
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(level.description)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(8)
    }
    
    private var color: Color {
        switch level {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .green
        case .none: return .blue
        }
    }
}

// MARK: - Animated Scan Ring

struct ScanRing: View {
    @State private var isAnimating = false
    let color: Color
    
    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(color.opacity(0.3 - Double(index) * 0.1), lineWidth: 2)
                    .scaleEffect(isAnimating ? 1.0 + CGFloat(index) * 0.3 : 0.5)
                    .opacity(isAnimating ? 0 : 1)
            }
        }
        .animation(
            .easeOut(duration: 1.5)
            .repeatForever(autoreverses: false)
            .delay(Double.random(in: 0...0.5)),
            value: isAnimating
        )
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Previews

#Preview("Signal Strength") {
    VStack(spacing: 20) {
        SignalStrengthBar(rssi: -45)
        SignalStrengthBar(rssi: -65)
        SignalStrengthBar(rssi: -80)
        SignalStrengthBar(rssi: -95)
    }
    .padding()
}

#Preview("Status Chips") {
    HStack(spacing: 8) {
        StatusChip("Connected", color: .green, icon: "checkmark.circle.fill")
        StatusChip("Scanning", color: .blue, icon: "antenna.radiowaves.left.and.right")
        StatusChip("Error", color: .red, icon: "exclamationmark.triangle.fill")
    }
    .padding()
}

#Preview("Loading Overlay") {
    LoadingOverlay(message: "Scanning network...", progress: 0.65)
}

#Preview("Empty State") {
    EmptyStateView(
        icon: "network",
        title: "No Devices Found",
        message: "Tap scan to discover devices on your network.",
        actionTitle: "Scan Now",
        action: {}
    )
}
