import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                NewsFeedView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("News", systemImage: "newspaper.fill")
            }
            .tag(0)
            
            NavigationView {
                LegislatorsGridView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Legislators", systemImage: "person.3.fill")
            }
            .tag(1)
            
            NavigationView {
                VotingInfoView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Voting", systemImage: "info.circle.fill")
            }
            .tag(2)
        }
        .accentColor(Color("PrimaryBlue"))
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
