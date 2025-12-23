import SwiftUI

// MARK: - API CONFIGURATION
let API_KEY = "c3yejfiNvHRNh8eu5uT4JzUQmqEbBLh0wPXV2NWT"
let BASE_URL = "https://api.congress.gov/v3"

// MARK: - UTILITIES

// Helper to remove duplicates
extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

struct DateUtils {
    static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return f
    }()
    
    static let simpleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    
    static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
    
    static func parse(_ string: String?) -> Date {
        guard let string = string else { return Date.distantPast }
        if let date = isoFormatter.date(from: string) { return date }
        if let date = simpleFormatter.date(from: string) { return date }
        return Date.distantPast
    }
    
    static func format(_ string: String?) -> String {
        let date = parse(string)
        if date == Date.distantPast { return string ?? "N/A" }
        return displayFormatter.string(from: date)
    }
}

struct YearFormatter {
    static func format(_ year: Int?) -> String {
        guard let year = year else { return "" }
        return String(format: "%d", year)
    }
}

struct URLBuilder {
    static func bill(congress: Int, type: String, number: String) -> URL? {
        let map = [
            "hr": "house-bill", "s": "senate-bill",
            "hjres": "house-joint-resolution", "sjres": "senate-joint-resolution",
            "hconres": "house-concurrent-resolution", "sconres": "senate-concurrent-resolution",
            "hres": "house-resolution", "sres": "senate-resolution"
        ]
        let chamberType = map[type.lowercased()] ?? "bill"
        return URL(string: "https://www.congress.gov/bill/\(congress)th-congress/\(chamberType)/\(number)")
    }
    
    static func treaty(congress: Int, number: Int, suffix: String?) -> URL? {
        let s = suffix ?? ""
        return URL(string: "https://www.congress.gov/treaty-document/\(congress)th-congress/\(number)\(s)")
    }
}

// MARK: - MODELS

struct FlexibleWrapper<T: Codable>: Codable {
    let item: [T]
    
    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            if let list = try? container.decode([T].self, forKey: .item) {
                self.item = list
                return
            }
        }
        if let list = try? decoder.singleValueContainer().decode([T].self) {
            self.item = list
            return
        }
        self.item = []
    }
    
    enum CodingKeys: String, CodingKey {
        case item
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(item, forKey: .item)
    }
}

// -- RESPONSE ROOTS --

struct CongressResponse<T: Codable>: Codable {
    let bills: [BillListRaw]?
    let treaties: [TreatyListRaw]?
    let members: [MemberListRaw]?
}

// -- LIST MODELS --

struct BillListRaw: Codable, Identifiable, Hashable {
    let congress: Int?
    let type: String?
    let number: String?
    let title: String?
    let updateDate: String?
    let latestAction: ActionRaw?
    
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
    let partyName: String?
    let depiction: Depiction?
    
    var id: String { bioguideId }
}

// -- DETAIL MODELS --

struct BillDetailResponse: Codable { let bill: BillDetail? }
struct BillDetail: Codable {
    let congress: Int?
    let type: String?
    let number: String?
    let title: String?
    let introducedDate: String?
    let sponsors: FlexibleWrapper<SponsorRaw>?
}

struct TreatyDetailResponse: Codable { let treaty: TreatyDetail? }
struct TreatyDetail: Codable {
    let congressReceived: Int?
    let congressConsidered: Int?
    let number: Int?
    let suffix: String?
    let topic: String?
    let transmittedDate: String?
    let inForceDate: String?
    let oldNumber: String?
    let oldNumberDisplayName: String?
    
    let countriesParties: FlexibleWrapper<CountryParty>?
    let indexTerms: FlexibleWrapper<IndexTerm>?
    let relatedDocs: FlexibleWrapper<RelatedDoc>?
}

