import SwiftUI

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
                        "Register online through the Virginia Department of Elections.",
                        "You'll need a valid Virginia driver’s license or state-issued ID."
                    ],
                    link: URL(string: "https://vote.elections.virginia.gov/VoterInformation"),
                    iconName: "desktopcomputer"
                ),
                InfoSection(
                    heading: "Register by Mail",
                    body: [
                        "Print and complete the application form, then mail it to your local registrar.",
                        "It must be postmarked by the registration deadline."
                    ],
                    link: URL(string: "https://www.elections.virginia.gov/registration/how-to-register/"),
                    iconName: "envelope.fill"
                ),
                InfoSection(
                    heading: "Register In Person",
                    body: [
                        "Visit your local registrar’s office, DMV, or other designated agencies.",
                        "Make sure to bring valid identification."
                    ],
                    link: nil,
                    iconName: "person.crop.circle.badge.checkmark"
                ),
                InfoSection(
                    heading: "Deadline",
                    body: [
                        "Registration must be completed 22 days before the election.",
                        "Some late registration may be possible during early voting."
                    ],
                    link: nil,
                    iconName: "calendar"
                )
            ]

        case "Voting Requirements":
            return [
                InfoSection(
                    heading: "Eligibility",
                    body: [
                        "You must be a U.S. citizen, a resident of Virginia, and at least 18 years old by election day.",
                        "You must not be under a disqualifying felony conviction (unless rights restored)."
                    ],
                    link: nil,
                    iconName: "checkmark.shield"
                ),
                InfoSection(
                    heading: "Accepted ID",
                    body: [
                        "Bring a valid ID such as a driver’s license, U.S. passport, or student ID.",
                        "No ID? You can sign an ID Confirmation Statement at the polls."
                    ],
                    link: URL(string: "https://www.elections.virginia.gov/registration/voter-id/"),
                    iconName: "person.text.rectangle"
                ),
                InfoSection(
                    heading: "Need Help?",
                    body: [
                        "Check your registration status or find official resources at the Virginia Elections site."
                    ],
                    link: URL(string: "https://www.elections.virginia.gov/"),
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Elect Connect Privacy Policy")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Last Updated: September 25, 2025")

                Text("""
Elect Connect ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your information when you use our mobile application.

Information We Collect
- Location Information: We collect your GPS coordinates to identify your elected representatives.
- Personal Preferences: Your selected political topics, onboarding data, app settings.
- Communication Data: We facilitate email composition to representatives, store question history.
- Usage Information: We collect anonymized feature usage and engagement.

How We Use Your Information
- Identify your elected representatives based on location.
- Personalize news content to your selected interests.
- Facilitate communication with your representatives.
- Improve app functionality and user experience.

Data Sharing
We share your information with:
- OpenStates API, News Sources, Email Providers, Google Sheets.

Data Security
- Location data encrypted during transmission.
- Local data storage uses iOS security frameworks.
- No sensitive personal identifiers collected.

Data Retention
- Location data stored until you change your location or delete the app.
- Cached legislator data refreshed periodically.
- User preferences retained until app deletion.
- Email copies stored indefinitely for support purposes.

Your Privacy Rights
- Control your data (location, topics, data deletion, email opt-out).
- Access, correct, or export your data.

Third-Party Services
- OpenStates, GitHub, Google Sheets.

Children's Privacy
- Intended for users 17 years and older.

International Users
- Data may be transferred to and processed in the United States.

Changes to This Policy
- We may update this policy periodically. Continued use constitutes acceptance.

Data Deletion
- Contact us at gautam.anamalai@gmail.com with subject "Data Deletion Request".

Contact Us
- Email: gautam.anamalai@gmail.com (Subject: "Privacy Inquiry - Elect Connect").

Legal Basis for Processing
- Consent, Legitimate Interest, Public Interest.
""")
                .font(.body)

                Spacer()
            }
            .padding()
        }
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
