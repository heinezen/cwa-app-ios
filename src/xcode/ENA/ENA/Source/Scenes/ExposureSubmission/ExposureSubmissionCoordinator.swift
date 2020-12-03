//
// 🦠 Corona-Warn-App
//

import Foundation
import UIKit
import Combine

/// Coordinator for the exposure submission flow.
/// This protocol hides the creation of view controllers and their transitions behind a slim interface.
protocol ExposureSubmissionCoordinating: class {

	// MARK: - Attributes.

	/// Delegate that is called for life-cycle events of the coordinator.
	var delegate: ExposureSubmissionCoordinatorDelegate? { get set }

	// MARK: - Navigation.

	/// Starts the coordinator and displays the initial root view controller.
	/// The underlying implementation may decide which initial screen to show, currently the following options are possible:
	/// - Case 1: When a valid test result is provided, the coordinator shows the test result screen.
	/// - Case 2: (DEFAULT) The coordinator shows the screen "Fetch Test Result and Warn Others".
	/// - Case 3: (UI-Testing) The coordinator may be configured to show other screens for UI-Testing.
	/// For more information on the usage and configuration of the initial screen, check the concrete implementation of the method.
	func start(with result: TestResult?)
	func dismiss()
	func showTestResultScreen(with result: TestResult)
	func showTanScreen()
}

/// This delegate allows a class to be notified for life-cycle events of the coordinator.
protocol ExposureSubmissionCoordinatorDelegate: class {
	func exposureSubmissionCoordinatorWillDisappear(_ coordinator: ExposureSubmissionCoordinating)
}

// swiftlint:disable file_length
/// Concrete implementation of the ExposureSubmissionCoordinator protocol.
// swiftlint:disable:next type_body_length
class ExposureSubmissionCoordinator: NSObject, ExposureSubmissionCoordinating, RequiresAppDependencies {

	// MARK: - Initializers.

	init(
		warnOthersReminder: WarnOthersRemindable,
		parentNavigationController: UINavigationController,
		exposureSubmissionService: ExposureSubmissionService,
		delegate: ExposureSubmissionCoordinatorDelegate? = nil
	) {
		self.parentNavigationController = parentNavigationController
		self.delegate = delegate
		self.warnOthersReminder = warnOthersReminder
		
		super.init()

		model = ExposureSubmissionCoordinatorModel(
			exposureSubmissionService: exposureSubmissionService,
			appConfigurationProvider: appConfigurationProvider
		)
	}

	// MARK: - Protocol ExposureSubmissionCoordinating

	/// - NOTE: The delegate is called by the `viewWillDisappear(_:)` method of the `navigationController`.
	weak var delegate: ExposureSubmissionCoordinatorDelegate?

	func start(with result: TestResult? = nil) {
		let initialVC = getInitialViewController(with: result)
		guard let parentNavigationController = parentNavigationController else {
			Log.error("Parent navigation controller not set.", log: .ui)
			return
		}

		/// The navigation controller keeps a strong reference to the coordinator. The coordinator only reaches reference count 0
		/// when UIKit dismisses the navigationController.
		let exposureSubmissionNavigationController = ExposureSubmissionNavigationController(
			coordinator: self,
			dismissClosure: { [weak self] in
				self?.navigationController?.dismiss(animated: true)
			},
			rootViewController: initialVC
		)
		parentNavigationController.present(exposureSubmissionNavigationController, animated: true)
		navigationController = exposureSubmissionNavigationController
	}

	func dismiss() {
		guard let presentedViewController = navigationController?.viewControllers.last else { return }
		guard let vc = presentedViewController as? RequiresDismissConfirmation else {
			navigationController?.dismiss(animated: true)
			return
		}

		vc.attemptDismiss { [weak self] shouldDismiss in
			if shouldDismiss { self?.navigationController?.dismiss(animated: true) }
		}
	}

	func showTanScreen() {
		let vc = createTanInputViewController()
		push(vc)
	}

	func showTestResultScreen(with testResult: TestResult) {
		let vc = createTestResultViewController(with: testResult)
		push(vc)
	}
	
	// MARK: - Private

	/// - NOTE: We keep a weak reference here to avoid a reference cycle.
	///  (the navigationController holds a strong reference to the coordinator).
	private weak var navigationController: UINavigationController?
	private weak var parentNavigationController: UINavigationController?
	private weak var presentedViewController: UIViewController?

	private var model: ExposureSubmissionCoordinatorModel!
	private let warnOthersReminder: WarnOthersRemindable
	
	private func push(_ vc: UIViewController) {
		self.navigationController?.pushViewController(vc, animated: true)
		
	}

