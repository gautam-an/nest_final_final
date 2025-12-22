import SwiftUI

// MARK: - Models

struct CongressResponse<T: Codable>: Codable {
    let bills: [BillListRaw]?
    let treaties: [TreatyListRaw]?
    let members: [MemberListRaw]?
    let pagination: Pagination?
    
    // Wrappers for detail responses
    let bill: BillDetail?
    let treaty: TreatyDetail?
    let member: MemberDetail?
    let sponsoredLegislation: [SponsoredBillRaw]?
}

struct Pagination: Codable {
    let count: Int?
    let next: String?
}

// -- List Models --

struct BillListRaw: Codable, Identifiable, Hashable {
    let congress: Int?
    let type: String?
    let originChamber: String?
    let number: String?
    let title: String?
    let updateDate: String?
    let latestAction: Action?
    
    var id: String { "\(congress ?? 0)-\(type ?? "")-\(number ?? "")" }
}

struct TreatyListRaw: Codable, Identifiable, Hashable {
    let number: Int?
    let suffix: String?
    let congressReceived: Int?
    let topic: String?
    let transmittedDate: String?
    
    var id: String { "\(congressReceived ?? 0)-\(number ?? 0)-\(suffix ?? "")" }
}

struct MemberListRaw: Codable, Identifiable, Hashable {
    let bioguideId: String
    let name: String?
    let state: String?
    let district: Int?
    let partyName: String?
    let depiction: Depiction?
    let terms: MemberTerms?
    
    var id: String { bioguideId }
}

struct SponsoredBillRaw: Codable, Identifiable, Hashable {
    let congress: Int?
    let type: String?
    let number: String?
    let title: String?
    let latestAction: Action?
    
    var id: String { "\(congress ?? 0)-\(type ?? "")-\(number ?? "")" }
}

// -- Detail Models --

struct BillDetail: Codable {
    let congress: Int?
    let type: String?
    let number: String?
    let title: String?
    let originChamber: String?
    let introducedDate: String?
    let updateDate: String?
    let policyArea: PolicyArea?
    let sponsors: [Sponsor]?
    let latestAction: Action?
    let summaries: [SummaryWrapper]?
    let committees: CommitteesWrapper?
    let actions: ActionsWrapper?
    
    struct PolicyArea: Codable {
        let name: String?
    }
    
    struct Sponsor: Codable, Hashable {
        let bioguideId: String?
        let fullName: String?
        let state: String?
        let party: String?
    }
    
    struct SummaryWrapper: Codable {
        let text: String?
    }
    
    struct CommitteesWrapper: Codable {
        let count: Int?
        let url: String?
    }
    
    struct ActionsWrapper: Codable {
        let count: Int?
        let url: String?
    }
}

struct TreatyDetail: Codable {
    let number: Int?
    let suffix: String?
    let congressReceived: Int?
    let topic: String?
    let transmittedDate: String?
    let inForceDate: String?
    let countriesParties: [CountryParty]?
    let indexTerms: [IndexTerm]?
    
    struct CountryParty: Codable, Hashable {
        let name: String?
    }
    
    struct IndexTerm: Codable, Hashable {
        let name: String?
    }
}

struct MemberDetail: Codable {
    let bioguideId: String
    let name: String? // usually directOrderName or similar in detail
    let birthYear: String?
    let directOrderName: String?
    let partyHistory: [PartyHistoryItem]?
    let depiction: Depiction?
    
    struct PartyHistoryItem: Codable, Hashable {
        let partyName: String?
        let startYear: Int?
    }
}

// -- Shared Sub-Models --

struct Action: Codable, Hashable {
    let actionDate: String?
    let text: String?
}

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

// MARK: - Navigation

enum CongressRoute: Hashable {
    case billDetail(congress: Int, type: String, number: String)
    case treatyDetail(congress: Int, number: Int, suffix: String?)
    case memberDetail(bioguideId: String)
}

// MARK: - API Manager

