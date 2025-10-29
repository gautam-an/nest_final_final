import SwiftUI
import CoreLocation
import MapKit
import WebKit
import MessageUI

// MARK: - Data Cache Manager
class DataCache {
    private func getCacheUrl(for coordinate: CLLocationCoordinate2D) -> URL? {
        guard let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let fileName = "legislators_lat_\(coordinate.latitude)_lng_\(coordinate.longitude).json"
        return cacheDirectory.appendingPathComponent(fileName)
    }
    
    func save(_ legislators: [Legislator], for coordinate: CLLocationCoordinate2D) {
        guard let url = getCacheUrl(for: coordinate) else { return }
        do {
            let data = try JSONEncoder().encode(legislators)
            try data.write(to: url)
        } catch {
            print("🚨 Cache: Failed to save data. Error: \(error)")
        }
    }
    
    func load(for coordinate: CLLocationCoordinate2D) -> [Legislator]? {
        guard let url = getCacheUrl(for: coordinate), FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Legislator].self, from: data)
        } catch {
            print("🚨 Cache: Failed to load or decode data. Error: \(error)")
            return nil
        }
    }
    
    func clearCache(for coordinate: CLLocationCoordinate2D) {
        guard let url = getCacheUrl(for: coordinate), FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("🚨 Cache: Failed to clear cache. Error: \(error)")
        }
    }
}

// MARK: - Location Storage
class LocationStorage: ObservableObject {
    @AppStorage("savedLatitude") private var latitude: Double = 0
    @AppStorage("savedLongitude") private var longitude: Double = 0
    
    var hasSavedLocation: Bool { latitude != 0 && longitude != 0 }
    
    var savedCoordinate: CLLocationCoordinate2D? {
        guard hasSavedLocation else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    func save(coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        objectWillChange.send()
    }
}

// MARK: - Location Manager
class LocationManager2: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    
    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }
    
    func requestLocation() { manager.requestWhenInUseAuthorization() }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let newLocation = locations.last {
            location = newLocation
            manager.stopUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("🚨 LocationManager2: Failed to get location. Error: \(error.localizedDescription)")
    }
}

// MARK: - Models
struct LegislatorResponse: Codable { let results: [Legislator] }

struct Legislator: Identifiable, Codable {
    let id: String, name: String, party: String?, image: String?, currentRole: Role?, openstatesUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, party, image
        case currentRole = "current_role"
        case openstatesUrl = "openstates_url"
    }
    
    var finalImageURL: URL? {
        if name == "Suhas Subramanyam" {
            return URL(string: "https://clerk.house.gov/images/members/S001230.jpg")
        }
        guard let imageString = image else { return nil }
        return URL(string: imageString)
    }
    
    var partyColor: Color {
        switch party {
        case "Democratic": return .blue
        case "Republican": return .red
        default: return .gray
        }
    }
    
    var profileURL: URL? {
        guard let urlString = openstatesUrl else { return nil }
        return URL(string: urlString)
    }
}

struct Role: Codable {
    let orgClassification: String, district: String?
    
    enum CodingKeys: String, CodingKey {
        case orgClassification = "org_classification"
        case district
    }
}

// MARK: - Asked Question Model
struct AskedQuestion: Identifiable {
    let id: String, candidate: String, candidateEmail: String, requester: String, subject: String, question: String, answer: String, timestamp: String
    