	// MARK: Initial Screens

	/// This method selects the correct initial view controller among the following options:
	/// Option 1: (only for UITESTING) if the `-negativeResult` flag was passed, return ExposureSubmissionTestResultViewController
	/// Option 2: if a test result was passed, the method checks further preconditions (e.g. the exposure submission service has a registration token)
	/// and returns an ExposureSubmissionTestResultViewController.
	/// Option 3: (default) return the ExposureSubmissionIntroViewController.
	private func getInitialViewController(with result: TestResult? = nil) -> UIViewController {
		#if DEBUG
		if isUITesting {
			model.exposureSubmissionService.isSubmissionConsentGiven = false
			if UserDefaults.standard.string(forKey: "isSubmissionConsentGiven") == "YES" {
				model.exposureSubmissionService.isSubmissionConsentGiven = true
			}
			
			if let testResultStringValue = UserDefaults.standard.string(forKey: "testResult"),
			   let testResult = TestResult(stringValue: testResultStringValue) {
				return createTestResultViewController(with: testResult)
			}
		}
		#endif

		// We got a test result and can jump straight into the test result view controller.
		if let testResult = result, model.exposureSubmissionService.hasRegistrationToken {
			// For a positive test result we show the test result available screen if it wasn't shown before
			if testResult == .positive && !model.exposureSubmissionService.positiveTestResultWasShown {
				return createTestResultAvailableViewController(testResult: testResult)
			} else {
				return createTestResultViewController(with: testResult)
			}
		}

		// By default, we show the intro view.
		let viewModel = ExposureSubmissionIntroViewModel(
			onQRCodeButtonTap: { [weak self] in self?.showQRInfoScreen() },
			onTANButtonTap: { [weak self] in self?.showTanScreen() },
			onHotlineButtonTap: { [weak self] in self?.showHotlineScreen() }
		)
		return ExposureSubmissionIntroViewController(viewModel)
	}

	/// method to get an instance of TestResultAvailableViewController
	private func createTestResultAvailableViewController(testResult: TestResult) -> UIViewController {
		let viewModel = TestResultAvailableViewModel(
			exposureSubmissionService: model.exposureSubmissionService,
			didTapConsentCell: { [weak self] isLoading in
				self?.model.exposureSubmissionService.loadSupportedCountries(
					isLoading: isLoading,
					onSuccess: {
						self?.showTestResultSubmissionConsentScreen(
							presentDismissAlert: {
								self?.presentTestResultCloseAlert()
							}
						)
					},
					onError: { error in
						self?.showErrorAlert(for: error)
					}
				)
			},
			didTapPrimaryFooterButton: { [weak self] isLoading in
				isLoading(true)

				self?.model.exposureSubmissionService.getTemporaryExposureKeys { error in
					isLoading(false)

					if let error = error {
						self?.showErrorAlert(for: error)
					} else {
						self?.showTestResultScreen(with: testResult)
					}
				}
			},
			presentDismissAlert: { [weak self] in
				self?.presentTestResultCloseAlert()
			}
		)
		return TestResultAvailableViewController(viewModel)
	}
	
	private func createTestResultViewController(with testResult: TestResult) -> ExposureSubmissionTestResultViewController {
		return ExposureSubmissionTestResultViewController(
			viewModel: .init(
				warnOthersReminder: warnOthersReminder,
				testResult: testResult,
				exposureSubmissionService: model.exposureSubmissionService,
				onContinueWithSymptomsFlowButtonTap: { [weak self] isLoading in
					self?.model.exposureSubmissionService.loadSupportedCountries(
						isLoading: isLoading,
						onSuccess: {
							self?.showSymptomsScreen()
						}, onError: { error in
							self?.showErrorAlert(for: error)
						}
					)
				},
				onContinueWithoutSymptomsFlowButtonTap: { [weak self] isLoading in
					self?.model.exposureSubmissionService.loadSupportedCountries(
						isLoading: isLoading,
						onSuccess: {
							self?.showWarnOthersScreen()
						},
						onError: { error in
							self?.showErrorAlert(for: error)
						}
					)
				},
				onContinueHomeButtonTap: { [weak self] in
					self?.dismiss()
				},
				onTestDeleted: { [weak self] in
					self?.dismiss()
				},
				onSubmissionConsentButtonTap: { [weak self] isLoading in
					self?.model.exposureSubmissionService.loadSupportedCountries(
						isLoading: isLoading,
						onSuccess: {
							self?.showTestResultSubmissionConsentScreen(presentDismissAlert: nil)
						},
						onError: { error in
							self?.showErrorAlert(for: error)
						}
					)
				}
			),
			exposureSubmissionService: self.model.exposureSubmissionService,
			presentCancelAlert: { [weak self] in
				if testResult == TestResult.positive {
					self?.presentPositiveTestResultCancelAlert()
				} else {
					self?.dismiss()
				}
				
			}
		)
	}

