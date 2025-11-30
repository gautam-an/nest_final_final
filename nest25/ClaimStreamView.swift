import SwiftUI

// MARK: - Models (unchanged)
struct ClaimStreamResponse: Codable {
    let claims: [Claim]
}

struct Claim: Codable, Identifiable {
    let id: String
    let timestamp_in_stream: String
    let text: String
    let verification: Verification
    
    enum CodingKeys: String, CodingKey {
        case id = "claim_id"
        case timestamp_in_stream
        case text
        case verification
    }
}

struct Verification: Codable {
    let status: String // "true" or "false"
    let explanation: String
    let sources: [Source]
}

struct Source: Codable, Identifiable {
    let id = UUID()
    let name: String
    let url: String
}

// MARK: - ViewModel (unchanged)
class ClaimStreamViewModel: ObservableObject {
    @Published var claims: [Claim] = []
    private var timer: Timer?

    private let endpoint = "http://192.168.1.47:8000/verifications"

    init() {
        fetchClaims()
        startAutoRefresh()
    }

    func fetchClaims() {
        guard let url = URL(string: endpoint) else {
            print("Invalid URL")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Request error:", error)
                return
            }

            guard let data = data else { return }

            do {
                let decoded = try JSONDecoder().decode(ClaimStreamResponse.self, from: data)

                DispatchQueue.main.async {
                    self.claims = decoded.claims
                }

            } catch {
                print("Decoding error:", error)
            }
        }.resume()
    }

    func startAutoRefresh() {
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            self.fetchClaims()
        }
    }

    deinit {
        timer?.invalidate()
    }
}


// MARK: - Views
struct ClaimStreamView: View {
    @StateObject private var viewModel = ClaimStreamViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Live Fact Checks")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    ForEach(viewModel.claims) { claim in
                        NavigationLink(destination: ClaimDetailView(claim: claim)) {
                            ClaimCardView(claim: claim)
                                .padding(.horizontal)
                        }
                        .buttonStyle(PlainButtonStyle()) // ✅ important
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Live Claims")
        .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
    }
}


// MARK: - Claim Card View
struct ClaimCardView: View {
    let claim: Claim
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: claim.verification.status == "true" ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.system(size: 24))
                    .foregroundColor(claim.verification.status == "true" ? .green : .red)
                    .frame(width: 30, height: 30)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(claim.text)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                            Text(claim.timestamp_in_stream)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Text(claim.verification.status == "true" ? "VERIFIED" : "FALSE")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(claim.verification.status == "true" ? .green : .red)
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Detail View
struct ClaimDetailView: View {
    let claim: Claim
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Claim Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Text("Claim")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Image(systemName: "quote.bubble.fill")
                            .foregroundColor(Color("PrimaryBlue"))
                            .imageScale(.large)
                    }
                    
                    Text(claim.text)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                        Text(claim.timestamp_in_stream)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    .padding(.top, 5)
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
                
                // Verification Status Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Text("Verification Status")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Image(systemName: claim.verification.status == "true" ? "checkmark.seal.fill" : "xmark.seal.fill")
                            .foregroundColor(claim.verification.status == "true" ? .green : .red)
                            .imageScale(.large)
                    }
                    
                    HStack {
                        Text(claim.verification.status == "true" ? "VERIFIED" : "FALSE")
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundColor(claim.verification.status == "true" ? .green : .red)
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
                
                // Explanation Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Text("Explanation")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(Color("PrimaryBlue"))
                            .imageScale(.large)
                    }
                    
                    RichTextView(explanation: claim.verification.explanation, sources: claim.verification.sources)
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
                
                // Sources Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Text("Sources")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Image(systemName: "link.circle.fill")
                            .foregroundColor(Color("PrimaryBlue"))
                            .imageScale(.large)
                    }
                    
                    ForEach(claim.verification.sources) { source in
                        Link(destination: URL(string: source.url)!) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(source.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Text(source.url)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.right.square.fill")
                                    .foregroundColor(Color("PrimaryBlue"))
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Claim Details")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
    }
}

// MARK: - Rich Text View (functionality unchanged)
struct RichTextView: View {
    let explanation: String
    let sources: [Source]
    
    var body: some View {
        var attributed = AttributedString(explanation)
        for source in sources {
            // Find the range of the bracketed source name in the AttributedString
            if let range = attributed.range(of: "[\(source.name)]") {
                // Replace the bracketed text with plain source name
                attributed.replaceSubrange(range, with: AttributedString(source.name))
                // Get the new range of the plain name
                if let newRange = attributed.range(of: source.name) {
                    if let url = URL(string: source.url) {
                        attributed[newRange].link = url
                        attributed[newRange].foregroundColor = .blue
                        attributed[newRange].underlineStyle = .single
                    }
                }
            }
        }
        
        return Text(attributed)
            .font(.body)
    }
}

// MARK: - Preview
struct ClaimStreamView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ClaimStreamView()
        }
    }
}
