import SwiftUI

struct Article: Identifiable, Decodable {
    var id: URL { url }
    var url: URL
    var title: String
    var bias: String
    var summary: String
    var category: String
    var publishedAt: String
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed != 0 ? seed : 0xdeadbeef
    }

    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2685821657736338717
    }
}

func computeSeed(from articles: [Article]) -> UInt64 {
    let words = articles.map { article -> String in
        let parts = article.title.split(separator: " ").map(String.init)
        if parts.count >= 2 {
            return parts[1]
        } else {
            return parts.first ?? ""
        }
    }

    let sorted = words.sorted { $0.lowercased() < $1.lowercased() }

    let numbers = sorted.map { word -> String in
        guard let lastChar = word.last else { return "26" }
        let scalar = lastChar.lowercased().unicodeScalars.first!
        if scalar.value >= 97 && scalar.value <= 122 {
            return String(Int(scalar.value - 97))
        } else {
            return "26"
        }
    }

    let concatenated = numbers.joined()
    return UInt64(concatenated) ?? 0
}

func deterministicShuffle(_ articles: [Article]) -> [Article] {
    let seed = computeSeed(from: articles)
    var rng = SeededGenerator(seed: seed)
    return articles.shuffled(using: &rng)
}

struct NewsFeedView: View {
    @State private var articles: [Article] = []
    @State private var showingTopicSettings = false
    @AppStorage("selectedTopics") private var storedTopics: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if selectedTopics.isEmpty {
                        Text("Please change your page settings in the top right to view articles.")
                            .italic()
                            .padding()
                    } else {
                        ForEach(articles) { article in
                            ArticleCardView(article: article)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("News Feed")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingTopicSettings = true
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
            .onAppear(perform: fetchArticlesForSelectedTopics)
            .sheet(isPresented: $showingTopicSettings) {
                TopicSettingsView(selectedTopics: $storedTopics, onSave: {
                    fetchArticlesForSelectedTopics()
                })
            }
        }
    }

    private var selectedTopics: [String] {
        storedTopics.components(separatedBy: ",").filter { !$0.isEmpty }
    }

    func fetchArticlesForSelectedTopics() {
        articles = []
        let baseURL = "https://raw.githubusercontent.com/JacobPercy/articles/main/article_cache/"
        guard !selectedTopics.isEmpty else { return }

        let group = DispatchGroup()
        var allFetchedArticles: [Article] = []

        for topic in selectedTopics {
            guard let url = URL(string: "\(baseURL)\(topic)_parsed.json") else { continue }

            group.enter()
            URLSession.shared.dataTask(with: url) { data, _, error in
                defer { group.leave() }
                if error != nil { return }
                guard let data = data else { return }
                if let decoded = try? JSONDecoder().decode([Article].self, from: data) {
                    allFetchedArticles.append(contentsOf: decoded)
                }
            }.resume()
        }

        group.notify(queue: .main) {
            self.articles = deterministicShuffle(allFetchedArticles)
        }
    }
}

struct TopicSettingsView: View {
    @Binding var selectedTopics: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    let availableTopics = ["technology", "economics", "environment", "international", "immigration"]

    private var selectedTopicsArray: [String] {
        selectedTopics.components(separatedBy: ",").filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Select your interests")) {
                    ForEach(availableTopics, id: \.self) { topic in
                        HStack {
                            Text(topic.capitalized)
                            Spacer()
                            if selectedTopicsArray.contains(topic) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleTopic(topic)
                        }
                    }
                }
            }
            .navigationTitle("Topics")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                onSave()
            }
        }
    }

    private func toggleTopic(_ topic: String) {
        var topics = selectedTopicsArray
        if let index = topics.firstIndex(of: topic) {
            topics.remove(at: index)
        } else {
            topics.append(topic)
        }
        selectedTopics = topics.joined(separator: ",")
    }
}

struct ArticleCardView: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: categoryIcon(for: article.category))
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(Color(red: 0.3, green: 0.6, blue: 0.9))
                    .frame(width: 60, height: 60)

                VStack(alignment: .leading, spacing: 4) {
                    Text(article.title)
                        .font(.system(size: dynamicTitleFontSize(for: article.title), weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)

                    Text(formattedDate(article.publishedAt))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            HStack {
                Text(article.bias.capitalized)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)

                Spacer()

                Text(article.category.capitalized)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            Text(article.summary)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Link("Read More", destination: article.url)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)

                Spacer()

                Button(action: {
                    shareArticle(article)
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    private func formattedDate(_ iso: String) -> String {
        let input = ISO8601DateFormatter()
        let output = DateFormatter()
        output.dateStyle = .medium
        guard let date = input.date(from: iso) else { return "" }
        return output.string(from: date)
    }

    private func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case "economics", "econ", "business":
            return "chart.line.uptrend.xyaxis"
        case "environment", "env", "climate":
            return "leaf.fill"
        case "technology", "tech":
            return "laptopcomputer"
        case "politics":
            return "building.columns.fill"
        case "sports":
            return "sportscourt.fill"
        case "health":
            return "heart.fill"
        case "science":
            return "atom"
        case "entertainment":
            return "tv.fill"
        case "world", "international":
            return "globe.americas.fill"
        case "immigration":
            return "airplane.arrival"
        default:
            return "doc.text.fill"
        }
    }

    private func dynamicTitleFontSize(for title: String) -> CGFloat {
        let length = title.count
        switch length {
        case 0...40:
            return 20
        case 41...60:
            return 18
        case 61...80:
            return 17
        case 81...100:
            return 16
        default:
            return 15
        }
    }

    private func shareArticle(_ article: Article) {
        let activityVC = UIActivityViewController(activityItems: [article.url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

struct NewsFeedView_Previews: PreviewProvider {
    static var previews: some View {
        NewsFeedView()
    }
}