	// MARK: Screen Flow

	private func showHotlineScreen() {
		let vc = createHotlineViewController()
		push(vc)
	}

	private func showQRInfoScreen() {
		let vc = ExposureSubmissionQRInfoViewController(
			supportedCountries: model.exposureSubmissionService.supportedCountries,
			onPrimaryButtonTap: { [weak self] isLoading in
				self?.model.exposureSubmissionService.acceptPairing()
				self?.model.exposureSubmissionService.isSubmissionConsentGiven = true
				self?.showQRScreen(isLoading: isLoading)
			}
		)

		push(vc)
	}

	private func showQRScreen(isLoading: @escaping (Bool) -> Void) {
		let scannerViewController = ExposureSubmissionQRScannerViewController(
			onSuccess: { [weak self] deviceRegistrationKey in
				self?.presentedViewController?.dismiss(animated: true) {
					self?.getTestResults(for: deviceRegistrationKey, isLoading: isLoading)
				}
			},
			onError: { [weak self] error, reactivateScanning in
				switch error {
				case .cameraPermissionDenied:
					DispatchQueue.main.async {
						let alert = UIAlertController.errorAlert(message: error.localizedDescription, completion: {
							self?.presentedViewController?.dismiss(animated: true)
						})
						self?.presentedViewController?.present(alert, animated: true)
					}
				case .codeNotFound:
					DispatchQueue.main.async {
						let alert = UIAlertController.errorAlert(
							title: AppStrings.ExposureSubmissionError.qrAlreadyUsedTitle,
							message: AppStrings.ExposureSubmissionError.qrAlreadyUsed,
							okTitle: AppStrings.Common.alertActionCancel,
							secondaryActionTitle: AppStrings.Common.alertActionRetry,
							completion: { [weak self] in
								self?.presentedViewController?.dismiss(animated: true)
							},
							secondaryActionCompletion: { reactivateScanning() }
						)
						self?.presentedViewController?.present(alert, animated: true)
					}
				case .other:
					Log.error("QRScannerError.other occurred.", log: .ui)
				}
			},
			onCancel: { [weak self] in
				self?.model.exposureSubmissionService.isSubmissionConsentGiven = false
				self?.presentedViewController?.dismiss(animated: true)
			}
		)

		let qrScannerNavigationController = UINavigationController(rootViewController: scannerViewController)
		qrScannerNavigationController.modalPresentationStyle = .fullScreen

		navigationController?.present(qrScannerNavigationController, animated: true)
		presentedViewController = qrScannerNavigationController
	}

	private func showTestResultAvailableScreen(with testResult: TestResult) {
		let vc = createTestResultAvailableViewController(testResult: testResult)
		push(vc)
	}

	private func showTestResultSubmissionConsentScreen(presentDismissAlert: (() -> Void)?) {
		let vc = ExposureSubmissionTestResultConsentViewController(
			viewModel: ExposureSubmissionTestResultConsentViewModel(
				supportedCountries: model.exposureSubmissionService.supportedCountries,
				exposureSubmissionService: model.exposureSubmissionService,
				presentDismissAlert: presentDismissAlert
			)
		)

		push(vc)
	}

	// MARK: Late consent

	private func showWarnOthersScreen() {
		let vc = createWarnOthersViewController(
			supportedCountries: model.exposureSubmissionService.supportedCountries,
			onPrimaryButtonTap: { [weak self] isLoading in
				self?.model.exposureSubmissionService.isSubmissionConsentGiven = true
				self?.model.exposureSubmissionService.getTemporaryExposureKeys { error in
					isLoading(false)

					if let error = error {
						self?.showErrorAlert(for: error)
					} else {
						self?.showThankYouScreen()
					}
				}
			}
		)

		push(vc)
	}

	private func showThankYouScreen() {
		let thankYouVC = ExposureSubmissionThankYouViewController { [weak self] in
			self?.showSymptomsScreen()
		} onSecondaryButtonTap: { [weak self] in
			self?.presentThankYouCancelAlert()
		} presentCancelAlert: { [weak self] in
			self?.presentThankYouCancelAlert()
		}

		push(thankYouVC)
	}

	// MARK: Symptoms

