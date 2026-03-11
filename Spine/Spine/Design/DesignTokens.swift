import SwiftUI

// MARK: - Spine Design System
// Literary, modern, calm, slightly premium.
// "A beautiful reading gym for ambitious people."

enum SpineTokens {
    
    // MARK: - Color Palette
    
    enum Colors {
        // Core palette — warm, literary, non-childish
        static let cream = Color(hex: "FAF7F2")
        static let warmStone = Color(hex: "E8E0D8")
        static let parchment = Color(hex: "F5F0E8")
        static let charcoal = Color(hex: "2C2C2E")
        static let espresso = Color(hex: "4A3728")
        static let ink = Color(hex: "1C1C1E")
        
        // Accent
        static let accentGold = Color(hex: "C49B5C")
        static let accentAmber = Color(hex: "D4A853")
        static let softGold = Color(hex: "C49B5C").opacity(0.3)
        
        // Semantic
        static let streakFlame = Color(hex: "E8734A")
        static let successGreen = Color(hex: "4CAF82")
        static let subtleGray = Color(hex: "8E8E93")
        
        // Reader themes
        static let sepiaBackground = Color(hex: "F4ECD8")
        static let sepiaText = Color(hex: "5B4636")
        static let darkBackground = Color(hex: "1C1C1E")
        static let darkText = Color(hex: "E5E5EA")
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }
    
    // MARK: - Corner Radius
    
    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 24
        static let pill: CGFloat = 100
    }
    
    // MARK: - Typography
    
    enum Typography {
        // UI fonts — clean, rounded
        static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
        static let title = Font.system(.title2, design: .rounded, weight: .semibold)
        static let title3 = Font.system(.title3, design: .rounded, weight: .medium)
        static let headline = Font.system(.headline, design: .rounded, weight: .semibold)
        static let body = Font.system(.body, design: .default, weight: .regular)
        static let callout = Font.system(.callout, design: .default, weight: .regular)
        static let caption = Font.system(.caption, design: .rounded, weight: .regular)
        static let caption2 = Font.system(.caption2, design: .rounded, weight: .medium)
        
        // Reader fonts
        static func readerSerif(size: CGFloat) -> Font {
            .system(size: size, design: .serif)
        }
        
        static func readerSans(size: CGFloat) -> Font {
            .system(size: size, design: .default)
        }
    }
    
    // MARK: - Shadows
    
    enum Shadows {
        static let subtle = Color.black.opacity(0.08)
        static let medium = Color.black.opacity(0.15)
        static let strong = Color.black.opacity(0.25)
    }
    
    // MARK: - Animation
    
    enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.35)
        static let gentle = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
    }
}

// Color(hex:) extension is in Extensions/Color+Hex.swift
