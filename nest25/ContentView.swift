import SwiftUI

struct ContentView: View {
    @AppStorage("isOnboarded") private var isOnboarded: Bool = false
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @State private var isShowingSplash: Bool = true
    @State private var shouldDismissSplash: Bool = false
    @State private var contentScale: CGFloat = 0.95
    @State private var contentOpacity: Double = 0
    
    var body: some View {
        ZStack {
            if isShowingSplash && !shouldDismissSplash {
                SplashView(shouldDismiss: $shouldDismissSplash)
                    .zIndex(1)
                    .transition(.asymmetric(
                        insertion: .identity,
                        removal: .opacity.combined(with: .scale(scale: 0.9))
                    ))
            }
            
            // Main content with smooth transitions
            Group {
                if !isOnboarded {
                    OnboardingView(isOnboarded: $isOnboarded)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                } else {
                    MainTabView()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                }
            }
            .scaleEffect(contentScale)
            .opacity(contentOpacity)
            .blur(radius: isShowingSplash ? 8 : 0)
        }
        .preferredColorScheme(.light)
        .onChange(of: shouldDismissSplash) { newValue in
            if newValue {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                    contentScale = 1.0
                    contentOpacity = 1.0
                }
                
                withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                    isShowingSplash = false
                }
            }
        }
        .onChange(of: isOnboarded) { newValue in
            if newValue {
                // Smooth transition from onboarding to main content
                withAnimation(.easeInOut(duration: 0.6)) {
                    // The transition modifiers will handle the view change
                }
            }
        }
        .onAppear {
            // Prepare the content behind the splash
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    contentScale = 0.95
                    contentOpacity = 0.3
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