    var isAnswered: Bool { !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

// MARK: - Fetcher
class LegislatorFetcher: ObservableObject {
    @Published var legislators: [Legislator] = []
    private let cache = DataCache()
    
    func fetchLegislators(apiKey: String, lat: Double, lng: Double, forceRefresh: Bool = false) {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        
        if forceRefresh { cache.clearCache(for: coordinate) }
        
        if !forceRefresh, let cachedLegislators = cache.load(for: coordinate) {
            DispatchQueue.main.async { self.legislators = cachedLegislators }
            return
        }
        
        guard let url = URL(string: "https://v3.openstates.org/people.geo?lat=\(lat)&lng=\(lng)") else { return }
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data else { return }
            do {
                let decodedResponse = try JSONDecoder().decode(LegislatorResponse.self, from: data)
                DispatchQueue.main.async { self.legislators = decodedResponse.results }
                self.cache.save(decodedResponse.results, for: coordinate)
            } catch { print("🚨 Fetcher: Decoding error: \(error)") }
        }.resume()
    }
}

// MARK: - Question Fetcher
class QuestionFetcher: ObservableObject {
    @Published var questions: [AskedQuestion] = []
    private let csvUrl = URL(string: "https://docs.google.com/spreadsheets/d/1SxwTKCm8lGS8a0AgiZrJxEHDFpORvw7Dsd05mWr1qAo/export?format=csv&gid=2110081341")!
    
    func fetchAndParseCSV(completion: @escaping ([AskedQuestion]) -> Void) {
        URLSession.shared.dataTask(with: csvUrl) { data, _, error in
            guard let data = data, error == nil else {
                print("🚨 Failed to download CSV: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async { completion([]) }; return
            }
            
            guard let csvString = String(data: data, encoding: .utf8) else {
                print("🚨 Failed to convert data to string")
                DispatchQueue.main.async { completion([]) }; return
            }
            
            let parsedQuestions = self.parse(csv: csvString)
            DispatchQueue.main.async {
                self.questions = parsedQuestions
                completion(parsedQuestions)
            }
        }.resume()
    }
    
    private func parse(csv: String) -> [AskedQuestion] {
        var records: [AskedQuestion] = []; var allRows: [[String]] = []; var currentRow: [String] = []; var currentField = ""; var inQuotes = false
        
        let normalizedCSV = csv.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        
        for char in normalizedCSV {
            if inQuotes {
                if char == "\"" { inQuotes = false } else { currentField.append(char) }
            } else {
                switch char {
                case "\"": inQuotes = true
                case ",": currentRow.append(currentField); currentField = ""
                case "\n": currentRow.append(currentField); allRows.append(currentRow); currentRow = []; currentField = ""
                default: currentField.append(char)
                }
            }
        }
        
        if !currentField.isEmpty || !currentRow.isEmpty { currentRow.append(currentField); allRows.append(currentRow) }
        
        for fields in allRows.dropFirst() {
            if fields.count >= 8 {
                records.append(AskedQuestion(id: fields[0], candidate: fields[1], candidateEmail: fields[2], requester: fields[3], subject: fields[4], question: fields[5], answer: fields[6], timestamp: fields[7]))
            } else { print("⚠️ Skipping malformed CSV row: \(fields)") }
        }
        
        return records
    }
}

// MARK: - Location Picker View
struct LocationPickerView: View {
    @Environment(\.dismiss) var dismiss
    @State private var region: MKCoordinateRegion
    @State private var cameraPosition: MapCameraPosition // New state for the map
    var onLocationSave: (CLLocationCoordinate2D) -> Void
    
    init(onLocationSave: @escaping (CLLocationCoordinate2D) -> Void) {
        self.onLocationSave = onLocationSave
        let initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 38.8899, longitude: -77.0091),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        // Set the initial values for both state variables
        _region = State(initialValue: initialRegion)
        _cameraPosition = State(initialValue: .region(initialRegion))
    }
    
