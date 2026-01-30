import SwiftUI

// MARK: - Glass Container (Liquid Glass on macOS 26+, Material fallback)

struct GlassContainer<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content
    
    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            VStack(spacing: spacing) {
                content
            }
        }
    }
}

// MARK: - View Extensions

extension View {
    @ViewBuilder
    func glassBackground() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: 12))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    @ViewBuilder
    func glassBackground(in shape: some InsettableShape) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
        }
    }
    
    @ViewBuilder
    func glassID(_ id: String, in namespace: Namespace.ID) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffectID(id, in: namespace)
        } else {
            self
        }
    }
}

// MARK: - Glass Card Modifier

extension View {
    @ViewBuilder
    func glassCard() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: 14))
        } else {
            self
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.secondary.opacity(0.1), lineWidth: 1)
                )
        }
    }
    
    @ViewBuilder
    func glassPill() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: Capsule())
        } else {
            self.background(.regularMaterial, in: Capsule())
        }
    }
    
    @ViewBuilder
    func glassInteractive(isHovered: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            self
                .glassEffect(
                    isHovered ? .regular.tint(.primary.opacity(0.1)).interactive() : .regular.interactive(),
                    in: .rect(cornerRadius: 12)
                )
        } else {
            self
                .background(
                    isHovered ? Color.primary.opacity(0.08) : Color.secondary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 12)
                )
        }
    }
}

// MARK: - Button Styles

struct GlassButtonStyle: ButtonStyle {
    var isProminent: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 26.0, *) {
            if isProminent {
                AnyView(
                    configuration.label
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.tint, in: RoundedRectangle(cornerRadius: 10))
                        .opacity(configuration.isPressed ? 0.8 : 1)
                )
            } else {
                AnyView(
                    configuration.label
                        .padding(8)
                        .background(
                            configuration.isPressed ? Color.primary.opacity(0.1) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                )
            }
        } else {
            configuration.label
                .padding(isProminent ? 12 : 8)
                .background(
                    configuration.isPressed 
                        ? Color.primary.opacity(0.15) 
                        : Color.primary.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .opacity(configuration.isPressed ? 0.8 : 1)
        }
    }
}

extension ButtonStyle where Self == GlassButtonStyle {
    static var glassCompat: GlassButtonStyle { GlassButtonStyle() }
    static var glassProminentCompat: GlassButtonStyle { GlassButtonStyle(isProminent: true) }
}
