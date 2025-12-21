import SwiftUI

// MARK: - Helper Functions

func formatISODate(_ iso: String?) -> String? {
    guard let iso, !iso.isEmpty else { return nil }
    
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime]
    
    let simpleFormatter = DateFormatter()
    simpleFormatter.dateFormat = "yyyy-MM-dd"
    
    let out = DateFormatter()
    out.dateStyle = .medium
    
    // Try standard ISO first
    if let date = isoFormatter.date(from: iso) {
        return out.string(from: date)
    }
    // Try simple YYYY-MM-DD
    else if let date = simpleFormatter.date(from: iso) {
        return out.string(from: date)
    }
    
    // Fallback: Just strip the ugly timestamp if parsing fails
    return iso.replacingOccurrences(of: "T00:00:00Z", with: "")
}

// MARK: - API Models

struct CongressResponse<T: Codable>: Codable {
    let bills: [Bill]?
    let treaties: [Treaty]?
    let members: [Member]?
    let pagination: Pagination?
}

struct Pagination: Codable {
    let count: Int?
    let next: String?
}

struct Bill: Codable, Identifiable, Hashable {
    let congress: Int?
    let type: String?
    let originChamber: String?
    let number: String?
    let title: String?
    let updateDate: String?
    let latestAction: Action?
    
    // Unique ID combining fundamental properties + update date to catch changes
    var id: String {
        return "\(congress ?? 0)-\(type ?? "")-\(number ?? "")-\(updateDate ?? "")"
    }
    
    var formattedTitle: String {
        title ?? "Untitled Bill"
    }
    
    var formattedType: String {
        type?.uppercased() ?? "BILL"
    }
}

struct Action: Codable, Hashable {
    let actionDate: String?
    let text: String?
}

struct Treaty: Codable, Identifiable, Hashable {
    let number: Int?
    let suffix: String?
    let congressReceived: Int?
    let topic: String?
    let transmittedDate: String?
    
    var id: String {
        return "\(congressReceived ?? 0)-\(number ?? 0)-\(suffix ?? "")-\(transmittedDate ?? "")"
    }
    
    var displayTitle: String {
        let num = number ?? 0
        if let s = suffix, !s.isEmpty {
            return "Treaty \(num)-\(s)"
        }
        return "Treaty \(num)"
    }
}

struct Member: Codable, Identifiable, Hashable {
    let bioguideId: String
    let name: String?
    let state: String?
    let district: Int?
    let partyName: String?
    let depiction: Depiction?
    let terms: MemberTerms?
    
    var id: String { bioguideId }
    
    struct Depiction: Codable, Hashable {
        let imageUrl: String?
        let attribution: String?
    }
    
    struct MemberTerms: Codable, Hashable {
        let item: [Term]?
    }
    
    struct Term: Codable, Hashable {
        let chamber: String?
        let startYear: Int?
        let endYear: Int?
    }
}

// MARK: - View Model

@MainActor
class CongressViewModel: ObservableObject {
    @Published var selectedTab: CongressTab = .bills
    @Published var bills: [Bill] = []
    @Published var treaties: [Treaty] = []
    @Published var members: [Member] = []
    
    // Filters
    @Published var selectedCongress: Int = 118
    @Published var selectedBillType: String = "" // Empty = All
    @Published var selectedState: String = "" // Empty = All
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiKey = "c3yejfiNvHRNh8eu5uT4JzUQmqEbBLh0wPXV2NWT"
    private var offset = 0
    private let limit = 20
    private var canLoadMore = true
    
    enum CongressTab: String, CaseIterable {
        case bills = "Bills"
        case treaties = "Treaties"
        case members = "Members"
    }
    
    func resetAndLoad() {
        offset = 0
        canLoadMore = true
        bills = []
        treaties = []
        members = []
        errorMessage = nil
        Task { await loadData() }
    }
    
    func loadMore() {
        guard !isLoading && canLoadMore else { return }
        Task { await loadData() }
    }
    
