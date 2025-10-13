import SwiftUI
import WebKit

struct VotingInfoView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = true
    @AppStorage("userEmail") private var userEmail: String = ""
    @State private var showingLogoutAlert = false
    @State private var showPrivacy = false
    @State private var showGuidelines = false
    @State private var showAbout = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Voting Info Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Voting Information")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)

                        InfoCardView(
                            title: "How to Register",
                            description: "Learn about the voter registration process and ensure you're eligible to vote in the upcoming election.",
                            iconName: "person.text.rectangle.fill"
                        )
                        .padding(.horizontal)

                        InfoCardView(
                            title: "Voting Requirements",
                            description: "Understand what identification and materials you need to bring with you on election day.",
                            iconName: "checklist"
                        )
                        .padding(.horizontal)
                    }

                    Divider()
                        .padding(.horizontal)

                    // Settings Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Settings")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)

                        // Terms & Privacy
                        Button {
                            showPrivacy = true
                        } label: {
                            SettingsRowView(title: "Terms & Privacy", iconName: "lock.fill")
                        }
                        .sheet(isPresented: $showPrivacy) {
                            TermsPrivacyView()
                        }
                        .padding(.horizontal)

                        // Community Guidelines
                        Button {
                            showGuidelines = true
                        } label: {
                            SettingsRowView(title: "Community Guidelines", iconName: "person.3.fill")
                        }
                        .sheet(isPresented: $showGuidelines) {
                            CommunityGuidelinesView()
                        }
                        .padding(.horizontal)

                        // About Elect Connect
                        Button {
                            showAbout = true
                        } label: {
                            SettingsRowView(title: "About Elect Connect", iconName: "info.circle.fill")
                        }
                        .sheet(isPresented: $showAbout) {
                            AboutElectConnectView()
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Voting & Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingLogoutAlert = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .imageScale(.large)
                            .foregroundColor(Color("PrimaryBlue"))
                    }
                }
            }
        }
    }
}

struct SettingsRowView: View {
    var title: String
    var iconName: String

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(Color("PrimaryBlue"))
                .frame(width: 30, height: 30)

            Text(title)
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct InfoCardView: View {
    var title: String
    var description: String
    var iconName: String

    @State private var isPresentingMoreInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 15) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)

                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .foregroundColor(Color("PrimaryBlue"))
            }

            Button(action: {
                isPresentingMoreInfo = true
            }) {
                Text("Learn More")
                    .font(.caption)
                    .foregroundColor(Color("PrimaryBlue"))
                    .padding(.top, 5)
            }
            .sheet(isPresented: $isPresentingMoreInfo) {
                MoreInfoView(title: title, contentSections: detailedSections(for: title))
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    func detailedSections(for title: String) -> [InfoSection] {
        switch title {
        case "How to Register":
            return [
                InfoSection(
                    heading: "Online Registration",
                    body: [
                        "Most states offer online voter registration through their state election website.",
                        "You'll typically need a valid driver's license or state-issued ID.",
                        "Check your state's specific requirements and registration portal."
                    ],
                    link: URL(string: "https://www.vote.gov/register"),
                    iconName: "desktopcomputer"
                ),
                InfoSection(
                    heading: "Register by Mail",
                    body: [
                        "Download and complete the National Mail Voter Registration Form.",
                        "Mail it to your local election office by your state's deadline.",
                        "Forms must be postmarked by the registration deadline."
                    ],
                    link: URL(string: "https://www.eac.gov/voters/national-mail-voter-registration-form"),
                    iconName: "envelope.fill"
                ),
                InfoSection(
                    heading: "Register In Person",
                    body: [
                        "Visit your local election office, DMV, or other designated agencies.",
                        "Bring valid identification as required by your state.",
                        "Some states offer same-day registration at polling locations."
                    ],
                    link: nil,
                    iconName: "person.crop.circle.badge.checkmark"
                ),
                InfoSection(
                    heading: "Registration Deadlines",
                    body: [
                        "Deadlines vary by state, typically ranging from 15-30 days before an election.",
                        "Some states offer same-day registration during early voting or on election day.",
                        "Check your state's specific deadline to ensure you're registered in time."
                    ],
                    link: URL(string: "https://www.vote.gov/register"),
                    iconName: "calendar"
                )
            ]

        case "Voting Requirements":
            return [
                InfoSection(
                    heading: "Eligibility",
                    body: [
                        "You must be a U.S. citizen and a resident of your state.",
                        "You must be at least 18 years old by election day.",
                        "Most states require you not to be serving a felony sentence (requirements vary by state).",
                        "Some states allow 17-year-olds to vote in primaries if they'll be 18 by the general election."
                    ],
                    link: URL(string: "https://www.usa.gov/who-can-vote"),
                    iconName: "checkmark.shield"
                ),
                InfoSection(
                    heading: "Voter ID Requirements",
                    body: [
                        "ID requirements vary significantly by state.",
                        "Some states require photo ID, others accept non-photo documents, and some require no ID.",
                        "Accepted IDs may include driver's license, passport, state ID, military ID, or student ID.",
                        "Check your state's specific ID requirements before heading to the polls."
                    ],
                    link: URL(string: "https://www.usa.gov/voter-id"),
                    iconName: "person.text.rectangle"
                ),
                InfoSection(
                    heading: "Check Your Registration",
                    body: [
                        "Verify your voter registration status online.",
                        "Confirm your polling location and hours.",
                        "Find official election resources for your state."
                    ],
                    link: URL(string: "https://www.vote.gov/"),
                    iconName: "questionmark.circle"
                )
            ]

        default:
            return [
                InfoSection(
                    heading: "Coming Soon",
                    body: ["More details will be available soon."],
                    link: nil,
                    iconName: "clock"
                )
            ]
        }
    }
}

