//
// 🦠 Corona-Warn-App
//

import UIKit
import Combine

class ExposureSubmissionTestResultConsentViewController: DynamicTableViewController {
	
	
	// MARK: - Init
	
	init(
		supportedCountries: [Country],
		exposureSubmissionService: ExposureSubmissionService
	) {
				
		self.viewModel = ExposureSubmissionTestResultConsentViewModel(supportedCountries: supportedCountries, exposureSubmissionService: exposureSubmissionService)
		super.init(nibName: nil, bundle: nil)
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
	
	// MARK: - Private
	
	private let viewModel: ExposureSubmissionTestResultConsentViewModel
		
	private func setupView() {
		view.backgroundColor = .enaColor(for: .background)
		cellBackgroundColor = .clear
		
		dynamicTableViewModel = viewModel.dynamicTableViewModel
		tableView.separatorStyle = .none
		
		tableView.register(
			DynamicTableViewConsentCell.self,
			forCellReuseIdentifier: CustomCellReuseIdentifiers.consentCell.rawValue
		)
	}
}

extension ExposureSubmissionTestResultConsentViewController {
	enum CustomCellReuseIdentifiers: String, TableViewCellReuseIdentifiers {
		case consentCell
	}
}