struct MemberDetailResponse: Codable { let member: MemberDetail? }
struct MemberDetail: Codable {
    let bioguideId: String?
    let directOrderName: String?
    let birthYear: String?
    let state: String?
    let district: Int?
    let partyHistory: FlexibleWrapper<PartyHistory>?
    let terms: FlexibleWrapper<TermRaw>?
    let leadership: FlexibleWrapper<Leadership>?
    let depiction: Depiction?
}

// -- SUB-MODELS --

struct ActionRaw: Codable, Hashable {
    let actionDate: String?
    let text: String?
}

struct Depiction: Codable, Hashable {
    let imageUrl: String?
}

struct SummaryRaw: Codable, Hashable {
    let actionDesc: String?
    let text: String?
}

struct CommitteeRaw: Codable, Hashable {
    let name: String?
}

struct SponsorRaw: Codable, Hashable {
    let fullName: String?
    let party: String?
    let state: String?
}

struct TextRaw: Codable, Hashable {
    let formats: [TextFormat]?
}

struct TextFormat: Codable, Hashable {
    let url: String?
}

struct CountryParty: Codable, Hashable {
    let name: String?
}

struct IndexTerm: Codable, Hashable {
    let name: String?
}

struct RelatedDoc: Codable, Hashable {
    let name: String?
    let url: String?
}

struct PartyHistory: Codable, Hashable {
    let partyName: String?
    let startYear: Int?
}

struct TermRaw: Codable, Hashable {
    let chamber: String?
    let startYear: Int?
    let endYear: Int?
}

struct Leadership: Codable, Hashable {
    let type: String?
    let congress: Int?
}

// -- SUB-RESPONSE CONTAINERS --
struct ActionsResponse: Codable { let actions: [ActionRaw]? }
struct SummariesResponse: Codable { let summaries: [SummaryRaw]? }
struct CommitteesResponse: Codable { let committees: [CommitteeRaw]? }
struct TreatyCommitteesResponse: Codable { let treatyCommittees: [CommitteeRaw]? }
struct CosponsorsResponse: Codable { let cosponsors: [SponsorRaw]? }
struct TextResponse: Codable { let textVersions: [TextRaw]? }
struct SponsoredLegislationResponse: Codable { let sponsoredLegislation: [BillListRaw]? }
struct CosponsoredLegislationResponse: Codable { let cosponsoredLegislation: [BillListRaw]? }


// MARK: - NETWORK MANAGER

class NetworkManager {
    static let shared = NetworkManager()
    
    func fetch<T: Codable>(endpoint: String, limit: Int = 250) async throws -> T {
        guard var components = URLComponents(string: BASE_URL + endpoint) else {
            throw URLError(.badURL)
        }
        
        components.queryItems = [
            URLQueryItem(name: "api_key", value: API_KEY),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "format", value: "json")
        ]
        
        guard let url = components.url else { throw URLError(.badURL) }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResp = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResp.statusCode != 200 {
            print("❌ API Error: \(httpResp.statusCode) on \(endpoint)")
            throw URLError(.badServerResponse)
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("❌ Decoding Error on \(endpoint): \(error)")
            throw error
        }
    }
}

// MARK: - VIEW MODELS

@MainActor
class MainViewModel: ObservableObject {
    @Published var bills: [BillListRaw] = []
    @Published var treaties: [TreatyListRaw] = []
    @Published var members: [MemberListRaw] = []
    
    // Default to 119th Congress
    @Published var congress = 119
    @Published var billType = ""
    @Published var state = ""
    @Published var isLoading = false
    
    func loadBills() async {
        isLoading = true
        defer { isLoading = false }
        let path = billType.isEmpty ? "/bill/\(congress)" : "/bill/\(congress)/\(billType)"
        
        if let res: CongressResponse<BillListRaw> = try? await NetworkManager.shared.fetch(endpoint: path) {
            let allBills = res.bills ?? []
            var seen = Set<String>()
            let uniqueBills = allBills.filter { seen.insert($0.id).inserted }
            
            self.bills = uniqueBills.sorted {
                DateUtils.parse($0.updateDate) > DateUtils.parse($1.updateDate)
            }
        }
    }
    
