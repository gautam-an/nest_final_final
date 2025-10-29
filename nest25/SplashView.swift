import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var dotsAnimation: Bool = false // Separate state for dots animation
    @State private var pulseAnimation: Bool = false // State for background bubbles animation
    
    @Binding var shouldDismiss: Bool
    
    var body: some View {
        ZStack {
            // Clean gradient background with slightly lighter blue colors
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.25, green: 0.5, blue: 0.85), // Slightly lighter primary blue
                    Color(red: 0.2, green: 0.45, blue: 0.8)   // Slightly lighter darker blue for gradient end
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Animated background circles (bubbles) - re-added and subtle
            Circle()
                .fill(Color.white.opacity(0.08)) // Subtle opacity
                .frame(width: 280, height: 280)
                .offset(x: -100, y: -200)
                .scaleEffect(pulseAnimation ? 1.2 : 0.8)
                .animation(
                    Animation.easeInOut(duration: 3.0)
                        .repeatForever(autoreverses: true),
                    value: pulseAnimation
                )
            
            Circle()
                .fill(Color.white.opacity(0.03)) // Even more subtle opacity
                .frame(width: 180, height: 180)
                .offset(x: 120, y: 150)
                .scaleEffect(pulseAnimation ? 0.8 : 1.2)
                .animation(
                    Animation.easeInOut(duration: 2.5)
                        .repeatForever(autoreverses: true),
                    value: pulseAnimation
                )
            
            VStack(spacing: 32) {
                Spacer()
                
                // Simple, clean logo
                VStack(spacing: 24) {
                    // Logo - Simple and clean
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        // Changed icon to person.3.fill for a clearer "people" theme
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 50, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    
                    // App name
                    VStack(spacing: 8) {
                        Text("Elect Connect")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Your Voice Matters")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .opacity(textOpacity)
                }
                
                Spacer()
                
                // Subtle continue button
                VStack(spacing: 16) {
                    Button(action: {
                        dismissSplash()
                    }) {
                        HStack(spacing: 8) {
                            Text("Tap to continue")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .opacity(buttonOpacity)
                    
                    // Bouncing dots indicator
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.white.opacity(0.4))
                                .frame(width: 6, height: 6)
                                .scaleEffect(dotsAnimation ? 1.2 : 0.8) // Bouncing effect
                                .animation(
                                    .easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                    value: dotsAnimation // Tied to dotsAnimation state
                                )
                        }
                    }
                    .opacity(buttonOpacity * 0.6) // Fades in with the button
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            startAnimations()
            dotsAnimation = true // Start dots animation immediately
            pulseAnimation = true // Start background bubbles animation
            
            // Removed auto dismiss after 3 seconds to make it user-driven
        }
    }
    
    private func startAnimations() {
        // Logo animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // Text animation
        withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
            textOpacity = 1.0
        }
        
        // Button animation
        withAnimation(.easeOut(duration: 0.6).delay(1.2)) {
            buttonOpacity = 1.0
        }
    }
    
    private func dismissSplash() {
        withAnimation(.easeInOut(duration: 0.4)) {
            shouldDismiss = true
        }
    }
}

struct SplashView_Previews: PreviewProvider {
    static var previews: some View {
        SplashView(shouldDismiss: .constant(false))
    }
}
