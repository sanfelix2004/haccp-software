import Foundation
import AuthenticationServices

class AppleSignInManager: NSObject {
    static let shared = AppleSignInManager()
    
    // Callback to use for returning user info
    var onCompletion: ((String, String?) -> Void)?
    
    func performSignIn() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }
}

extension AppleSignInManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userIdentifier = appleIDCredential.user
            let email = appleIDCredential.email
            
            // In a real app, you would also use the identityToken and authorizationCode
            // to verify with your backend.
            
            print("Apple ID Login Success: \(userIdentifier)")
            onCompletion?(userIdentifier, email)
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple ID Login Error: \(error.localizedDescription)")
    }
}
