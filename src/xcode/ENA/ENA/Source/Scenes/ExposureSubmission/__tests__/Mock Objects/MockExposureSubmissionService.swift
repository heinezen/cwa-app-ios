//
// 🦠 Corona-Warn-App
//

import Foundation

#if DEBUG
class MockExposureSubmissionService: ExposureSubmissionService {

	// MARK: - Mock callbacks.

	var submitExposureCallback: ((@escaping ExposureSubmissionHandler) -> Void)?
	var getRegistrationTokenCallback: ((DeviceRegistrationKey, @escaping RegistrationHandler) -> Void)?
	var getTANForExposureSubmitCallback: ((Bool, @escaping TANHandler) -> Void)?
	var getTestResultCallback: ((@escaping TestResultHandler) -> Void)?
	var deleteTestCallback: (() -> Void)?
	var acceptPairingCallback: (() -> Void)?

	// MARK: - ExposureSubmissionService properties.

	var hasRegistrationToken: Bool = false

	var devicePairingConsentAcceptTimestamp: Int64?
	var devicePairingSuccessfulTimestamp: Int64?

	var positiveTestResultWasShown: Bool = false

	var supportedCountries: [Country] = []
	var symptomsOnset: SymptomsOnset = .noInformation

	// Needed to use a publisher in the protocol
	@Published var isSubmissionConsentGiven: Bool = false

	var isSubmissionConsentGivenPublisher: Published<Bool>.Publisher { $isSubmissionConsentGiven }

	var exposureManagerState: ExposureManagerState = ExposureManagerState(authorized: false, enabled: false, status: .unknown)

	// MARK: - ExposureSubmissionService methods.
	
	func setSubmissionConsentGiven(consentGiven: Bool) {
		self.isSubmissionConsentGiven = consentGiven
	}

	func loadSupportedCountries(
		isLoading: @escaping (Bool) -> Void,
		onSuccess: @escaping () -> Void,
		onError: @escaping (ExposureSubmissionError) -> Void
	) {
		
	}

	func submitExposure(completionHandler: @escaping ExposureSubmissionHandler) {
		submitExposureCallback?(completionHandler)
	}

	func getRegistrationToken(forKey deviceRegistrationKey: DeviceRegistrationKey, completion completeWith: @escaping RegistrationHandler) {
		getRegistrationTokenCallback?(deviceRegistrationKey, completeWith)
	}

	func getTANForExposureSubmit(hasConsent: Bool, completion completeWith: @escaping TANHandler) {
		getTANForExposureSubmitCallback?(hasConsent, completeWith)
	}

	func getTestResult(_ completeWith: @escaping TestResultHandler) {
		getTestResultCallback?(completeWith)
	}

	func getTestResult(forKey deviceRegistrationKey: DeviceRegistrationKey, useStoredRegistration: Bool, completion: @escaping TestResultHandler) {
		getTestResultCallback?(completion)
	}

	func deleteTest() {
		deleteTestCallback?()
	}

	func fakeRequest(completionHandler: ExposureSubmissionHandler?) { }

	func acceptPairing() {
		acceptPairingCallback?()
	}

}
#endif