    private func loadData() async {
        isLoading = true
        if offset == 0 { errorMessage = nil }
        
        do {
            let urlString = buildURL()
            guard let url = URL(string: urlString) else { throw URLError(.badURL) }
            
            var request = URLRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            // Decode based on tab
            switch selectedTab {
            case .bills:
                let result = try JSONDecoder().decode(CongressResponse<Bill>.self, from: data)
                if let newBills = result.bills {
                    // Filter duplicates before appending
                    let uniqueBills = newBills.filter { newBill in
                        !self.bills.contains(where: { $0.id == newBill.id })
                    }
                    self.bills.append(contentsOf: uniqueBills)
                    self.canLoadMore = newBills.count >= limit
                } else {
                    self.canLoadMore = false
                }
                
            case .treaties:
                let result = try JSONDecoder().decode(CongressResponse<Treaty>.self, from: data)
                if let newTreaties = result.treaties {
                    let uniqueTreaties = newTreaties.filter { newTreaty in
                        !self.treaties.contains(where: { $0.id == newTreaty.id })
                    }
                    self.treaties.append(contentsOf: uniqueTreaties)
                    self.canLoadMore = newTreaties.count >= limit
                } else {
                    self.canLoadMore = false
                }
                
            case .members:
                let result = try JSONDecoder().decode(CongressResponse<Member>.self, from: data)
                if let newMembers = result.members {
                    let uniqueMembers = newMembers.filter { newMember in
                        !self.members.contains(where: { $0.id == newMember.id })
                    }
                    self.members.append(contentsOf: uniqueMembers)
                    self.canLoadMore = newMembers.count >= limit
                } else {
                    self.canLoadMore = false
                }
            }
            
            offset += limit
            
        } catch {
            print("Decoding Error: \(error)")
            self.errorMessage = "Failed to load: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func buildURL() -> String {
        let baseURL = "https://api.congress.gov/v3"
        var endpoint = ""
        
        switch selectedTab {
        case .bills:
            endpoint = "/bill/\(selectedCongress)"
            if !selectedBillType.isEmpty { endpoint += "/\(selectedBillType)" }
        case .treaties:
            endpoint = "/treaty/\(selectedCongress)"
        case .members:
            if !selectedState.isEmpty {
                endpoint = "/member/\(selectedState)"
            } else {
                endpoint = "/member"
            }
        }
        
        return "\(baseURL)\(endpoint)?api_key=\(apiKey)&format=json&offset=\(offset)&limit=\(limit)"
    }
}

// MARK: - Main View

struct CongressView: View {
    @StateObject private var viewModel = CongressViewModel()
    @State private var showFilters = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Category", selection: $viewModel.selectedTab) {
                    ForEach(CongressViewModel.CongressTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: viewModel.selectedTab) { _, _ in viewModel.resetAndLoad() }
                
                // Content List
                List {
                    switch viewModel.selectedTab {
                    case .bills:
                        ForEach(viewModel.bills) { bill in
                            NavigationLink(value: bill) {
                                BillRow(bill: bill)
                            }
                        }
                    case .treaties:
                        ForEach(viewModel.treaties) { treaty in
                            TreatyRow(treaty: treaty)
                        }
                    case .members:
                        ForEach(viewModel.members) { member in
                            MemberRow(member: member)
                        }
                    }
                    
                    // Loading / Error / Infinite Scroll
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                    } else if let error = viewModel.errorMessage {
                        VStack(alignment: .leading) {
                            Text("Error")
                                .font(.headline)
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .listRowSeparator(.hidden)
                    } else {
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                viewModel.loadMore()
                            }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    viewModel.resetAndLoad()
                }
            }
            .navigationTitle("Congress Data")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showFilters.toggle() }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                FilterView(viewModel: viewModel)
            }
            .navigationDestination(for: Bill.self) { bill in
                BillDetailView(bill: bill)
            }
            .onAppear {
                if viewModel.bills.isEmpty && viewModel.members.isEmpty && viewModel.treaties.isEmpty {
                    viewModel.resetAndLoad()
                }
            }
        }
    }
}

// MARK: - Subviews

struct BillRow: View {
    let bill: Bill
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(bill.formattedTitle)
                .font(.headline)
                .lineLimit(2)
            
