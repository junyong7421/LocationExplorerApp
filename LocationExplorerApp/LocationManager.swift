import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var region: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationServicesEnabled: Bool = CLLocationManager.locationServicesEnabled()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        checkLocationServices()
    }

    // MARK: - 위치 서비스 확인 및 요청
    private func checkLocationServices() {
        locationServicesEnabled = CLLocationManager.locationServicesEnabled()

        guard locationServicesEnabled else {
            print("❌ 위치 서비스 꺼져 있음")
            return
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            print("⚠️ 위치 권한이 없거나 제한됨")
        @unknown default:
            print("❓ 알 수 없는 권한 상태")
        }
    }

    // MARK: - 위치 업데이트 수신
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        DispatchQueue.main.async {
            self.region = latest.coordinate
        }
    }

    // MARK: - 권한 변경 감지
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        DispatchQueue.main.async {
            self.authorizationStatus = newStatus
            self.locationServicesEnabled = CLLocationManager.locationServicesEnabled()
        }

        switch newStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            print("✅ 위치 권한 허용됨")
            manager.startUpdatingLocation()
        case .denied:
            print("❌ 위치 권한 거부됨")
        case .restricted:
            print("🚫 위치 권한 제한됨")
        case .notDetermined:
            print("ℹ️ 위치 권한 미결정")
        @unknown default:
            print("❓ 알 수 없는 위치 권한 상태")
        }
    }

    // MARK: - 에러 처리
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("⚠️ 위치 수신 실패: \(error.localizedDescription)")
    }
}
