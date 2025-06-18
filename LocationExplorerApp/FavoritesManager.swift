import Foundation
import CoreLocation

class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()
    
    private let key = "favorites"
    
    // 즐겨찾기 목록 (SwiftUI 뷰 자동 업데이트 가능)
    @Published private(set) var favorites: [Place] = []

    private init() {
        loadFavorites()
    }

    // MARK: - 즐겨찾기 추가
    func saveFavorite(place: Place) {
        guard !isFavorite(place: place) else { return }
        favorites.append(place)
        persistFavorites()
    }

    // MARK: - 즐겨찾기 제거
    func removeFavorite(place: Place) {
        favorites.removeAll { $0.place_name == place.place_name }
        persistFavorites()
    }

    // MARK: - 즐겨찾기 여부 확인
    func isFavorite(place: Place) -> Bool {
        return favorites.contains(where: { $0.place_name == place.place_name })
    }

    // MARK: - 저장된 즐겨찾기 불러오기
    private func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            print("ℹ️ 저장된 즐겨찾기 없음")
            return
        }
        do {
            let decoded = try JSONDecoder().decode([Place].self, from: data)
            self.favorites = decoded
            print("✅ 즐겨찾기 로드 완료 (\(decoded.count)개)")
        } catch {
            print("❌ 즐겨찾기 로드 실패: \(error.localizedDescription)")
        }
    }

    // MARK: - 즐겨찾기 저장
    private func persistFavorites() {
        do {
            let data = try JSONEncoder().encode(favorites)
            UserDefaults.standard.set(data, forKey: key)
            print("💾 즐겨찾기 저장 완료 (\(favorites.count)개)")
        } catch {
            print("❌ 즐겨찾기 저장 실패: \(error.localizedDescription)")
        }
    }
}
