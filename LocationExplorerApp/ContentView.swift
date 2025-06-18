import SwiftUI
import MapKit
import WebKit

// MARK: - CLLocationCoordinate2D 확장
extension CLLocationCoordinate2D: Equatable, Hashable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
}

// MARK: - WebView (카카오 장소 상세보기용)
struct WebView: UIViewRepresentable, Identifiable {
    var id: URL { url }
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.load(URLRequest(url: url))
    }
}

// MARK: - ContentView
struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var favoritesManager = FavoritesManager.shared

    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    @State private var selectedCategory = "FD6"
    @State private var places: [Place] = []
    @State private var showingFavorites = false
    @State private var searchText = ""
    @State private var selectedPlaceForDetail: Place? = nil
    @State private var selectedPlaceURL: WebView? = nil

    var filteredPlaces: [Place] {
        let source = showingFavorites ? favoritesManager.favorites : places
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? source : source.filter { $0.place_name.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        ZStack {
            if let userLocation = locationManager.region {
                buildMapView(userLocation: userLocation)
                    .onAppear {
                        mapRegion.center = userLocation
                        fetchNearbyPlaces()
                    }
            } else {
                ProgressView("📡 위치를 불러오는 중입니다...")
            }

            overlayControls
        }
        .edgesIgnoringSafeArea(.all)
        .sheet(item: $selectedPlaceForDetail) { place in
            detailSheetView(for: place)
        }
        .sheet(item: $selectedPlaceURL) { webview in
            webview
        }
    }

    private func buildMapView(userLocation: CLLocationCoordinate2D) -> some View {
        Map(
            coordinateRegion: $mapRegion,
            showsUserLocation: true,
            annotationItems: filteredPlaces
        ) { place in
            MapAnnotation(coordinate: coordinate(for: place)) {
                annotationView(for: place)
            }
        }
    }

    private func coordinate(for place: Place) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: Double(place.y) ?? 0.0,
            longitude: Double(place.x) ?? 0.0
        )
    }

    private func annotationView(for place: Place) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(.red)
                .font(.title)
            Text(place.place_name)
                .font(.caption)
            HStack {
                Button(favoritesManager.isFavorite(place: place) ? "\u{1F5D1}\u{FE0F}" : "\u{2B50}\u{FE0F}") {
                    toggleFavorite(place: place)
                }
                Button("\u{2139}\u{FE0F}") {
                    selectedPlaceForDetail = place
                }
                Button("\u{1F697}") {
                    openInMaps(place: place)
                }
            }
            .font(.caption)
        }
    }

    private var overlayControls: some View {
        VStack {
            HStack {
                TextField("장소를 검색하세요", text: $searchText)
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(8)
                    .shadow(radius: 2)

                Button(action: searchPlaceByName) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.top, 50)

            if !showingFavorites {
                Picker("카테고리", selection: $selectedCategory) {
                    Text("맛집").tag("FD6")
                    Text("카페").tag("CE7")
                    Text("관광지").tag("AT4")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .onChange(of: selectedCategory) { _ in fetchNearbyPlaces() }
            }

            Spacer()

            HStack {
                Spacer()
                VStack(spacing: 16) {
                    Button(action: centerToUserLocation) {
                        Image(systemName: "location.fill")
                            .padding()
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }

                    Button {
                        mapRegion.span.latitudeDelta *= 0.5
                        mapRegion.span.longitudeDelta *= 0.5
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                            .padding()
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }

                    Button {
                        mapRegion.span.latitudeDelta *= 2.0
                        mapRegion.span.longitudeDelta *= 2.0
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                            .padding()
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }

                    Button {
                        showingFavorites.toggle()
                    } label: {
                        Image(systemName: showingFavorites ? "map.fill" : "star.fill")
                            .padding()
                            .background(Color.yellow)
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }
                }
                .padding()
            }
        }
    }

    private func detailSheetView(for place: Place) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\u{1F4CD} \(place.place_name)").font(.title2).bold()
            Divider()
            Text("주소: \(place.road_address_name)")
            Text("거리: \(place.distance)m")
            Text("위도: \(place.y)")
            Text("경도: \(place.x)")
            if let phone = place.phone {
                Text("전화번호: \(phone)")
            }
            if let urlStr = place.place_url, let url = URL(string: urlStr) {
                Link("\u{1F517} 카카오 장소 페이지", destination: url)
                Button("\u{1F50D} 상세보기") {
                    selectedPlaceURL = WebView(url: url)
                }
            }
            Spacer()
        }
        .padding()
    }

    private func toggleFavorite(place: Place) {
        if favoritesManager.isFavorite(place: place) {
            favoritesManager.removeFavorite(place: place)
        } else {
            favoritesManager.saveFavorite(place: place)
        }
    }

    private func centerToUserLocation() {
        if let current = locationManager.region {
            mapRegion.center = current
        }
    }

    private func fetchNearbyPlaces() {
        KakaoAPIService.shared.fetchPlaces(category: selectedCategory, coordinate: mapRegion.center) { results in
            places = results
        }
    }

    private func searchPlaceByName() {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            fetchNearbyPlaces()
            return
        }
        KakaoAPIService.shared.searchPlace(keyword: trimmed, coordinate: mapRegion.center) { results in
            places = results
        }
    }

    private func openInMaps(place: Place) {
        guard let lat = Double(place.y), let lon = Double(place.x) else { return }
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = place.place_name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

