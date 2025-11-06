import SwiftUI

struct OnboardingView: View {
    @Binding var isOnboarded: Bool
    
    @AppStorage("selectedTopics") private var storedTopics: String = ""
    @State private var tempSelectedTopics: [String] = []
    
    var selectedTopics: [String] {
        get { storedTopics.components(separatedBy: ",").filter { !$0.isEmpty } }
        set { storedTopics = newValue.joined(separator: ",") }
    }
    
    @State private var currentPage = 0
    
    private let pages = [
        OnboardingPage(
            title: "Welcome to Elect Connect",
            description: "Your non-partisan guide to civic action, turning political confusion into confident engagement.",
            imageName: "person.3.fill",
            buttonText: "Continue"
        ),
        OnboardingPage(
            title: "Town Hall (Coming Soon)",
            description: "Watch live streams of candidate events with live fact-checking and stay connected with your representatives.",
            imageName: "video.fill",
            buttonText: "Continue"
        ),
        OnboardingPage(
            title: "Find Your Polling Place (Coming Soon)",
            description: "Based on your location, easily find nearby polling places and their hours of operation.",
            imageName: "mappin.circle.fill",
            buttonText: "Continue"
        ),
        OnboardingPage(
            title: "Connect with Your Legislators",
            description: "You can find your local representatives, based on your location. Easily email them your questions and view their previously answered inquiries.",
            imageName: "mappin.and.ellipse",
            buttonText: "Continue"
        ),
        OnboardingPage(
            title: "Voting Information",
            description: "Access comprehensive giudes on how to register to vote and the voting requirements",
            imageName: "info.circle.fill",
            buttonText: "Continue"
        ),
        OnboardingPage(
            title: "News Feed",
            description: "Get the latest news and updates about elections and candidates, tailored to your interests, and with tools to help you detect media bias.",
            imageName: "newspaper.fill",
            buttonText: "Take the Quiz!"
        )
    ]
        
    private var totalPages: Int {
        pages.count + 1
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.white, Color("PrimaryBlue").opacity(0.05)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Capsule()
                            .fill(index <= currentPage ? Color("PrimaryBlue") : Color.gray.opacity(0.3))
                            .frame(height: 4)
                            .animation(.easeInOut(duration: 0.3), value: currentPage)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                VStack(spacing: 0) {
                    TabView(selection: $currentPage) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            if index == totalPages - 1 {
                                QuizPage(selectedTopics: $tempSelectedTopics, isOnboarded: $isOnboarded)
                                    .tag(index)
                            } else {
                                OnboardingPageView(page: pages[index])
                                    .tag(index)
                            }
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.5), value: currentPage)
                    .onAppear {
                        tempSelectedTopics = selectedTopics
                    }
                }
                .frame(maxHeight: .infinity)
                
                VStack(spacing: 16) {
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            if currentPage < totalPages - 1 {
                                currentPage += 1
                            } else {
                                storedTopics = tempSelectedTopics.joined(separator: ",")
                                isOnboarded = true
                            }
                        }
                    }) {
                        HStack {
                            Text(currentPage == totalPages - 1 ? "Get Started" : pages[currentPage].buttonText)
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            if currentPage < totalPages - 1 {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color("PrimaryBlue"))
                                .shadow(color: Color("PrimaryBlue").opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                    }
                    .scaleEffect(currentPage == totalPages - 1 && tempSelectedTopics.isEmpty ? 0.95 : 1.0)
                    .opacity(currentPage == totalPages - 1 && tempSelectedTopics.isEmpty ? 0.6 : 1.0)
                    .disabled(currentPage == totalPages - 1 && tempSelectedTopics.isEmpty)
                    .animation(.easeInOut(duration: 0.2), value: tempSelectedTopics.count)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, max(34, UIApplication.shared.connectedScenes
                                        .compactMap { $0 as? UIWindowScene }
                                        .flatMap { $0.windows }
                                        .first?.safeAreaInsets.bottom ?? 0))
            }
        }
    }
}
struct QuizPage: View {
    @Binding var selectedTopics: [String]
    @Binding var isOnboarded: Bool
    
    let topics = [
        ("Technology", "desktopcomputer", "technology", Color.blue),
        ("Economy", "chart.bar.fill", "economics", Color.green),
        ("Environment", "leaf.fill", "environment", Color.mint),
        ("Global Affairs", "globe.europe.africa.fill", "international", Color.indigo),
        ("Immigration", "figure.wave", "immigration", Color.orange)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 32))
                    .foregroundColor(Color("PrimaryBlue"))
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: selectedTopics.count)
                
                Text("Choose Your Interests")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color("PrimaryBlue"))
                    .multilineTextAlignment(.center)
                
                Text("Select topics to personalize your experience")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.top, 20)
            .padding(.bottom, 24)
            
            VStack(spacing: 12) {
                ForEach(Array(topics.enumerated()), id: \.offset) { index, topic in
                    TopicCard(
                        title: topic.0,
                        icon: topic.1,
                        key: topic.2,
                        color: topic.3,
                        isSelected: selectedTopics.contains(topic.2)
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            if selectedTopics.contains(topic.2) {
                                selectedTopics.removeAll { $0 == topic.2 }
                            } else {
                                selectedTopics.append(topic.2)
                            }
                        }
                    }
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.05), value: selectedTopics.count)
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            if !selectedTopics.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color("PrimaryBlue"))
                        .font(.system(size: 16))
                    Text("\(selectedTopics.count) selected")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color("PrimaryBlue"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color("PrimaryBlue").opacity(0.1))
                .cornerRadius(16)
                .transition(.scale.combined(with: .opacity))
                .padding(.bottom, 20)
            }
        }
    }
}

struct TopicCard: View {
    let title: String
    let icon: String
    let key: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color("PrimaryBlue") : color.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isSelected ? .white : color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color("PrimaryBlue").opacity(0.3), lineWidth: 2)
                        .frame(width: 20, height: 20)
                    
                    if isSelected {
                        Circle()
                            .fill(Color("PrimaryBlue"))
                            .frame(width: 20, height: 20)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color("PrimaryBlue").opacity(0.05) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color("PrimaryBlue") : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                    )
                    .shadow(color: isSelected ? Color("PrimaryBlue").opacity(0.1) : Color.black.opacity(0.05), radius: isSelected ? 6 : 3, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
    }
}

struct OnboardingPage: Identifiable {
    var id = UUID()
    var title: String
    var description: String
    var imageName: String
    var buttonText: String
}

struct OnboardingPageView: View {
    var page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color("PrimaryBlue").opacity(0.1))
                    .frame(width: 200, height: 200)
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: UUID())
                
                Circle()
                    .fill(Color("PrimaryBlue").opacity(0.05))
                    .frame(width: 160, height: 160)
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: UUID())
                
                Image(systemName: page.imageName)
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(Color("PrimaryBlue"))
            }
            .padding(.top, 40)
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color("PrimaryBlue"))
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
            }
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isOnboarded: .constant(false))
    }
}
