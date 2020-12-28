////
// 🦠 Corona-Warn-App
//

import UIKit
import OpenCombine

class HomeTableViewModel {

	// MARK: - Init

	init(
		state: HomeState
	) {
		self.state = state
	}

	// MARK: - Internal

	enum Section: Int, CaseIterable {
		case exposureLogging
		case riskAndTest
		case diary
		case infos
		case settings
	}

	enum RiskAndTestRow {
		case risk
		case testResult
		case shownPositiveTestResult
		case thankYou
	}

	var state: HomeState

	var numberOfSections: Int {
		Section.allCases.count
	}

	func numberOfRows(in section: Int) -> Int {
		switch Section(rawValue: section) {
		case .exposureLogging:
			return 1
		case .riskAndTest:
			return 1
		case .diary:
			return 1
		case .infos:
			return 2
		case .settings:
			return 2
		case .none:
			fatalError("Invalid section")
		}
	}

	func heightForHeader(in section: Int) -> CGFloat {
		switch Section(rawValue: section) {
		case .exposureLogging, .riskAndTest, .diary:
			return 0
		case .infos, .settings:
			return 16
		case .none:
			fatalError("Invalid section")
		}
	}

	func heightForFooter(in section: Int) -> CGFloat {
		switch Section(rawValue: section) {
		case .exposureLogging, .riskAndTest, .diary:
			return 0
		case .infos:
			return 16
		case .settings:
			return 32
		case .none:
			fatalError("Invalid section")
		}
	}

	// MARK: - Private

}