class APIManager {
    static let shared = APIManager()
    private let apiKey = "c3yejfiNvHRNh8eu5uT4JzUQmqEbBLh0wPXV2NWT"
    private let baseURL = "https://api.congress.gov/v3"
    
    func fetch<T: Decodable>(endpoint: String, params: [String: String] = [:]) async throws -> T {
        var urlComp = URLComponents(string: baseURL + endpoint)!
        var queryItems = [URLQueryItem(name: "api_key", value: apiKey), URLQueryItem(name: "format", value: "json")]
        for (key, value) in params {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        urlComp.queryItems = queryItems
        
        guard let url = urlComp.url else { throw URLError(.badURL) }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("Decoding error for \(endpoint): \(error)")
            throw error
        }
    }
}

// MARK: - View Models

@MainActor
class CongressListViewModel: ObservableObject {
    @Published var bills: [BillListRaw] = []
    @Published var treaties: [TreatyListRaw] = []
    @Published var members: [MemberListRaw] = []
    
    @Published var selectedTab: Tab = .bills
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Filters
    @Published var selectedCongress: Int = 118
    @Published var selectedBillType: String = ""
    @Published var selectedState: String = ""
    
    private var offset = 0
    private let limit = 20
    private var canLoadMore = true
    
    enum Tab: String, CaseIterable {
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
        do {
            let endpoint: String
            switch selectedTab {
            case .bills:
                endpoint = "/bill/\(selectedCongress)" + (selectedBillType.isEmpty ? "" : "/\(selectedBillType)")
            case .treaties:
                endpoint = "/treaty/\(selectedCongress)"
            case .members:
                endpoint = selectedState.isEmpty ? "/member" : "/member/\(selectedState)"
            }
            
            let params = ["offset": "\(offset)", "limit": "\(limit)"]
            
            switch selectedTab {
            case .bills:
                let res: CongressResponse<BillListRaw> = try await APIManager.shared.fetch(endpoint: endpoint, params: params)
                if let items = res.bills {
                    let unique = items.filter { n in !bills.contains(where: { $0.id == n.id }) }
                    bills.append(contentsOf: unique)
                    canLoadMore = items.count >= limit
                } else { canLoadMore = false }
                
            case .treaties:
                let res: CongressResponse<TreatyListRaw> = try await APIManager.shared.fetch(endpoint: endpoint, params: params)
                if let items = res.treaties {
                    let unique = items.filter { n in !treaties.contains(where: { $0.id == n.id }) }
                    treaties.append(contentsOf: unique)
                    canLoadMore = items.count >= limit
                } else { canLoadMore = false }
                
            case .members:
                // For members list, usually want current members unless filtered by congress
                // If using /member, we might want currentMember=true if no other filter
                var memParams = params
                if selectedState.isEmpty { memParams["currentMember"] = "true" }
                
                let res: CongressResponse<MemberListRaw> = try await APIManager.shared.fetch(endpoint: endpoint, params: memParams)
                if let items = res.members {
                    let unique = items.filter { n in !members.contains(where: { $0.id == n.id }) }
                    members.append(contentsOf: unique)
                    canLoadMore = items.count >= limit
                } else { canLoadMore = false }
            }
            offset += limit
            
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Main Views

struct CongressView: View {
    @StateObject private var vm = CongressListViewModel()
    @State private var showFilters = false
    @State private var navPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navPath) {
            VStack(spacing: 0) {
                Picker("Category", selection: $vm.selectedTab) {
                    ForEach(CongressListViewModel.Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: vm.selectedTab) { _, _ in vm.resetAndLoad() }
                
                List {
                    switch vm.selectedTab {
                    case .bills:
                        ForEach(vm.bills) { bill in
                            NavigationLink(value: CongressRoute.billDetail(congress: bill.congress ?? 118, type: bill.type ?? "hr", number: bill.number ?? "1")) {
                                BillListRow(bill: bill)
                            }
                        }
                    case .treaties:
                        ForEach(vm.treaties) { treaty in
                            NavigationLink(value: CongressRoute.treatyDetail(congress: treaty.congressReceived ?? 118, number: treaty.number ?? 0, suffix: treaty.suffix)) {
                                TreatyListRow(treaty: treaty)
                            }
                        }
                    case .members:
                        ForEach(vm.members) { member in
                            NavigationLink(value: CongressRoute.memberDetail(bioguideId: member.bioguideId)) {
                                MemberListRow(member: member)
                            }
                        }
                    }
                    
                    if vm.isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else {
                        Color.clear.onAppear { vm.loadMore() }
                    }
                }
                .listStyle(.plain)
                .refreshable { vm.resetAndLoad() }
            }
            .navigationTitle(vm.selectedTab.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showFilters.toggle() }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                FilterView(vm: vm)
            }
            .navigationDestination(for: CongressRoute.self) { route in
                switch route {
                case .billDetail(let c, let t, let n):
                    BillDetailView(congress: c, type: t, number: n)
                case .treatyDetail(let c, let n, let s):
                    TreatyDetailView(congress: c, number: n, suffix: s)
                case .memberDetail(let id):
                    MemberDetailView(bioguideId: id)
                }
            }
            .onAppear {
                if vm.bills.isEmpty && vm.members.isEmpty && vm.treaties.isEmpty {
                    vm.resetAndLoad()
                }
            }
        }
    }
}

// MARK: - Row Views

struct BillListRow: View {
    let bill: BillListRaw
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(bill.title ?? "Untitled")
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
            
