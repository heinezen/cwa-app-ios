//
// 🦠 Corona-Warn-App
//

import UIKit
import Combine

final class ExposureSubmissionSymptomsViewController: DynamicTableViewController, ENANavigationControllerWithFooterChild, RequiresDismissConfirmation {

	typealias PrimaryButtonHandler = (SymptomsOption) -> Void

	enum SymptomsOption {
		case yes, no, preferNotToSay
	}

	// MARK: - Init

	init?(
		coder: NSCoder,
		onPrimaryButtonTap: @escaping PrimaryButtonHandler
	) {
		self.onPrimaryButtonTap = onPrimaryButtonTap

		super.init(coder: coder)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	// MARK: - Overrides

	override func viewDidLoad() {
		super.viewDidLoad()

		setupView()
	}

	// MARK: - Protocol ENANavigationControllerWithFooterChild

	func navigationController(_ navigationController: ENANavigationControllerWithFooter, didTapPrimaryButton button: UIButton) {
		guard let selectedSymptomsOption = selectedSymptomsOption else {
			fatalError("Primary button must not be enabled before the user has selected an option")
		}

		onPrimaryButtonTap(selectedSymptomsOption)
	}

	// MARK: - Private

	private let onPrimaryButtonTap: PrimaryButtonHandler

	@Published private var selectedSymptomsOption: SymptomsOption?

	private var optionGroupSelection: OptionGroupViewModel.Selection? {
		didSet {
			guard case let .option(index: index) = optionGroupSelection else { return }

			switch index {
			case 0:
				selectedSymptomsOption = .yes
			case 1:
				selectedSymptomsOption = .no
			case 2:
				selectedSymptomsOption = .preferNotToSay
			default:
				break
			}
		}
	}

	private var selectedSymptomsOptionConfirmationButtonStateSubscription: AnyCancellable?
	private var optionGroupSelectionSubscription: AnyCancellable?

	private func setupView() {
		navigationItem.title = AppStrings.ExposureSubmissionSymptoms.title
		navigationFooterItem?.primaryButtonTitle = AppStrings.ExposureSubmissionSymptoms.continueButton

		setupTableView()

		selectedSymptomsOptionConfirmationButtonStateSubscription = $selectedSymptomsOption.receive(on: RunLoop.main).sink {
			self.navigationFooterItem?.isPrimaryButtonEnabled = $0 != nil
		}
	}

	private func setupTableView() {
		tableView.delegate = self
		tableView.dataSource = self

		tableView.register(
			DynamicTableViewOptionGroupCell.self,
			forCellReuseIdentifier: CustomCellReuseIdentifiers.optionGroupCell.rawValue
		)

		dynamicTableViewModel = dynamicTableViewModel()
	}

	private func dynamicTableViewModel() -> DynamicTableViewModel {
		
		let bulletPointCells = AppStrings.ExposureSubmissionSymptoms.symptoms.map {
			DynamicCell.bulletPoint(text: $0)
		}
		
		return DynamicTableViewModel.with {
			$0.add(
				.section(
					header: .none,
					cells: [
							.headline(
							 text: AppStrings.ExposureSubmissionSymptoms.description,
							 accessibilityIdentifier: AccessibilityIdentifiers.ExposureSubmissionSymptoms.description
						 )]
						+ bulletPointCells
						+ [
							.subheadline(
								text: AppStrings.ExposureSubmissionSymptoms.introduction,
								color: .enaColor(for: .textPrimary2),
								accessibilityIdentifier: AccessibilityIdentifiers.ExposureSubmissionSymptoms.introduction
						)]
						+ [
							.custom(
								withIdentifier: CustomCellReuseIdentifiers.optionGroupCell,
								configure: { [weak self] _, cell, _ in
									guard let cell = cell as? DynamicTableViewOptionGroupCell else { return }
									
									cell.configure(
										options: [
											.option(title: AppStrings.ExposureSubmissionSymptoms.answerOptionYes,
													accessibilityIdentifier: AccessibilityIdentifiers.ExposureSubmissionSymptoms.answerOptionYes),
											.option(title: AppStrings.ExposureSubmissionSymptoms.answerOptionNo,
													accessibilityIdentifier: AccessibilityIdentifiers.ExposureSubmissionSymptoms.answerOptionNo),
											.option(title: AppStrings.ExposureSubmissionSymptoms.answerOptionPreferNotToSay,
													accessibilityIdentifier: AccessibilityIdentifiers.ExposureSubmissionSymptoms.answerOptionPreferNotToSay)
										],
										// The current selection needs to be provided in case the cell is recreated after leaving and reentering the screen
										initialSelection: self?.optionGroupSelection
									)
									
									self?.optionGroupSelectionSubscription = cell.$selection.sink {
										self?.optionGroupSelection = $0
									}
								}
							)
					]
				)
			)
		}
	}

}

// MARK: - Cell reuse identifiers.

extension ExposureSubmissionSymptomsViewController {
	enum CustomCellReuseIdentifiers: String, TableViewCellReuseIdentifiers {
		case optionGroupCell
	}
}
