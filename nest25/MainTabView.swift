import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                    
                NewsFeedView()
                    .tabItem {
                        Label("News", systemImage: "newspaper.fill")
                    }
                    .tag(0)
                
                LegislatorsGridView()
                    .tabItem {
                        Label("Legislators", systemImage: "person.3.fill")
                    }
                    .tag(1)
                

                VotingInfoView()
                    .tabItem {
                        Label("Voting", systemImage: "info.circle.fill")
                    }
                    .tag(2)
            }
            .accentColor(Color("PrimaryBlue"))
        }
        .navigationViewStyle(.stack)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