            HStack {
                Text(bill.type?.uppercased() ?? "BILL")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                
                Text(bill.number ?? "")
                    .font(.caption2)
                    .fontWeight(.bold)
                
                Spacer()
                
                if let date = formatISODate(bill.latestAction?.actionDate ?? bill.updateDate) {
                    Text(date)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct TreatyListRow: View {
    let treaty: TreatyListRaw
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(treaty.topic ?? "Unknown Treaty")
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
            
            HStack {
                Text("Treaty \(treaty.number ?? 0)\(treaty.suffix ?? "")")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(4)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(4)
                
                Spacer()
                
                if let date = formatISODate(treaty.transmittedDate) {
                    Text(date)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct MemberListRow: View {
    let member: MemberListRaw
    
    var body: some View {
        HStack(spacing: 12) {
            if let urlString = member.depiction?.imageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                Circle().fill(Color.gray.opacity(0.2)).frame(width: 44, height: 44)
            }
            
            VStack(alignment: .leading) {
                Text(member.name ?? "Unknown")
                    .font(.body)
                    .fontWeight(.medium)
                Text("\(member.partyName ?? "") • \(member.state ?? "")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Detail Views

struct BillDetailView: View {
    let congress: Int
    let type: String
    let number: String
    
    @State private var detail: BillDetail?
    @State private var loading = true
    
    var body: some View {
        ScrollView {
            if loading {
                ProgressView().padding(.top, 50)
            } else if let detail = detail {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(detail.title ?? "Untitled")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        HStack {
                            Badge(text: "\(detail.type?.uppercased() ?? "") \(detail.number ?? "")", color: .blue)
                            Badge(text: "\(detail.congress ?? 0)th Congress", color: .gray)
                            if let chamber = detail.originChamber {
                                Badge(text: chamber, color: .orange)
                            }
                        }
                    }
                    
                    Divider()
                    
                    if let policy = detail.policyArea?.name {
                        VStack(alignment: .leading) {
                            Text("Policy Area").font(.caption).foregroundColor(.secondary)
                            Text(policy).font(.body)
                        }
                    }
                    
                    if let introduced = formatISODate(detail.introducedDate) {
                        VStack(alignment: .leading) {
                            Text("Introduced").font(.caption).foregroundColor(.secondary)
                            Text(introduced).font(.body)
                        }
                    }
                    
                    if let latest = detail.latestAction {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Latest Action").font(.caption).foregroundColor(.secondary)
                            Text(latest.text ?? "")
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            if let date = formatISODate(latest.actionDate) {
                                Text(date).font(.caption2).foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if let sponsors = detail.sponsors, !sponsors.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Sponsor").font(.caption).foregroundColor(.secondary)
                            ForEach(sponsors, id: \.self) { sponsor in
                                NavigationLink(value: CongressRoute.memberDetail(bioguideId: sponsor.bioguideId ?? "")) {
                                    HStack {
                                        Text(sponsor.fullName ?? "Unknown")
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.caption)
                                    }
                                    .padding(.vertical, 4)
                                    .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                    
                    Link(destination: generateCongressURL()) {
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
                .padding()
            } else {
                Text("Failed to load details").foregroundColor(.red).padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                let res: CongressResponse<BillDetail> = try await APIManager.shared.fetch(endpoint: "/bill/\(congress)/\(type.lowercased())/\(number)")
                self.detail = res.bill
            } catch {
                print(error)
            }
            loading = false
        }
    }
    
    func generateCongressURL() -> URL {
        var typeSlug = "bill"
        var chamber = "house"
        switch type.lowercased() {
        case "s", "sres", "sjres", "sconres": chamber = "senate"
        default: chamber = "house"
        }
        
        // Simplified mapping for URL generation
        if type.lowercased().contains("res") { typeSlug = "resolution" }
        
        return URL(string: "https://www.congress.gov/bill/\(congress)th-congress/\(chamber)-\(typeSlug)/\(number)")!
    }
}

struct TreatyDetailView: View {
    let congress: Int
    let number: Int
    let suffix: String?
    
    @State private var detail: TreatyDetail?
    @State private var loading = true
    
    var body: some View {
        ScrollView {
            if loading {
                ProgressView().padding(.top, 50)
            } else if let detail = detail {
                VStack(alignment: .leading, spacing: 16) {
                    Text(detail.topic ?? "Treaty")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack {
                        Badge(text: "Treaty \(detail.number ?? 0)\(detail.suffix ?? "")", color: .purple)
                        Badge(text: "Received: \(detail.congressReceived ?? 0)th", color: .gray)
                    }
                    
                    Divider()
                    
                    if let date = formatISODate(detail.transmittedDate) {
                        VStack(alignment: .leading) {
                            Text("Transmitted Date").font(.caption).foregroundColor(.secondary)
                            Text(date).font(.body)
                        }
                    }
                    
                    if let parties = detail.countriesParties, !parties.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Parties").font(.caption).foregroundColor(.secondary)
                            Text(parties.compactMap { $0.name }.joined(separator: ", "))
                        }
                    }
                    
                    if let terms = detail.indexTerms, !terms.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Index Terms").font(.caption).foregroundColor(.secondary)
                            ForEach(terms, id: \.self) { term in
                                Text("• " + (term.name ?? "")).font(.caption)
                            }
                        }
                    }
                    
                    Link(destination: URL(string: "https://www.congress.gov/treaty-document/\(congress)th-congress/\(number)")!) {
                        HStack {
                            Text("View on Congress.gov")
                            Image(systemName: "arrow.up.right")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
        .task {
            do {
                let s = suffix ?? ""
                let endpoint = s.isEmpty ? "/treaty/\(congress)/\(number)" : "/treaty/\(congress)/\(number)/\(s)"
                let res: CongressResponse<TreatyDetail> = try await APIManager.shared.fetch(endpoint: endpoint)
                self.detail = res.treaty
            } catch {
                print(error)
            }
            loading = false
        }
    }
}

struct MemberDetailView: View {
    let bioguideId: String
    
    @State private var detail: MemberDetail?
    @State private var sponsored: [SponsoredBillRaw] = []
    @State private var loading = true
    
    var body: some View {
        ScrollView {
            if loading {
                ProgressView().padding(.top, 50)
            } else if let member = detail {
                VStack(alignment: .leading, spacing: 16) {
                    
                    HStack(spacing: 16) {
                        if let urlString = member.depiction?.imageUrl, let url = URL(string: urlString) {
                            AsyncImage(url: url) { img in
                                img.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: { Color.gray.opacity(0.3) }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                        }
                        
                        VStack(alignment: .leading) {
                            Text(member.directOrderName ?? member.name ?? "Unknown")
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            if let history = member.partyHistory?.last {
                                Text(history.partyName ?? "")
                                    .foregroundColor(.secondary)
                            }
                            Text("Bioguide: \(member.bioguideId)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Divider()
                    
                    Text("Sponsored Legislation")
                        .font(.headline)
                    
                    if sponsored.isEmpty {
                        Text("No recent sponsored legislation found.").font(.caption).foregroundColor(.gray)
                    } else {
                        ForEach(sponsored) { bill in
                            NavigationLink(value: CongressRoute.billDetail(congress: bill.congress ?? 118, type: bill.type ?? "hr", number: bill.number ?? "1")) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bill.title ?? "Untitled")
                                        .font(.subheadline)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(2)
                                        .foregroundColor(.primary)
                                    
                                    HStack {
                                        Text("\(bill.type?.uppercased() ?? "") \(bill.number ?? "")")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .padding(2)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(4)
                                        Spacer()
                                        if let date = formatISODate(bill.latestAction?.actionDate) {
                                            Text(date).font(.caption2).foregroundColor(.gray)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 4)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .task {
            do {
                // Fetch Member Info
                let res: CongressResponse<MemberDetail> = try await APIManager.shared.fetch(endpoint: "/member/\(bioguideId)")
                self.detail = res.member
                
                // Fetch Sponsored
                let sponsoredRes: CongressResponse<SponsoredBillRaw> = try await APIManager.shared.fetch(endpoint: "/member/\(bioguideId)/sponsored-legislation", params: ["limit": "10"])
                self.sponsored = sponsoredRes.sponsoredLegislation ?? []
            } catch {
                print(error)
            }
            loading = false
        }
    }
}

// MARK: - Filter View

struct FilterView: View {
    @ObservedObject var vm: CongressListViewModel
    @Environment(\.dismiss) var dismiss
    
    let states = ["AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA","HI","ID","IL","IN","IA","KS","KY","LA","ME","MD","MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ","NM","NY","NC","ND","OH","OK","OR","PA","RI","SC","SD","TN","TX","UT","VT","VA","WA","WV","WI","WY"]
    
    var body: some View {
        NavigationStack {
            Form {
                if vm.selectedTab == .bills || vm.selectedTab == .treaties {
                    Section(header: Text("Congress")) {
                        Picker("Congress Session", selection: $vm.selectedCongress) {
                            ForEach((100...118).reversed(), id: \.self) { i in
                                Text("\(i)th Congress").tag(i)
                            }
                        }
                    }
                }
                
                if vm.selectedTab == .bills {
                    Section(header: Text("Bill Type")) {
                        Picker("Type", selection: $vm.selectedBillType) {
                            Text("All").tag("")
                            Text("HR").tag("hr")
                            Text("S").tag("s")
                            Text("H.Res").tag("hres")
                            Text("S.Res").tag("sres")
                        }
                    }
                }
                
                if vm.selectedTab == .members {
                    Section(header: Text("Location")) {
                        Picker("State", selection: $vm.selectedState) {
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
                    vm.resetAndLoad()
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Helpers

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

func formatISODate(_ iso: String?) -> String? {
    guard let iso, !iso.isEmpty else { return nil }
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime]
    let simpleFormatter = DateFormatter()
    simpleFormatter.dateFormat = "yyyy-MM-dd"
    let out = DateFormatter()
    out.dateStyle = .medium
    
    if let date = isoFormatter.date(from: iso) { return out.string(from: date) }
    if let date = simpleFormatter.date(from: iso) { return out.string(from: date) }
    return iso.replacingOccurrences(of: "T00:00:00Z", with: "")
}