	private func showSymptomsScreen() {
		let vc = ExposureSubmissionSymptomsViewController(
			onPrimaryButtonTap: { [weak self] selectedSymptomsOption in
				guard let self = self else { return }
				
				self.model.symptomsOptionSelected(selectedSymptomsOption)
				self.model.shouldShowSymptomsOnsetScreen ? self.showSymptomsOnsetScreen() : self.showWarnOthersScreen()
			},
			presentCancelAlert: { [weak self] in
				self?.presentSubmissionSymptomsCancelAlert()
			}
		)

		push(vc)
	}

	private func showSymptomsOnsetScreen() {
		let vc = ExposureSubmissionSymptomsOnsetViewController(
			onPrimaryButtonTap: { [weak self] selectedSymptomsOnsetOption in
				self?.model.symptomsOnsetOptionSelected(selectedSymptomsOnsetOption)
				self?.showWarnOthersScreen()
			}, presentCancelAlert: { [weak self] in
				self?.presentSubmissionSymptomsCancelAlert()
			}
		)

		push(vc)
	}

	// MARK: Cancel Alerts

	private func presentSubmissionSymptomsCancelAlert() {
		let alert = UIAlertController(
			title: AppStrings.ExposureSubmissionSymptomsCancelAlert.title,
			message: AppStrings.ExposureSubmissionSymptomsCancelAlert.message,
			preferredStyle: .alert
		)

		alert.addAction(
			UIAlertAction(
				title: AppStrings.ExposureSubmissionSymptomsCancelAlert.cancelButton,
				style: .cancel,
				handler: { [weak self] _ in
					self?.dismiss()
				}
			)
		)

		alert.addAction(
			UIAlertAction(
				title: AppStrings.ExposureSubmissionSymptomsCancelAlert.continueButton,
				style: .default
			)
		)

		navigationController?.present(alert, animated: true, completion: nil)
	}

	private func presentPositiveTestResultCancelAlert() {
		let isSubmissionConsentGiven = self.model.exposureSubmissionService.isSubmissionConsentGiven

		let alertTitle = isSubmissionConsentGiven ? AppStrings.ExposureSubmissionSymptomsCancelAlert.title : AppStrings.ExposureSubmissionPositiveTestResult.noConsentAlertTitle
		let alertMessage = isSubmissionConsentGiven ? AppStrings.ExposureSubmissionSymptomsCancelAlert.message : AppStrings.ExposureSubmissionPositiveTestResult.noConsentAlertDescription

		let alertButtonCancel = isSubmissionConsentGiven ? AppStrings.ExposureSubmissionSymptomsCancelAlert.cancelButton :
			AppStrings.ExposureSubmissionPositiveTestResult.noConsentAlertButtonDontWarn

		let alertButtonGo = isSubmissionConsentGiven ? AppStrings.ExposureSubmissionSymptomsCancelAlert.continueButton :
			AppStrings.ExposureSubmissionPositiveTestResult.noConsentAlertButtonWarn

		let alert = UIAlertController(
			title: alertTitle,
			message: alertMessage,
			preferredStyle: .alert)

		alert.addAction(
			UIAlertAction(
				title: alertButtonCancel,
				style: .default,
				handler: { [weak self] _ in
					self?.dismiss()
				}
			)
		)
		alert.addAction(
			UIAlertAction(
				title: alertButtonGo,
				style: .cancel
			)
		)

		navigationController?.present(alert, animated: true, completion: nil)
	}

	private func presentTestResultCloseAlert() {
		let alert = UIAlertController(
			title: AppStrings.ExposureSubmissionTestResultAvailable.closeAlertTitle,
			message: AppStrings.ExposureSubmissionTestResultAvailable.closeAlertMessage,
			preferredStyle: .alert
		)

		alert.addAction(
			UIAlertAction(
				title: AppStrings.ExposureSubmissionTestResultAvailable.closeAlertButtonClose,
				style: .cancel,
				handler: { [weak self] _ in
					self?.dismiss()
				}
			)
		)

		alert.addAction(
			UIAlertAction(
				title: AppStrings.ExposureSubmissionTestResultAvailable.closeAlertButtonContinue,
				style: .default
			)
		)

		navigationController?.present(alert, animated: true, completion: nil)
	}
	
