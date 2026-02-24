import SwiftUI

// MARK: - Brand Color Palette

enum AppColors {
    // Primary: Slate Teal — #1A535C / dark #2D8A99
    static let appPrimary = Color(UIColor(dynamicProvider: { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x2D/255, green: 0x8A/255, blue: 0x99/255, alpha: 1)
            : UIColor(red: 0x1A/255, green: 0x53/255, blue: 0x5C/255, alpha: 1)
    }))

    // Accent: Warm Amber — #E8A838 / dark #F0BA4A
    static let appAccent = Color(UIColor(dynamicProvider: { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xF0/255, green: 0xBA/255, blue: 0x4A/255, alpha: 1)
            : UIColor(red: 0xE8/255, green: 0xA8/255, blue: 0x38/255, alpha: 1)
    }))

    // Success: Soft Green — #52B788 / dark #6DD4A0
    static let appSuccess = Color(UIColor(dynamicProvider: { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x6D/255, green: 0xD4/255, blue: 0xA0/255, alpha: 1)
            : UIColor(red: 0x52/255, green: 0xB7/255, blue: 0x88/255, alpha: 1)
    }))

    // Danger: Red — #E63946 / dark #FF5C68
    static let appDanger = Color(UIColor(dynamicProvider: { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xFF/255, green: 0x5C/255, blue: 0x68/255, alpha: 1)
            : UIColor(red: 0xE6/255, green: 0x39/255, blue: 0x46/255, alpha: 1)
    }))

    // Background — #F7F9FC / dark #0F1117
    static let appBackground = Color(UIColor(dynamicProvider: { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x0F/255, green: 0x11/255, blue: 0x17/255, alpha: 1)
            : UIColor(red: 0xF7/255, green: 0xF9/255, blue: 0xFC/255, alpha: 1)
    }))

    // Text Primary — #1C1C1E / dark #F5F5F5
    static let appTextPrimary = Color(UIColor(dynamicProvider: { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xF5/255, green: 0xF5/255, blue: 0xF5/255, alpha: 1)
            : UIColor(red: 0x1C/255, green: 0x1C/255, blue: 0x1E/255, alpha: 1)
    }))
}

// MARK: - Convenient Color extensions

extension Color {
    static let appPrimary     = AppColors.appPrimary
    static let appAccent      = AppColors.appAccent
    static let appSuccess     = AppColors.appSuccess
    static let appDanger      = AppColors.appDanger
    static let appBackground  = AppColors.appBackground
    static let appTextPrimary = AppColors.appTextPrimary
}