struct MoreInfoView: View {
    var title: String
    var contentSections: [InfoSection]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)

                ForEach(contentSections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Text(section.heading)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: section.iconName ?? "info.circle.fill")
                                .foregroundColor(Color("PrimaryBlue"))
                                .imageScale(.large)
                        }

                        ForEach(section.body, id: \.self) { paragraph in
                            Text(paragraph)
                                .font(.body)
                                .foregroundColor(.primary)
                        }

                        if let url = section.link {
                            Link("Learn more", destination: url)
                                .font(.subheadline)
                                .foregroundColor(Color("PrimaryBlue"))
                                .padding(.top, 5)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
                }

                Spacer()
            }
            .padding()
        }
    }
}

struct TermsPrivacyView: View {
    var body: some View {
        WebView(url: URL(string: "https://jacobpercy.github.io/ecpv/privacy.html")!)
            .edgesIgnoringSafeArea(.all)
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
}

struct CommunityGuidelinesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Community Guidelines")
                    .font(.title)
                    .fontWeight(.bold)

                Group {
                    Text("Respectful Use")
                        .font(.headline)
                    Text("Use Elect Connect to engage constructively with elected officials. Harassment, spam, or illegal activity is prohibited.")
                }

                Group {
                    Text("Data Accuracy")
                        .font(.headline)
                    Text("Please ensure information you provide (like your location) is accurate for best results.")
                }

                Group {
                    Text("Reporting Issues")
                        .font(.headline)
                    Text("If you see any misuse or incorrect information, contact our support team at gautam.anamalai@gmail.com.")
                }

                Spacer()
            }
            .padding()
        }
    }
}

struct AboutElectConnectView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("About Elect Connect")
                    .font(.title)
                    .fontWeight(.bold)

                Group {
                    Text("Our Mission")
                        .font(.headline)
                    Text("Elect Connect is built to make election info more accessible and useful. We're focused on helping people stay informed, not overwhelmed.")
                }

                Group {
                    Text("Why We Built This")
                        .font(.headline)
                    Text("We wanted a simpler way to track voter info, candidates, and deadlines — so we made one. No clutter, no noise.")
                }

                Group {
                    Text("Version Info")
                        .font(.headline)
                    Text("Elect Connect v1.0.\nSwiftUI • iOS")
                }

                Group {
                    Text("Open Source")
                        .font(.headline)
                    Text("We're currently developing Elect Connect with plans to make parts of it open source in the future.")
                }

                Spacer()
            }
            .padding()
        }
    }
}

struct InfoSection: Identifiable {
    let id = UUID()
    let heading: String
    let body: [String]
    let link: URL?
    let iconName: String?
}

struct VotingInfoView_Previews: PreviewProvider {
    static var previews: some View {
        VotingInfoView()
    }
}
