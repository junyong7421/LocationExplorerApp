import Foundation
import CoreLocation

// MARK: - 모델 정의

struct Place: Identifiable, Codable, Equatable {
    var id = UUID()
    let place_name: String
    let road_address_name: String
    let distance: String
    let x: String   // 경도
    let y: String   // 위도
    let phone: String?
    let place_url: String?

    enum CodingKeys: String, CodingKey {
        case place_name, road_address_name, distance, x, y, phone, place_url
    }
}

struct PlaceResult: Codable {
    let documents: [Place]
}

// MARK: - Kakao API 서비스

class KakaoAPIService {
    static let shared = KakaoAPIService()
    private init() {}

    // ✅ API 키는 Info.plist 또는 환경 설정 파일로 이전 권장
    private let apiKey = "KakaoAK a7b05ffab3f51f88ed120384513dca38"

    // MARK: - 카테고리 기반 장소 검색
    func fetchPlaces(category: String, coordinate: CLLocationCoordinate2D, completion: @escaping ([Place]) -> Void) {
        let queryItems = [
            URLQueryItem(name: "category_group_code", value: category),
            URLQueryItem(name: "x", value: "\(coordinate.longitude)"),
            URLQueryItem(name: "y", value: "\(coordinate.latitude)"),
            URLQueryItem(name: "radius", value: "1000"),
            URLQueryItem(name: "sort", value: "distance")
        ]

        fetch(from: "https://dapi.kakao.com/v2/local/search/category.json",
              queryItems: queryItems,
              completion: completion)
    }

    // MARK: - 키워드 기반 장소 검색
    func searchPlace(keyword: String, coordinate: CLLocationCoordinate2D, completion: @escaping ([Place]) -> Void) {
        guard let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("❌ 키워드 인코딩 실패: \(keyword)")
            completion([])
            return
        }

        let queryItems = [
            URLQueryItem(name: "query", value: encodedKeyword),
            URLQueryItem(name: "x", value: "\(coordinate.longitude)"),
            URLQueryItem(name: "y", value: "\(coordinate.latitude)"),
            URLQueryItem(name: "radius", value: "1000"),
            URLQueryItem(name: "sort", value: "distance")
        ]

        fetch(from: "https://dapi.kakao.com/v2/local/search/keyword.json",
              queryItems: queryItems,
              completion: completion)
    }

    // MARK: - 공통 요청 함수
    private func fetch(from baseURL: String, queryItems: [URLQueryItem], completion: @escaping ([Place]) -> Void) {
        var components = URLComponents(string: baseURL)
        components?.queryItems = queryItems

        guard let url = components?.url else {
            print("❌ URL 생성 실패: \(baseURL)?\(queryItems)")
            completion([])
            return
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")

        print("🌐 요청 URL: \(url.absoluteString)")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ 요청 실패: \(error.localizedDescription)")
                completion([])
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("❌ HTTP 오류 상태 코드: \(httpResponse.statusCode)")
                completion([])
                return
            }

            guard let data = data else {
                print("❌ 응답 데이터 없음")
                completion([])
                return
            }

            do {
                let decoded = try JSONDecoder().decode(PlaceResult.self, from: data)
                DispatchQueue.main.async {
                    print("✅ 장소 \(decoded.documents.count)개 수신 완료")
                    completion(decoded.documents)
                }
            } catch {
                print("❌ JSON 파싱 실패: \(error.localizedDescription)")
                completion([])
            }
        }.resume()
    }
}
