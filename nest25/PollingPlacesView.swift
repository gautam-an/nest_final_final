import SwiftUI
import MapKit
import CoreLocation
import EventKit

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    
    override init() {
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
        self.location = CLLocation(latitude: 39.0388, longitude: -77.4866)
    }
    
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() {
        locationManager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            self.location = location
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to find user's location: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
}

struct PollingPlace: Hashable, Identifiable {
    var id = UUID()
    var coordinate: CLLocationCoordinate2D
    var title: String
    var type: PlaceType
    var address: String
    var distance: Double?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
        hasher.combine(title)
        hasher.combine(type)
        hasher.combine(address)
        hasher.combine(distance)
    }
    
    static func == (lhs: PollingPlace, rhs: PollingPlace) -> Bool {
        return lhs.id == rhs.id &&
               lhs.coordinate.latitude == rhs.coordinate.latitude &&
               lhs.coordinate.longitude == rhs.coordinate.longitude &&
               lhs.title == rhs.title &&
               lhs.type == rhs.type &&
               lhs.address == rhs.address &&
               lhs.distance == rhs.distance
    }
    
    enum PlaceType: String {
        case school = "School"
        case library = "Library"
        case communityCenter = "Community Center"
        case governmentBuilding = "Government Building"
        case church = "Church"
        case other = "Other"
        
        var iconName: String {
            switch self {
            case .school: return "building.columns.fill"
            case .library: return "books.vertical.fill"
            case .communityCenter: return "person.3.fill"
            case .governmentBuilding: return "building.2.fill"
            case .church: return "building.fill"
            case .other: return "mappin.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .school: return .blue
            case .library: return .purple
            case .communityCenter: return .green
            case .governmentBuilding: return .orange
            case .church: return .red
            case .other: return .gray
            }
        }
    }
}