            HStack {
                Text("\(bill.formattedType) \(bill.number ?? "")")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                
                Text("• \(bill.congress ?? 0)th Congress")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let action = bill.latestAction?.text {
                Text(action)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TreatyRow: View {
    let treaty: Treaty
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(treaty.topic ?? "Unknown Treaty")
                .font(.headline)
                .lineLimit(2)
            
            HStack {
                Text(treaty.displayTitle)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(4)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(4)
                
                // Cleaned up: Removed "Received:" text
                Text("• \(treaty.congressReceived ?? 0)th Congress")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Cleaned up: Removed "Transmitted:" label, just showing nice date
            if let date = formatISODate(treaty.transmittedDate) {
                Text(date)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MemberRow: View {
    let member: Member
    
    var body: some View {
        HStack(spacing: 12) {
            if let urlString = member.depiction?.imageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(Text(String(member.name?.prefix(1) ?? "?")))
            }
            
            VStack(alignment: .leading) {
                Text(member.name ?? "Unknown")
                    .font(.headline)
                
                Text("\(member.partyName ?? "N/A") • \(member.state ?? "")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct FilterView: View {
    @ObservedObject var viewModel: CongressViewModel
    @Environment(\.dismiss) var dismiss
    
    let states = ["AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA","HI","ID","IL","IN","IA","KS","KY","LA","ME","MD","MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ","NM","NY","NC","ND","OH","OK","OR","PA","RI","SC","SD","TN","TX","UT","VT","VA","WA","WV","WI","WY"]
    
    var body: some View {
        NavigationView {
            Form {
                if viewModel.selectedTab == .bills || viewModel.selectedTab == .treaties {
                    Section(header: Text("Congress")) {
                        Picker("Congress Session", selection: $viewModel.selectedCongress) {
                            ForEach((100...118).reversed(), id: \.self) { i in
                                Text("\(i)th Congress").tag(i)
                            }
                        }
                    }
                }
                
                if viewModel.selectedTab == .bills {
                    Section(header: Text("Bill Type")) {
                        Picker("Type", selection: $viewModel.selectedBillType) {
                            Text("All").tag("")
                            Text("HR").tag("hr")
                            Text("S").tag("s")
                            Text("H.Res").tag("hres")
                            Text("S.Res").tag("sres")
                        }
                    }
                }
                
                if viewModel.selectedTab == .members {
                    Section(header: Text("Location")) {
                        Picker("State", selection: $viewModel.selectedState) {
                            Text("All").tag("")
                            ForEach(states, id: \.self) { state in
                                Text(state).tag(state)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                Button("Done") {
                    viewModel.resetAndLoad()
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Detail Views

struct BillDetailView: View {
    let bill: Bill
    @State private var fullBillURL: URL?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(bill.formattedTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack {
                        Badge(text: "\(bill.formattedType) \(bill.number ?? "")", color: .blue)
                        Badge(text: "\(bill.congress ?? 0)th Congress", color: .gray)
                        if let chamber = bill.originChamber {
                            Badge(text: chamber, color: .orange)
                        }
                    }
                }
                
                Divider()
                
                // Latest Action
                if let action = bill.latestAction {
                    VStack(alignment: .leading, spacing: 5) {
                        Label("Latest Action", systemImage: "clock")
                            .font(.headline)
                        
                        Text(action.text ?? "No description")
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        
                        if let date = formatISODate(action.actionDate) {
                            Text(date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // External Link
                if let url = generateCongressURL() {
                    Link(destination: url) {
                        HStack {
                            Text("View on Congress.gov")
                            Image(systemName: "arrow.up.right")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func generateCongressURL() -> URL? {
        guard let congress = bill.congress, let type = bill.type, let number = bill.number else { return nil }
        
        var typeSlug = "bill"
        var chamber = "house"
        
        switch type.lowercased() {
        case "s": chamber = "senate"; typeSlug = "bill"
        case "hr": chamber = "house"; typeSlug = "bill"
        case "hres": chamber = "house"; typeSlug = "resolution"
        case "sres": chamber = "senate"; typeSlug = "resolution"
        default: break
        }
        
        return URL(string: "https://www.congress.gov/bill/\(congress)th-congress/\(chamber)-\(typeSlug)/\(number)")
    }
}

struct Badge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}
