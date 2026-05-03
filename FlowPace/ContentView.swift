import SwiftUI

struct ContentView: View {
    @StateObject private var routineManager = RoutineManager()
    @StateObject private var storeKitManager = StoreKitManager()
    @StateObject private var audioManager = AudioManager()
    @EnvironmentObject var backgroundColorManager: BackgroundColorManager

    
    var body: some View {
        NavigationView {
            RoutineListView()
                .environmentObject(routineManager)
                .environmentObject(storeKitManager)
                .environmentObject(audioManager)
                .environmentObject(backgroundColorManager)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            audioManager.storeKitManager = storeKitManager
            audioManager.checkPremiumStatus()
            
            // Connect RoutineManager to StoreKitManager for premium checks
            routineManager.storeKitManager = storeKitManager
        }
    }
}

#Preview {
    ContentView()
}
