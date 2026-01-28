import SwiftUI

// MARK: - Animation Tokens

enum PlaidAnimation {
    
    enum Spring {
        /// Standard spring for hover and interactive feedback
        /// Used for: card hover, button press, state changes
        static let `default` = Animation.spring(response: 0.3, dampingFraction: 0.7)
        
        /// Snappy spring for quick UI feedback
        /// Used for: tab switches, toggles, quick transitions
        static let snappy = Animation.spring(response: 0.25, dampingFraction: 0.8)
        
        /// Smooth spring for slow, elegant transitions
        /// Used for: page transitions, large element moves
        static let smooth = Animation.spring(response: 0.5, dampingFraction: 0.75)
        
        /// Navigation spring from TabSwitcher
        /// Used for: navigation transitions, matched geometry
        static let navigation = Animation.spring(response: 0.35, dampingFraction: 0.75)
    }
    
    enum EaseOut {
        /// Fast ease out for quick responses
        /// Used for: waveforms, rapid updates
        static let fast = Animation.easeOut(duration: 0.08)
        
        /// Default ease out for general animations
        /// Used for: hover states, opacity changes
        static let `default` = Animation.easeOut(duration: 0.15)
        
        /// Slow ease out for pronounced animations
        /// Used for: chart animations, staggered reveals
        static let slow = Animation.easeOut(duration: 0.3)
    }
    
    enum EaseInOut {
        /// Standard ease in-out for symmetric animations
        static let `default` = Animation.easeInOut(duration: 0.2)
        
        /// Pulse animation (repeating)
        static let pulse = Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)
    }
}

// MARK: - Hover Scale Values

enum PlaidHoverScale {
    /// Subtle scale for dense UI elements
    static let subtle: CGFloat = 1.005
    
    /// Default scale for standard cards and buttons
    static let `default`: CGFloat = 1.01
    
    /// Emphasis scale for hero elements
    static let emphasis: CGFloat = 1.02
}

// MARK: - Hover Effect Modifier

struct PlaidHoverEffectModifier: ViewModifier {
    @State private var isHovered = false
    let scale: CGFloat
    let animation: Animation
    
    init(scale: CGFloat = PlaidHoverScale.default, animation: Animation = PlaidAnimation.Spring.default) {
        self.scale = scale
        self.animation = animation
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .animation(animation, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    /// Applies standardized hover effect with scale animation
    /// - Parameters:
    ///   - scale: Scale factor on hover (default: 1.01)
    ///   - animation: Animation to use (default: spring)
    func plaidHoverEffect(
        scale: CGFloat = PlaidHoverScale.default,
        animation: Animation = PlaidAnimation.Spring.default
    ) -> some View {
        modifier(PlaidHoverEffectModifier(scale: scale, animation: animation))
    }
}

// MARK: - Delayed Animation Modifier

extension View {
    /// Applies animation with delay, useful for staggered effects
    func plaidAnimated(delay: Double = 0, animation: Animation = PlaidAnimation.Spring.default) -> some View {
        self.animation(animation.delay(delay), value: UUID())
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        Text("Hover over me (subtle)")
            .padding()
            .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            .plaidHoverEffect(scale: PlaidHoverScale.subtle)
        
        Text("Hover over me (default)")
            .padding()
            .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            .plaidHoverEffect()
        
        Text("Hover over me (emphasis)")
            .padding()
            .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            .plaidHoverEffect(scale: PlaidHoverScale.emphasis)
    }
    .padding()
}