    var body: some View {
        ZStack {
            // Use the new Map initializer and keep the `region` state in sync
            Map(position: $cameraPosition)
                .onMapCameraChange { context in
                    self.region = context.region
                }
                .ignoresSafeArea()
            
            // Center pin (No changes needed here)
            VStack {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
                    .background(Circle().fill(.white).frame(width: 25, height: 25))
                    .shadow(radius: 2)
                
                Rectangle()
                    .fill(.red)
                    .frame(width: 3, height: 15)
                    .offset(y: -10)
            }
            
            // Bottom card view (No changes needed here as it reads from `region`)
            VStack {
                Spacer()
                
                VStack(spacing: 12) {
                    Text("Set Your Location")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    Text("Drag the map to position the pin at your location")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text("Lat: \(region.center.latitude, specifier: "%.4f"), Lon: \(region.center.longitude, specifier: "%.4f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                    
                    Button(action: {
                        onLocationSave(region.center)
                        dismiss()
                    }) {
                        Text("Save Location")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding()
                .shadow(radius: 10)
            }
        }
        .navigationTitle("Set Location")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}

// MARK: - Mail Helper
struct MailView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    let recipient: String, subject: String, body: String
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        guard MFMailComposeViewController.canSendMail() else { return MFMailComposeViewController() }
        
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([recipient])
        vc.setCcRecipients(["jacobpercy09+nest@gmail.com"])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailView
        init(_ parent: MailView) { self.parent = parent }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.dismiss()
        }
    }
}

// MARK: - Question Row View
struct QuestionView: View {
    let question: AskedQuestion
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isExpanded.toggle() } }) {
                HStack {
                    Text(question.subject)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(isExpanded ? nil : 1)
                    
                    Spacer()
                    
                    if !question.isAnswered {
                        Image(systemName: "circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .padding(.leading, 4)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Question")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        Text(question.question)
                            .font(.body)
                    }
                    
                    if question.isAnswered {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Answer")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            Text(question.answer)
                                .font(.body)
                                .italic()
                        }
                    } else {
                        HStack {
                            Image(systemName: "hourglass")
                                .foregroundColor(.orange)
                            
                            Text("Awaiting response")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Contact View
struct ContactView: View {
    let legislatorName: String, recipientEmail: String
    @State private var subject: String = ""
    @State private var intro: String
    @State private var question: String = ""
    @State private var makeQuestionPublic: Bool = true
    @State private var showMailSheet = false
    @StateObject private var questionFetcher = QuestionFetcher()
    @State private var relevantQuestions: [AskedQuestion] = []
    @State private var isLoadingQuestions = true
    @State private var showNewQuestionForm = false
    private let invisibleSeparator = "\u{180E}"
    
    init(legislatorName: String, recipientEmail: String) {
        self.legislatorName = legislatorName
        self.recipientEmail = recipientEmail
        _intro = State(initialValue: "Dear \(legislatorName),\n\nI am writing to you today as a concerned constituent.")
    }
    
    var isFormValid: Bool {
        !subject.trimmingCharacters(in: .whitespaces).isEmpty &&
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var emailBody: String {
        intro + invisibleSeparator + question + invisibleSeparator +
        "\n\nThis is an email from the app Elect Connect, which aims to connnect voters to their elected officials"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Contact \(legislatorName)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(recipientEmail)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // Previous Questions Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Label("Previously Asked Questions", systemImage: "text.bubble.fill")
                            .font(.headline)
                        
                        Spacer()
                        
                        if !isLoadingQuestions {
                            Button(action: loadQuestions) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    
                    if isLoadingQuestions {
                        HStack {
                            Spacer()
                            ProgressView("Loading questions...")
                            Spacer()
                        }
                        .padding()
                    } else if relevantQuestions.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "questionmark.square.dashed")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 4)
                            
                            Text("No questions found")
                                .font(.headline)
                            
                            Text("Be the first to ask a question to this representative.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(relevantQuestions) { question in
                                QuestionView(question: question)
                            }
                        }
                    }
                    
                    if !isLoadingQuestions && !showNewQuestionForm {
                        Button(action: { withAnimation(.easeInOut(duration: 0.3)) { showNewQuestionForm = true } }) {
                            Label("Ask a New Question", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal)
                
                // New Question Form
                if showNewQuestionForm {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Label("New Question", systemImage: "square.and.pencil")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: { withAnimation { showNewQuestionForm = false } }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Subject")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextField("Enter subject...", text: $subject)
                                .textFieldStyle(.roundedBorder)
                                .padding(.bottom, 4)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Introduction")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextEditor(text: $intro)
                                .frame(minHeight: 100)
                                .padding(4)
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                                )
                                .allowsHitTesting(false)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Question")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextEditor(text: $question)
                                .frame(minHeight: 150)
                                .padding(4)
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: $makeQuestionPublic) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Make Question Public")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text("Share your question with other users to see responses")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: Color("PrimaryBlue")))
                            .padding(.vertical, 8)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        
                        Button(action: { self.showMailSheet = true }) {
                            Label("Prepare Email", systemImage: "envelope.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!isFormValid)
                        
                        if !isFormValid {
                            Text("Please provide both a subject and your question")
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .sheet(isPresented: $showMailSheet) {
            MailView(recipient: recipientEmail, subject: subject, body: emailBody)
        }
        .onAppear(perform: loadQuestions)
    }
    
    private func loadQuestions() {
        isLoadingQuestions = true
        showNewQuestionForm = false
        
        questionFetcher.fetchAndParseCSV { allQuestions in
            self.relevantQuestions = allQuestions.filter {
                $0.candidateEmail.trimmingCharacters(in: .whitespaces).lowercased() ==
                self.recipientEmail.trimmingCharacters(in: .whitespaces).lowercased()
            }
            self.isLoadingQuestions = false
        }
    }
}

// MARK: - Interactive WebView
struct InteractiveWebView: UIViewRepresentable {
    let url: URL
    @Binding var triggerScraping: Bool
    let onScrapeCompleted: ([String: Any?]) -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "scraper")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if triggerScraping {
            webView.evaluateJavaScript(context.coordinator.javascriptToRun)
            DispatchQueue.main.async { self.triggerScraping = false }
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
            var parent: InteractiveWebView
            var hasScraped = false

            let javascriptToRun = """
            function findContactInfo() {
                const mailtoLink = document.querySelector('a[href^="mailto:"]');
                if (mailtoLink) { return { email: mailtoLink.href.replace('mailto:', '').split('?')[0], contactUrl: null }; }
                
                const contactPageLink = Array.from(document.querySelectorAll('a')).find(a => 
                    (a.textContent.toLowerCase().includes('contact') || a.href.toLowerCase().includes('contact')) && 
                    a.href.startsWith('http')
                );
                
                if (contactPageLink) { return { email: null, contactUrl: contactPageLink.href }; }
                return { email: null, contactUrl: null };
            }
            
            window.webkit.messageHandlers.scraper.postMessage(findContactInfo());
            """

            init(_ parent: InteractiveWebView) { self.parent = parent }

            func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
                guard let dict = message.body as? [String: Any?] else { return }
                let email = dict["email"] as? String
                let contactUrl = dict["contactUrl"] as? String

                if let email = email {
                    parent.onScrapeCompleted(["email": email, "contactUrl": nil])
                } else if let url = contactUrl {
                    parent.onScrapeCompleted(["email": nil, "contactUrl": url])
                } else {
                    parent.onScrapeCompleted(["email": nil, "contactUrl": nil])
                }
                hasScraped = true
            }

            func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
                if !hasScraped {
                    webView.evaluateJavaScript(javascriptToRun)
                }
            }
        }
}

// MARK: - Scrape Result Data Structure
struct ScrapeResult: Identifiable {
    let id = UUID()
    let email: String?
    let contactUrl: String?
}

// MARK: - Email Storage Class
class EmailStorage {
    static let shared = EmailStorage()
    private var emailCache: [String: String] = [:]
    
    private init() {}
    
    func saveEmail(_ email: String, forLegislatorId id: String) {
        emailCache[id] = email
        print("✅ Stored email for legislator \(id): \(email)")
    }
    
    func getEmail(forLegislatorId id: String) -> String? {
        return emailCache[id]
    }
}

// MARK: - Legislator Detail View
struct LegislatorDetailView: View {
    let legislator: Legislator
    @State private var triggerScraping = false
    @State private var scrapeResult: ScrapeResult?
    @State private var isScraping = false
    @State private var webViewLoaded = false
    @State private var showContactError = false
    @State private var cachedEmail: String?
    
    var body: some View {
        ZStack {
            if let url = legislator.profileURL {
                InteractiveWebView(
                    url: url,
                    triggerScraping: $triggerScraping,
                    onScrapeCompleted: { resultDict in
                        self.isScraping = false
                        let email = resultDict["email"] as? String
                        let url = resultDict["contactUrl"] as? String
                        
                        if let foundEmail = email {
                            EmailStorage.shared.saveEmail(foundEmail, forLegislatorId: legislator.id)
                            self.cachedEmail = foundEmail
                            self.scrapeResult = ScrapeResult(email: foundEmail, contactUrl: url)
                        } else if url != nil {
                            self.scrapeResult = ScrapeResult(email: nil, contactUrl: url)
                        } else {
                            print("❌ Scrape found no contact info.")
                            if let stored = EmailStorage.shared.getEmail(forLegislatorId: legislator.id) {
                                print("✅ Using previously stored email: \(stored)")
                                self.cachedEmail = stored
                                self.scrapeResult = ScrapeResult(email: stored, contactUrl: nil)
                            } else {
                                self.showContactError = true}
                        }
                    }
                )
                .ignoresSafeArea(edges: .bottom)
                .onAppear {
                    cachedEmail = EmailStorage.shared.getEmail(forLegislatorId: legislator.id)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        webViewLoaded = true
                    }
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("No profile information available")
                        .font(.headline)
                    
                    Text("We couldn't find any profile data for this representative.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
            }
            
            if isScraping {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text("Searching for contact information...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .shadow(radius: 10)
            }
        }
        .navigationTitle(legislator.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    guard webViewLoaded else {
                        showContactError = true
                        return
                    }
                    
                    if let stored = cachedEmail {
                        print("✅ Using cached email without scraping: \(stored)")
                        self.scrapeResult = ScrapeResult(email: stored, contactUrl: nil)
                    } else {
                        self.isScraping = true
                        self.triggerScraping = true
                    }
                }) {
                    Label("Contact", systemImage: "envelope.fill")
                }
                .disabled(isScraping || !webViewLoaded)
                .buttonStyle(.borderedProminent)
            }
        }
        .alert("Contact Information Unavailable", isPresented: $showContactError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We couldn't find contact information on this page. Please try visiting their profile directly.")
        }
        .sheet(item: $scrapeResult) { result in
            if let email = result.email {
                ContactView(legislatorName: legislator.name, recipientEmail: email)
            } else if let urlString = result.contactUrl, let url = URL(string: urlString) {
                NavigationView {
                    WebView2(url: url)
                        .navigationTitle("Contact Form")
                        .navigationBarTitleDisplayMode(.inline)
                        .ignoresSafeArea(edges: .bottom)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    scrapeResult = nil
                                }
                            }
                        }
                }
            }
        }
    }
    
    private struct WebView2: UIViewRepresentable {
        let url: URL
        
        func makeUIView(context: Context) -> WKWebView {
            let webView = WKWebView()
            webView.load(URLRequest(url: url))
            return webView
        }
        
        func updateUIView(_ uiView: WKWebView, context: Context) {}
    }
}

