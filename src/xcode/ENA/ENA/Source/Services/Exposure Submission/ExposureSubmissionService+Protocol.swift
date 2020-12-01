//
// 🦠 Corona-Warn-App
//

import Foundation

protocol ExposureSubmissionService: class {

	typealias ExposureSubmissionHandler = (_ error: ExposureSubmissionError?) -> Void
	typealias RegistrationHandler = (Result<String, ExposureSubmissionError>) -> Void
	typealias TestResultHandler = (Result<TestResult, ExposureSubmissionError>) -> Void
	typealias TANHandler = (Result<String, ExposureSubmissionError>) -> Void

	var exposureManagerState: ExposureManagerState { get }
	var hasRegistrationToken: Bool { get }

	var devicePairingConsentAcceptTimestamp: Int64? { get }
	var devicePairingSuccessfulTimestamp: Int64? { get }

	var positiveTestResultWasShown: Bool { get set }

	var supportedCountries: [Country] { get set }
	var symptomsOnset: SymptomsOnset { get set }
	
	var isSubmissionConsentGivenPublisher: Published<Bool>.Publisher { get }
	
	func setSubmissionConsentGiven(consentGiven: Bool)

	func loadSupportedCountries(
		isLoading: @escaping (Bool) -> Void,
		onSuccess: @escaping () -> Void,
		onError: @escaping (ExposureSubmissionError) -> Void
	)

	func getTemporaryExposureKeys(completion: @escaping ExposureSubmissionHandler)
	func submitExposure(completion: @escaping ExposureSubmissionHandler)

	func getRegistrationToken(
		forKey deviceRegistrationKey: DeviceRegistrationKey,
		completion completeWith: @escaping RegistrationHandler
	)
	func getTestResult(_ completeWith: @escaping TestResultHandler)

	/// Fetches test results for a given device key.
	///
	/// - Parameters:
	///   - deviceRegistrationKey: the device key to fetch the test results for
	///   - useStoredRegistration: flag to show if a separate registration is needed (`false`) or an existing registration token is used (`true`)
	///   - completion: a `TestResultHandler`
	func getTestResult(forKey deviceRegistrationKey: DeviceRegistrationKey, useStoredRegistration: Bool, completion: @escaping TestResultHandler)
	func deleteTest()
	func acceptPairing()
	func fakeRequest(completionHandler: ExposureSubmissionHandler?)
	

}