	private func presentThankYouCancelAlert() {
		let alertTitle = AppStrings.ExposureSubmissionSymptomsCancelAlert.title
		let alertMessage = AppStrings.ExposureSubmissionSymptomsCancelAlert.message
		let alertButtonLeft = AppStrings.ExposureSubmissionSymptomsCancelAlert.cancelButton
		let alertButtonRight = AppStrings.ExposureSubmissionSymptomsCancelAlert.continueButton
		
		let alert = UIAlertController(
			title: alertTitle,
			message: alertMessage,
			preferredStyle: .alert
		)
		
		alert.addAction(
			UIAlertAction(
				title: alertButtonLeft,
				style: .cancel,
				handler: { [weak self] _ in
					self?.dismiss()
				}
			)
		)
		
		alert.addAction(
			UIAlertAction(
				title: alertButtonRight,
				style: .default
			)
		)

		navigationController?.present(alert, animated: true, completion: nil)
	}
	
	
	private func showErrorAlert(for error: ExposureSubmissionError, onCompletion: (() -> Void)? = nil) {
		Log.error("error: \(error.localizedDescription)", log: .ui)

		let alert = UIAlertController.errorAlert(
			message: error.localizedDescription,
			secondaryActionTitle: error.faqURL != nil ? AppStrings.Common.errorAlertActionMoreInfo : nil,
			secondaryActionCompletion: {
				guard let url = error.faqURL else {
					Log.error("Unable to open FAQ page.", log: .api)
					return
				}

				UIApplication.shared.open(
					url,
					options: [:]
				)
			}
		)

		navigationController?.present(alert, animated: true, completion: {
			onCompletion?()
		})
	}

	// MARK: Test Result Helper

	private func getTestResults(for key: DeviceRegistrationKey, isLoading: @escaping (Bool) -> Void) {
		model.getTestResults(
			for: key,
			isLoading: isLoading,
			onSuccess: { [weak self] testResult in
				switch testResult {
				case .positive:
					self?.showTestResultAvailableScreen(with: testResult)
				case .pending, .negative, .invalid, .expired:
					self?.showTestResultScreen(with: testResult)
				}
			},
			onError: { [weak self] error in
				let alert: UIAlertController

				switch error {
				case .qrDoesNotExist:
					alert = UIAlertController.errorAlert(
						title: AppStrings.ExposureSubmissionError.qrNotExistTitle,
						message: error.localizedDescription
					)

					self?.navigationController?.present(alert, animated: true, completion: nil)
				case .qrAlreadyUsed:
					alert = UIAlertController.errorAlert(
						title: AppStrings.ExposureSubmissionError.qrAlreadyUsedTitle,
						message: error.localizedDescription
					)
				case .qrExpired:
					alert = UIAlertController.errorAlert(
						title: AppStrings.ExposureSubmission.qrCodeExpiredTitle,
						message: error.localizedDescription
					)
				default:
					alert = UIAlertController.errorAlert(
						message: error.localizedDescription,
						secondaryActionTitle: AppStrings.Common.alertActionRetry,
						secondaryActionCompletion: {
							self?.getTestResults(for: key, isLoading: isLoading)
						}
					)
				}

				self?.navigationController?.present(alert, animated: true, completion: nil)

				Log.error("An error occurred during result fetching: \(error)", log: .ui)
			}
		)
	}

}

// MARK: - Creation.

extension ExposureSubmissionCoordinator {
	
	// MARK: - Private

	private func createTanInputViewController() -> ExposureSubmissionTanInputViewController {
		AppStoryboard.exposureSubmission.initiate(viewControllerType: ExposureSubmissionTanInputViewController.self) { coder -> UIViewController? in
			ExposureSubmissionTanInputViewController(coder: coder, coordinator: self, exposureSubmissionService: self.model.exposureSubmissionService)
		}
	}

	private func createHotlineViewController() -> ExposureSubmissionHotlineViewController {
		AppStoryboard.exposureSubmission.initiate(viewControllerType: ExposureSubmissionHotlineViewController.self) { coder -> UIViewController? in
			ExposureSubmissionHotlineViewController(coder: coder, coordinator: self)
		}
	}

	private func createWarnOthersViewController(
		supportedCountries: [Country],
		onPrimaryButtonTap: @escaping (@escaping (Bool) -> Void) -> Void
	) -> ExposureSubmissionWarnOthersViewController {
		AppStoryboard.exposureSubmission.initiate(viewControllerType: ExposureSubmissionWarnOthersViewController.self) { coder -> UIViewController? in
			ExposureSubmissionWarnOthersViewController(coder: coder, supportedCountries: supportedCountries, onPrimaryButtonTap: onPrimaryButtonTap)
		}
	}

	private func createSuccessViewController() -> ExposureSubmissionSuccessViewController {
		AppStoryboard.exposureSubmission.initiate(viewControllerType: ExposureSubmissionSuccessViewController.self) { coder -> UIViewController? in
			ExposureSubmissionSuccessViewController(warnOthersReminder: self.warnOthersReminder, coder: coder, coordinator: self)
		}
	}

}

extension ExposureSubmissionCoordinator: UIAdaptivePresentationControllerDelegate {
	func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
		dismiss()
	}
}
