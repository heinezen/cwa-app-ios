//
// Corona-Warn-App
//
// SAP SE and all other contributors /
// copyright owners license this file to you under the Apache
// License, Version 2.0 (the "License"); you may not use this
// file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
//

import Foundation

typealias RiskCalculationResult = Result<Risk, RiskCalculationError>

enum RiskCalculationError: Error {
	case timeout
	case missingAppConfig
	case missingCachedSummary
	case failedRiskCalculation
	case failedRiskDetection(ExposureDetection.DidEndPrematurelyReason)
}

protocol RiskProviding: AnyObject {
	typealias Completion = (RiskCalculationResult) -> Void

	func observeRisk(_ consumer: RiskConsumer)
	func requestRisk(userInitiated: Bool, ignoreCachedSummary: Bool, completion: Completion?)
	func nextExposureDetectionDate() -> Date

	var configuration: RiskProvidingConfiguration { get set }
}