struct PollingPlacesView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var pollingPlaces: [PollingPlace] = []
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showLocationPermissionAlert = false
    @State private var selectedPlace: PollingPlace?
    @State private var showDetailsSheet = false
    @State private var searchRadius: Double = 5000
    @State private var isLoading = false
    @State private var errorMessage: String?
    @GestureState private var dragOffset: CGFloat = 0
    @State private var listHeight: CGFloat = 250
    
    let userLocation = CLLocationCoordinate2D(latitude: 39.0388, longitude: -77.4866)
    
    let pollingPlacesAshburn = [
        PollingPlace(coordinate: .init(latitude: 39.0437, longitude: -77.4875), title: "Ashburn Elementary School", type: .school, address: "44062 Fincastle Dr, Ashburn, VA 20147", distance: nil),
        PollingPlace(coordinate: .init(latitude: 39.0551, longitude: -77.4752), title: "Cedar Lane Elementary School", type: .school, address: "43700 Tolamac Dr, Ashburn, VA 20147", distance: nil),
        PollingPlace(coordinate: .init(latitude: 39.0298, longitude: -77.4926), title: "Brambleton Library", type: .library, address: "43316 Hay Rd, Ashburn, VA 20147", distance: nil),
        PollingPlace(coordinate: .init(latitude: 39.0592, longitude: -77.5078), title: "Broad Run High School", type: .school, address: "21670 Ashburn Rd, Ashburn, VA 20147", distance: nil),
        PollingPlace(coordinate: .init(latitude: 39.0431, longitude: -77.5124), title: "Ashburn Library", type: .library, address: "43316 Hay Rd, Ashburn, VA 20147", distance: nil),
        PollingPlace(coordinate: .init(latitude: 39.0112, longitude: -77.4634), title: "Moorefield Station Elementary", type: .school, address: "22325 Mooreview Pkwy, Ashburn, VA 20148", distance: nil),
        PollingPlace(coordinate: .init(latitude: 39.0310, longitude: -77.4805), title: "Brambleton Community Center", type: .communityCenter, address: "42330 Fredrick Blvd, Ashburn, VA 20148", distance: nil),
        PollingPlace(coordinate: .init(latitude: 39.0542, longitude: -77.4760), title: "Loudoun County Government Center", type: .governmentBuilding, address: "1 Harrison St SE, Leesburg, VA 20175", distance: nil),
        PollingPlace(coordinate: .init(latitude: 39.0360, longitude: -77.5030), title: "St. Theresa Catholic Church", type: .church, address: "21371 St Theresa Ln, Ashburn, VA 20147", distance: nil),
        PollingPlace(coordinate: .init(latitude: 39.0647, longitude: -77.4678), title: "Sanders Corner Elementary", type: .school, address: "43100 Ashburn Farm Pkwy, Ashburn, VA 20147", distance: nil)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Map(position: $cameraPosition, interactionModes: .all, selection: $selectedPlace) {
                    UserAnnotation()
                    ForEach(pollingPlaces) { place in
                        Marker(place.title, systemImage: place.type.iconName, coordinate: place.coordinate)
                            .tint(place.type.color)
                    }
                }
                .mapStyle(.standard)
                .edgesIgnoringSafeArea(.top)
                .onAppear {
                    cameraPosition = .region(MKCoordinateRegion(center: userLocation, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
                    loadPollingPlaces(from: userLocation)
                    setupLocationManager()
                }
                .onChange(of: locationManager.location) { _, newLocation in
                    if let location = newLocation {
                        withAnimation {
                            cameraPosition = .region(MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
                        }
                        if pollingPlaces.isEmpty {
                            loadPollingPlaces(from: location.coordinate)
                        }
                    }
                }
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)
                        .padding()
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(10)
                }
                
                VStack {
                    Spacer()
                    VStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 3)
                            .frame(width: 40, height: 6)
                            .foregroundColor(.gray.opacity(0.3))
                            .padding(.top, 8)
                            .gesture(
                                DragGesture()
                                    .updating($dragOffset) { value, state, _ in
                                        state = value.translation.height
                                    }
                                    .onEnded { value in
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                            if value.translation.height > 50 {
                                                listHeight = 60
                                            } else if value.translation.height < -50 {
                                                listHeight = 350                                             }
                                        }
                                    }
                            )
                        HStack {
                            Text("Polling Places")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()

                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        if listHeight > 60 {
                            if let error = errorMessage {
                                Text(error)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding()
                            } else if pollingPlaces.isEmpty {
                                Text("No polling places found nearby. Try increasing your search radius.")
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding()
                            } else {
                                List {
                                    ForEach(pollingPlaces.sorted { ($0.distance ?? 0) < ($1.distance ?? 0) }) { place in
                                        Button(action: {
                                            selectedPlace = place
                                            withAnimation {
                                                cameraPosition = .region(MKCoordinateRegion(center: place.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
                                            }
                                        }) {
                                            HStack {
                                                Image(systemName: place.type.iconName)
                                                    .foregroundColor(place.type.color)
                                                    .frame(width: 30)
                                                VStack(alignment: .leading) {
                                                    Text(place.title)
                                                        .font(.system(size: 16))
                                                        .fontWeight(.medium)
                                                    Text(place.address)
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                                Spacer()
                                                if let distance = place.distance {
                                                    Text(formatDistance(distance))
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                            .padding(.vertical, 8)
                                            .padding(.horizontal)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(selectedPlace?.id == place.id ? Color.blue.opacity(0.1) : Color.white)
                                            .cornerRadius(8)
                                            .shadow(radius: 2)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .listStyle(.plain)
                                .frame(height: listHeight)
                            }
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(16, corners: [.topLeft, .topRight])
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: -3)
                }
                
                VStack {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    if !pollingPlaces.isEmpty {
                                        let coordinates = pollingPlaces.map { $0.coordinate }
                                        cameraPosition = .region(regionThatFitsCoordinates(coordinates))
                                        selectedPlace = nil
                                    }
                                }
                            }) {
                                Image(systemName: "globe.americas.fill")
                                    .font(.system(size: 20))
                                    .padding(12)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                            }
                            Button(action: {
                                withAnimation {
                                    cameraPosition = .region(MKCoordinateRegion(center: userLocation, span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)))
                                }
                            }) {
                                Image(systemName: "location.circle.fill")
                                    .font(.system(size: 20))
                                    .padding(12)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                            }
                        }
                        .padding()
                    }
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Text("Polling Places")
                    .font(.headline)
                    .fontWeight(.bold),
                trailing: Button(action: {
                    refreshPollingPlaces()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
            )
            .alert(isPresented: $showLocationPermissionAlert) {
                Alert(
                    title: Text("Location Access Required"),
                    message: Text("Please enable location access in your device settings to find polling places near you."),
                    primaryButton: .default(Text("Open Settings"), action: openSettings),
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showDetailsSheet) {
                if let selectedPlace = selectedPlace {
                    PollingPlaceDetailView(place: selectedPlace)
                }
            }
            .onChange(of: selectedPlace) { _, newPlace in
                showDetailsSheet = newPlace != nil
            }
        }
    }
    
    func setupLocationManager() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            showLocationPermissionAlert = true
            errorMessage = "Location access denied. Please enable it in Settings."
        @unknown default:
            break
        }
    }
    
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    func refreshPollingPlaces() {
        isLoading = true
        errorMessage = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            loadPollingPlaces(from: userLocation)
            isLoading = false
        }
    }
    
    func loadPollingPlaces(from userLocation: CLLocationCoordinate2D) {
        var filteredPlaces = pollingPlacesAshburn
        for i in 0..<filteredPlaces.count {
            let placeCoordinate = filteredPlaces[i].coordinate
            let locationDistance = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                .distance(from: CLLocation(latitude: placeCoordinate.latitude, longitude: placeCoordinate.longitude))
            filteredPlaces[i].distance = locationDistance
        }
        filteredPlaces = filteredPlaces.filter { ($0.distance ?? 0) <= searchRadius }
        pollingPlaces = filteredPlaces.sorted { ($0.distance ?? 0) < ($1.distance ?? 0) }
        if pollingPlaces.isEmpty {
            errorMessage = "No polling places found within \(Int(searchRadius/1000)) km."
        }
    }
    
    func openInMaps(_ place: PollingPlace) {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
        mapItem.name = place.title
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
    
    func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m"
        } else {
            let kilometers = meters / 1000
            return String(format: "%.1fkm", kilometers)
        }
    }
    
    func regionThatFitsCoordinates(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        var minLat: CLLocationDegrees = 90.0
        var maxLat: CLLocationDegrees = -90.0
        var minLon: CLLocationDegrees = 180.0
        var maxLon: CLLocationDegrees = -180.0
        
        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.3, 0.01), longitudeDelta: max((maxLon - minLon) * 1.3, 0.01))
        return MKCoordinateRegion(center: center, span: span)
    }
}