    func loadTreaties() async {
        isLoading = true
        defer { isLoading = false }
        
        // CHANGED: Use /treaty (ALL) instead of filtered by congress
        if let res: CongressResponse<TreatyListRaw> = try? await NetworkManager.shared.fetch(endpoint: "/treaty", limit: 250) {
            let allTreaties = res.treaties ?? []
            var seen = Set<String>()
            let uniqueTreaties = allTreaties.filter { seen.insert($0.id).inserted }
            
            self.treaties = uniqueTreaties.sorted {
                DateUtils.parse($0.transmittedDate) > DateUtils.parse($1.transmittedDate)
            }
        }
    }
    
    func loadMembers() async {
        isLoading = true
        defer { isLoading = false }
        
        // Filters by specific Congress to avoid dead/past members (unless user selects older congress)
        var path = "/member/congress/\(congress)"
        if !state.isEmpty {
            path += "/\(state)"
        }
        
        if let res: CongressResponse<MemberListRaw> = try? await NetworkManager.shared.fetch(endpoint: path) {
            let allMembers = res.members ?? []
            var seen = Set<String>()
            self.members = allMembers.filter { seen.insert($0.id).inserted }
        }
    }
}

@MainActor
class DetailViewModel: ObservableObject {
    @Published var bill: BillDetail?
    @Published var treaty: TreatyDetail?
    @Published var member: MemberDetail?
    
    @Published var actions: [ActionRaw] = []
    @Published var summaries: [SummaryRaw] = []
    @Published var committees: [CommitteeRaw] = []
    @Published var cosponsors: [SponsorRaw] = []
    @Published var text: [TextRaw] = []
    @Published var sponsored: [BillListRaw] = []
    @Published var cosponsored: [BillListRaw] = []
    
    @Published var loading = false
    @Published var errorMessage: String?
    
    func fetchBill(_ congress: Int, _ type: String, _ number: String) async {
        loading = true
        errorMessage = nil
        defer { loading = false }
        
        let base = "/bill/\(congress)/\(type.lowercased())/\(number)"
        
        do {
            let res: BillDetailResponse = try await NetworkManager.shared.fetch(endpoint: base)
            self.bill = res.bill
            
            async let a: ActionsResponse? = try? NetworkManager.shared.fetch(endpoint: base + "/actions")
            async let s: SummariesResponse? = try? NetworkManager.shared.fetch(endpoint: base + "/summaries")
            async let c: CommitteesResponse? = try? NetworkManager.shared.fetch(endpoint: base + "/committees")
            async let co: CosponsorsResponse? = try? NetworkManager.shared.fetch(endpoint: base + "/cosponsors")
            async let txt: TextResponse? = try? NetworkManager.shared.fetch(endpoint: base + "/text")
            
            let (act, sum, com, cosp, tex) = await (a, s, c, co, txt)
            
            self.actions = (act?.actions ?? []).uniqued()
            self.summaries = sum?.summaries ?? []
            self.committees = com?.committees ?? []
            self.cosponsors = cosp?.cosponsors ?? []
            self.text = tex?.textVersions ?? []
            
        } catch {
            self.errorMessage = "Unable to load bill details."
            print(error)
        }
    }
    
    func fetchTreaty(_ congress: Int, _ number: Int, _ suffix: String?) async {
        loading = true
        errorMessage = nil
        defer { loading = false }
        
        let s = suffix != nil ? "/\(suffix!)" : ""
        let base = "/treaty/\(congress)/\(number)\(s)"
        
        do {
            let res: TreatyDetailResponse = try await NetworkManager.shared.fetch(endpoint: base)
            self.treaty = res.treaty
            
            async let a: ActionsResponse? = try? NetworkManager.shared.fetch(endpoint: base + "/actions")
            async let c: TreatyCommitteesResponse? = try? NetworkManager.shared.fetch(endpoint: base + "/committees")
            
            let (act, com) = await (a, c)
            
            self.actions = (act?.actions ?? []).uniqued()
            self.committees = com?.treatyCommittees ?? []
            
        } catch {
            self.errorMessage = "Unable to load treaty details."
        }
    }
    
