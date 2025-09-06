import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 1 // Start with Camera tab
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Feed Tab
            HomeView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("Home")
                }
                .tag(0)
            
            // Camera Tab (Main action)
            CameraView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                    Text("Create")
                }
                .tag(1)
            
            // Profile Tab
            ProfileView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "person.fill" : "person")
                    Text("Profile")
                }
                .tag(2)
        }
        .accentColor(.primary)
        .onAppear {
            setupTabBarAppearance()
        }
    }
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}