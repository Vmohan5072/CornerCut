import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            SessionsView()
                .tabItem {
                    Label("Sessions", systemImage: "list.bullet.rectangle")
                }

            StraightlineView()
                .tabItem {
                    Label("Performance", systemImage: "speedometer")
                }

            MeView()
                .tabItem {
                    Label("Me", systemImage: "person.crop.circle")
                }
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