struct PollingPlaceDetailView: View {
    let place: PollingPlace
    @State private var showDirections = false
    @State private var showCalendarAlert = false
    @State private var calendarAlertMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    private let eventStore = EKEventStore()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Image(systemName: place.type.iconName)
                            .font(.largeTitle)
                            .foregroundColor(place.type.color)
                        VStack(alignment: .leading) {
                            Text(place.title)
                                .font(.title)
                                .fontWeight(.bold)
                            Text(place.type.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical)
                    
                    VStack(alignment: .leading) {
                        Text("Address")
                            .font(.headline)
                        Text(place.address)
                            .font(.body)
                    }
                    
                    if let distance = place.distance {
                        VStack(alignment: .leading) {
                            Text("Distance")
                                .font(.headline)
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.blue)
                                Text(distance < 1000 ? "\(Int(distance)) meters" : String(format: "%.2f kilometers", distance / 1000))
                            }
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Voting Hours")
                            .font(.headline)
                        Text("6:00 AM - 7:00 PM")
                            .font(.body)
                        Text("*Virginia polls are open from 6am to 7pm on Election Day.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Accessibility")
                            .font(.headline)
                        HStack {
                            Image(systemName: "figure.roll")
                            Text("Wheelchair accessible")
                        }
                        HStack {
                            Image(systemName: "car.fill")
                            Text("Parking available")
                        }
                    }
                    
                    VStack(alignment: .center) {
                        Text("Check in here to earn")
                            .font(.headline)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                            .padding()
                        Text("Digital \"I Voted\" sticker")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    VStack(spacing: 12) {
                        Button(action: {
                            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
                            mapItem.name = place.title
                            mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                        }) {
                            HStack {
                                Image(systemName: "map.fill")
                                Text("Get Directions")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            addToCalendar()
                        }) {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                Text("Add to Calendar")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitle("Polling Place Details", displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            })
            .alert(isPresented: $showCalendarAlert) {
                Alert(title: Text("Calendar"), message: Text(calendarAlertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    func addToCalendar() {
        eventStore.requestAccess(to: .event) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.calendarAlertMessage = "Failed to access calendar: \(error.localizedDescription)"
                    self.showCalendarAlert = true
                    return
                }
                
                guard granted else {
                    self.calendarAlertMessage = "Please allow calendar access in Settings to add this event"
                    self.showCalendarAlert = true
                    return
                }
                
                let event = EKEvent(eventStore: self.eventStore)
                event.title = "Vote at \(place.title)"
                event.location = place.address
                
                var components = DateComponents()
                components.year = 2025
                components.month = 11
                components.day = 4
                components.hour = 6
                components.minute = 0
                
                let calendar = Calendar.current
                if let startDate = calendar.date(from: components),
                   let endDate = calendar.date(byAdding: .hour, value: 13, to: startDate) {
                    event.startDate = startDate
                    event.endDate = endDate
                }
                
                event.calendar = self.eventStore.defaultCalendarForNewEvents
                
                do {
                    try self.eventStore.save(event, span: .thisEvent)
                    self.calendarAlertMessage = "Voting event added to your calendar!"
                    self.showCalendarAlert = true
                } catch {
                    self.calendarAlertMessage = "Failed to save event: \(error.localizedDescription)"
                    self.showCalendarAlert = true
                }
            }
        }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct PollingPlacesView_Previews: PreviewProvider {
    static var previews: some View {
        PollingPlacesView()
    }
}
