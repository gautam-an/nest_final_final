import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showClaims = false // controls showing ClaimStreamView sheet
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            // ✅ Town Hall tab with top-right Claims button
            NavigationView {
                TownHallView() // use your existing TownHallView
                    .navigationBarItems(trailing: Button(action: {
                        showClaims.toggle()
                    }) {
                        Label("Claims", systemImage: "checkmark.seal.fill")
                    })
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Town Hall", systemImage: "video.fill")
            }
            .tag(0)
            
            NavigationView {
                PollingPlacesView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Polling", systemImage: "mappin.circle.fill")
            }
            .tag(1)
            
            NavigationView {
                NewsFeedView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("News", systemImage: "newspaper.fill")
            }
            .tag(2)
            
            NavigationView {
                LegislatorsGridView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Legislators", systemImage: "person.3.fill")
            }
            .tag(3)
            
            NavigationView {
                VotingInfoView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Voting", systemImage: "info.circle.fill")
            }
            .tag(4)
        }
        .accentColor(Color("PrimaryBlue"))
        // show your existing ClaimStreamView as a modal sheet
        .sheet(isPresented: $showClaims) {
            ClaimStreamView() // this is the one from ClaimStreamView.swift
        }
    }
}

// -------------------- Preview --------------------
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