    func fetchMember(_ id: String) async {
        loading = true
        errorMessage = nil
        defer { loading = false }
        
        do {
            let res: MemberDetailResponse = try await NetworkManager.shared.fetch(endpoint: "/member/\(id)")
            self.member = res.member
            
            async let s: SponsoredLegislationResponse? = try? NetworkManager.shared.fetch(endpoint: "/member/\(id)/sponsored-legislation")
            async let c: CosponsoredLegislationResponse? = try? NetworkManager.shared.fetch(endpoint: "/member/\(id)/cosponsored-legislation")
            
            let (spon, cospon) = await (s, c)
            self.sponsored = spon?.sponsoredLegislation ?? []
            self.cosponsored = cospon?.cosponsoredLegislation ?? []
            
        } catch {
            self.errorMessage = "Unable to load member details."
        }
    }
}

// MARK: - VIEWS

struct CongressView: View {
    @StateObject var vm = MainViewModel()
    @State private var tab = 0
    @State private var showFilter = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    Text("Bills").tag(0)
                    Text("Treaties").tag(1)
                    Text("Members").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                if tab == 0 {
                    List(vm.bills) { bill in
                        NavigationLink(destination: BillDetailView(raw: bill)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(bill.title ?? "Untitled").font(.headline).lineLimit(2)
                                HStack {
                                    Text("\(bill.type?.uppercased() ?? "") \(bill.number ?? "")")
                                        .bold().font(.caption)
                                        .padding(4).background(Color.blue.opacity(0.1)).cornerRadius(4)
                                    Spacer()
                                    Text(DateUtils.format(bill.updateDate)).font(.caption).foregroundColor(.secondary)
                                }
                                Text(bill.latestAction?.text ?? "").font(.caption).foregroundColor(.gray).lineLimit(1)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await vm.loadBills() }
                } else if tab == 1 {
                    List(vm.treaties) { treaty in
                        NavigationLink(destination: TreatyDetailView(raw: treaty)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(treaty.topic ?? "Treaty").font(.headline).lineLimit(2)
                                HStack {
                                    Text("Treaty \(treaty.number ?? 0)\(treaty.suffix ?? "")")
                                        .bold().font(.caption)
                                        .padding(4).background(Color.purple.opacity(0.1)).cornerRadius(4)
                                    Spacer()
                                    Text(DateUtils.format(treaty.transmittedDate)).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await vm.loadTreaties() }
                } else {
                    List(vm.members) { member in
                        NavigationLink(destination: MemberDetailView(raw: member)) {
                            HStack {
                                if let url = member.depiction?.imageUrl {
                                    AsyncImage(url: URL(string: url)) { i in
                                        i.resizable().scaledToFill()
                                    } placeholder: {
                                        Image(systemName: "person.crop.circle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .foregroundColor(.gray.opacity(0.5))
                                    }
                                    .frame(width: 44, height: 44).clipShape(Circle())
                                } else {
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 44, height: 44)
                                        .foregroundColor(.gray.opacity(0.5))
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(member.name ?? "").font(.headline)
                                    Text("\(member.partyName ?? "") • \(member.state ?? "")").font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await vm.loadMembers() }
                }
            }
            .navigationTitle("Congress")
            .toolbar {
                Button(action: { showFilter.toggle() }) {
                    Image(systemName: "slider.horizontal.3")
                }
            }
            .sheet(isPresented: $showFilter) {
                FilterView(vm: vm, tab: tab)
            }
        }
        .task { await vm.loadBills() }
        .onChange(of: tab) { newVal in
            Task {
                if newVal == 0 { await vm.loadBills() }
                else if newVal == 1 { await vm.loadTreaties() }
                else { await vm.loadMembers() }
            }
        }
    }
}

struct BillDetailView: View {
    let raw: BillListRaw
    @StateObject var vm = DetailViewModel()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if vm.loading {
                ProgressView("Loading...")
            } else if let err = vm.errorMessage {
                Text(err).foregroundColor(.red).padding()
            } else if let b = vm.bill {
                List {
                    Section {
                        Text(b.title ?? "").font(.headline)
                        HStack {
                            Text("Type: \(b.type?.uppercased() ?? "")")
                            Spacer()
                            Text("No: \(b.number ?? "")")
                        }
                        Text("Introduced: \(DateUtils.format(b.introducedDate))")
                        if let s = b.sponsors?.item.first {
                            Text("Sponsor: \(s.fullName ?? "") (\(s.party ?? "")-\(s.state ?? ""))")
                        }
                    } header: { Text("Overview") }
                    
                    if !vm.summaries.isEmpty {
                        Section("Summaries") {
                            ForEach(vm.summaries, id: \.self) { s in
                                VStack(alignment: .leading) {
                                    Text(s.actionDesc ?? "").bold()
                                    Text(s.text?.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) ?? "").font(.caption)
                                }
                            }
                        }
                    }
                    
                    if !vm.actions.isEmpty {
                        Section("Actions") {
                            ForEach(vm.actions.prefix(10), id: \.self) { a in
                                HStack(alignment: .top) {
                                    Text(DateUtils.format(a.actionDate)).font(.caption).bold().frame(width: 80, alignment: .leading)
                                    Text(a.text ?? "").font(.caption)
                                }
                            }
                        }
                    }
                    
                    if !vm.committees.isEmpty {
                        Section("Committees") {
                            ForEach(vm.committees, id: \.self) { c in Text(c.name ?? "") }
                        }
                    }
                    
                    if !vm.cosponsors.isEmpty {
                        Section("Cosponsors (\(vm.cosponsors.count))") {
                            ScrollView(.horizontal) {
                                HStack {
                                    ForEach(vm.cosponsors, id: \.self) { c in
                                        Text(c.fullName ?? "").padding(6).background(Color.gray.opacity(0.1)).cornerRadius(5)
                                    }
                                }
                            }
                        }
                    }
                    
                    if let url = vm.text.first?.formats?.first?.url {
                        Link(destination: URL(string: url)!) {
                            Text("Read Full Text (PDF)")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Color.clear
                        .frame(height: 60)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.insetGrouped)
            }
            
            if let b = vm.bill, let url = URLBuilder.bill(congress: b.congress ?? 0, type: b.type ?? "", number: b.number ?? "") {
                Link(destination: url) {
                    Text("View on Congress.gov").bold().frame(maxWidth: .infinity)
                        .padding().background(Color.blue).foregroundColor(.white).cornerRadius(10)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .task { await vm.fetchBill(raw.congress ?? 118, raw.type ?? "", raw.number ?? "") }
    }
}

struct TreatyDetailView: View {
    let raw: TreatyListRaw
    @StateObject var vm = DetailViewModel()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if vm.loading {
                ProgressView("Loading...")
            } else if let err = vm.errorMessage {
                Text(err).foregroundColor(.red).padding()
            } else if let t = vm.treaty {
                List {
                    Section {
                        Text(t.topic ?? "").font(.headline)
                        Text("No: \(t.number ?? 0)\(t.suffix ?? "")")
                        Text("Transmitted: \(DateUtils.format(t.transmittedDate))")
                        if let f = t.inForceDate { Text("In Force: \(DateUtils.format(f))") }
                        if let cc = t.congressConsidered { Text("Considered: \(cc)th Congress") }
                        if let old = t.oldNumber { Text("Old Number: \(old)") }
                    } header: { Text("Details") }
                    
                    if let parties = t.countriesParties?.item, !parties.isEmpty {
                        Section("Parties") {
                            Text(parties.compactMap{$0.name}.joined(separator: ", "))
                        }
                    }
                    
                    if let terms = t.indexTerms?.item, !terms.isEmpty {
                         Section("Index Terms") {
                             Text(terms.compactMap{$0.name}.joined(separator: ", "))
                                 .font(.caption)
                         }
                    }
                    
                    if let docs = t.relatedDocs?.item, !docs.isEmpty {
                        Section("Executive Reports") {
                            ForEach(docs, id: \.self) { doc in
                                if let u = doc.url, let url = URL(string: u) {
                                    Link(doc.name ?? "Document", destination: url)
                                } else {
                                    Text(doc.name ?? "")
                                }
                            }
                        }
                    }
                    
                    if !vm.committees.isEmpty {
                        Section("Committees") {
                            ForEach(vm.committees, id: \.self) { c in
                                Text(c.name ?? "")
                            }
                        }
                    }
                    
                    if !vm.actions.isEmpty {
                        Section("Actions") {
                            ForEach(vm.actions, id: \.self) { a in
                                HStack {
                                    Text(DateUtils.format(a.actionDate)).font(.caption).bold().frame(width: 80, alignment: .leading)
                                    Text(a.text ?? "").font(.caption)
                                }
                            }
                        }
                    }
                    
                    Color.clear
                        .frame(height: 60)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.insetGrouped)
            }
            
            if let t = vm.treaty, let url = URLBuilder.treaty(congress: t.congressReceived ?? 0, number: t.number ?? 0, suffix: t.suffix) {
                Link(destination: url) {
                    Text("View on Congress.gov").bold().frame(maxWidth: .infinity)
                        .padding().background(Color.blue).foregroundColor(.white).cornerRadius(10)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .task { await vm.fetchTreaty(raw.congressReceived ?? 118, raw.number ?? 0, raw.suffix) }
    }
}

struct MemberDetailView: View {
    let raw: MemberListRaw
    @StateObject var vm = DetailViewModel()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if vm.loading {
                ProgressView("Loading...")
            } else if let err = vm.errorMessage {
                Text(err).foregroundColor(.red).padding()
            } else if let m = vm.member {
                List {
                    Section {
                        HStack {
                            if let url = m.depiction?.imageUrl {
                                AsyncImage(url: URL(string: url)) { i in
                                    i.resizable().scaledToFill()
                                } placeholder: {
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundColor(.gray.opacity(0.5))
                                }
                                .frame(width: 60, height: 60).clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                            
                            VStack(alignment: .leading) {
                                Text(m.directOrderName ?? "").font(.title2).bold()
                                Text("ID: \(m.bioguideId ?? "")").font(.caption)
                                if let state = m.state {
                                    Text("\(state)\(m.district != nil ? " - District \(m.district!)" : "")")
                                        .font(.subheadline).foregroundColor(.secondary)
                                }
                            }
                        }
                        if let ph = m.partyHistory?.item.last {
                            Text("Party: \(ph.partyName ?? "") (Since \(YearFormatter.format(ph.startYear)))")
                        }
                    } header: { Text("Profile") }
                    
                    if let leadership = m.leadership?.item {
                        Section("Leadership") {
                            ForEach(leadership, id: \.self) { l in
                                Text("\(l.type ?? "") (\(l.congress ?? 0)th)")
                            }
                        }
                    }
                    
                    if let terms = m.terms?.item {
                        Section("Terms") {
                            ForEach(terms.reversed(), id: \.self) { t in
                                Text("\(t.chamber ?? ""): \(YearFormatter.format(t.startYear))-\(t.endYear != nil ? YearFormatter.format(t.endYear) : "Present")")
                            }
                        }
                    }
                    
                    if !vm.sponsored.isEmpty {
                        Section("Sponsored Legislation") {
                            // Filter out untitled or empty bills
                            ForEach(vm.sponsored.prefix(5).filter { $0.title?.isEmpty == false && $0.title != "Untitled" }) { bill in
                                NavigationLink(destination: BillDetailView(raw: bill)) {
                                    VStack(alignment: .leading) {
                                        Text("\(bill.type?.uppercased() ?? "") \(bill.number ?? "")")
                                            .bold().font(.caption).foregroundColor(.blue)
                                        Text(bill.title ?? "Untitled").font(.caption).lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                    
                    if !vm.cosponsored.isEmpty {
                        Section("Cosponsored Legislation") {
                            // Filter out untitled or empty bills
                            ForEach(vm.cosponsored.prefix(5).filter { $0.title?.isEmpty == false && $0.title != "Untitled" }) { bill in
                                NavigationLink(destination: BillDetailView(raw: bill)) {
                                    VStack(alignment: .leading) {
                                        Text("\(bill.type?.uppercased() ?? "") \(bill.number ?? "")")
                                            .bold().font(.caption).foregroundColor(.blue)
                                        Text(bill.title ?? "Untitled").font(.caption).lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .task { await vm.fetchMember(raw.bioguideId) }
    }
}

struct FilterView: View {
    @ObservedObject var vm: MainViewModel
    let tab: Int
    @Environment(\.dismiss) var dismiss
    
    let states = [
        "AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "AR": "Arkansas", "CA": "California",
        "CO": "Colorado", "CT": "Connecticut", "DE": "Delaware", "FL": "Florida", "GA": "Georgia",
        "HI": "Hawaii", "ID": "Idaho", "IL": "Illinois", "IN": "Indiana", "IA": "Iowa",
        "KS": "Kansas", "KY": "Kentucky", "LA": "Louisiana", "ME": "Maine", "MD": "Maryland",
        "MA": "Massachusetts", "MI": "Michigan", "MN": "Minnesota", "MS": "Mississippi",
        "MO": "Missouri", "MT": "Montana", "NE": "Nebraska", "NV": "Nevada", "NH": "New Hampshire",
        "NJ": "New Jersey", "NM": "New Mexico", "NY": "New York", "NC": "North Carolina",
        "ND": "North Dakota", "OH": "Ohio", "OK": "Oklahoma", "OR": "Oregon", "PA": "Pennsylvania",
        "RI": "Rhode Island", "SC": "South Carolina", "SD": "South Dakota", "TN": "Tennessee",
        "TX": "Texas", "UT": "Utah", "VT": "Vermont", "VA": "Virginia", "WA": "Washington",
        "WV": "West Virginia", "WI": "Wisconsin", "WY": "Wyoming"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                // MESSAGE FOR TREATIES (TAB 1)
                if tab == 1 {
                    Section {
                        Text("There are no filters for this page.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                
                // FILTERS FOR BILLS (0) & MEMBERS (2)
                if tab == 0 || tab == 2 {
                    Section("Congress") {
                        Picker("Congress", selection: $vm.congress) {
                            ForEach((100...119).reversed(), id: \.self) { c in
                                Text("\(c)th").tag(c)
                            }
                        }
                    }
                }
                
                // FILTERS FOR BILLS ONLY
                if tab == 0 {
                    Section("Bill Type") {
                        Picker("Type", selection: $vm.billType) {
                            Text("All").tag("")
                            Text("HR").tag("hr")
                            Text("S").tag("s")
                        }
                    }
                }
                
                // FILTERS FOR MEMBERS ONLY
                if tab == 2 {
                    Section("State") {
                        Picker("State", selection: $vm.state) {
                            Text("All").tag("")
                            ForEach(states.keys.sorted { states[$0]! < states[$1]! }, id: \.self) { k in
                                Text(states[k]!).tag(k)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .toolbar { Button("Done") {
                Task {
                    if tab == 0 { await vm.loadBills() }
                    else if tab == 1 { await vm.loadTreaties() }
                    else { await vm.loadMembers() }
                }
                dismiss()
            }}
        }
    }
}
