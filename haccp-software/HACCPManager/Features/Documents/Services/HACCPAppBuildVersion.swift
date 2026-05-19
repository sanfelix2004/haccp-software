import Foundation

enum HACCPAppBuildVersion {
    static var marketingAndBuild: String {
        "\(AppVersionService.marketingVersion) (\(AppVersionService.buildNumber))"
    }
}