// MARK: - Main Grid View
struct LegislatorsGridView: View {
    @StateObject private var fetcher = LegislatorFetcher()
    @StateObject private var locationManager = LocationManager2()
    @StateObject private var locationStorage = LocationStorage()
    @State private var showLocationPicker = false
    @State private var isLoading = false
    @State private var showingLocationPermissionAlert = false
    
    let apiKey = "bc839aae-7609-47f9-82ed-c280c4ca07dd"
    let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack {
                if isLoading && fetcher.legislators.isEmpty {
                    loadingView
                } else if !fetcher.legislators.isEmpty {
                    legislatorGrid
                } else {
                    emptyStateView
                }
            }
        }
        .navigationTitle("Your Representatives")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: forceRefreshData) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(locationStorage.savedCoordinate == nil || isLoading)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showLocationPicker = true }) {
                    Label("Change Location", systemImage: "mappin.and.ellipse")
                }
                .buttonStyle(.bordered)
            }
        }
        .sheet(isPresented: $showLocationPicker) {
            NavigationView {
                LocationPickerView { coordinate in
                    locationStorage.save(coordinate: coordinate)
                    fetchData(for: coordinate)
                }
            }
        }
        .alert("Location Access Required", isPresented: $showingLocationPermissionAlert) {
            Button("Settings", role: .destructive) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable location access in Settings to find representatives in your area.")
        }
        .onAppear {
            if let savedCoord = locationStorage.savedCoordinate {
                fetchData(for: savedCoord)
            } else {
                locationManager.requestLocation()
            }
        }
        .onChange(of: locationManager.location) { oldValue, newLocation in
            if let location = newLocation, locationStorage.savedCoordinate == nil {
                locationStorage.save(coordinate: location.coordinate)
                fetchData(for: location.coordinate)
            }
        }

        .onChange(of: locationManager.authorizationStatus) { oldValue, newStatus in
            switch newStatus {
            case .denied, .restricted:
                showingLocationPermissionAlert = true
            default:
                break
            }
        }

        
    }
    
    private func fetchData(for coordinate: CLLocationCoordinate2D, forceRefresh: Bool = false) {
        isLoading = true
        fetcher.legislators = []
        
        fetcher.fetchLegislators(
            apiKey: apiKey,
            lat: coordinate.latitude,
            lng: coordinate.longitude,
            forceRefresh: forceRefresh
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
        }
    }
    
    private func forceRefreshData() {
        guard let coordinate = locationStorage.savedCoordinate else { return }
        fetchData(for: coordinate, forceRefresh: true)
    }
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Finding your representatives...")
                .font(.headline)
            
            Text("This may take a moment as we locate your elected officials.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Set Your Location")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("To find your representatives, we need to know your location.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { showLocationPicker = true }) {
                Label("Set Location", systemImage: "mappin.and.ellipse")
                    .font(.headline)
                    .frame(maxWidth: 250)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private var legislatorGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let coordinate = locationStorage.savedCoordinate {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Location")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Lat: \(coordinate.latitude, specifier: "%.4f"), Lon: \(coordinate.longitude, specifier: "%.4f")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: { showLocationPicker = true }) {
                            Text("Change")
                                .font(.subheadline)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                Text("Found \(fetcher.legislators.count) Representatives")
                    .font(.headline)
                    .padding(.horizontal)
                
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(fetcher.legislators) { legislator in
                        NavigationLink(destination: legislatorDetailView(for: legislator)) {
                            legislatorTile(for: legislator)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .refreshable {
            if let coordinate = locationStorage.savedCoordinate {
                fetchData(for: coordinate, forceRefresh: true)
            }
        }
    }
    
    private func legislatorTile(for legislator: Legislator) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(legislator.partyColor.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                AsyncImage(url: legislator.finalImageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 90, height: 90)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(legislator.partyColor, lineWidth: 3)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            
            VStack(spacing: 4) {
                Text(legislator.name)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                Text(legislator.currentRole?.orgClassification.capitalized ?? "Unknown Role")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let district = legislator.currentRole?.district {
                    Text("District \(district)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(legislator.partyColor.opacity(0.1))
                        .cornerRadius(4)
                }
                
                if let party = legislator.party {
                    Text(party)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(legislator.partyColor.opacity(0.2))
                        .foregroundColor(legislator.partyColor)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(UIColor.systemGray5), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func legislatorDetailView(for legislator: Legislator) -> some View {
        LegislatorDetailView(legislator: legislator)
    }
}

// MARK: - App Entry Point
struct ElectConnectApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                LegislatorsGridView()
            }
        }
    }
}
            
