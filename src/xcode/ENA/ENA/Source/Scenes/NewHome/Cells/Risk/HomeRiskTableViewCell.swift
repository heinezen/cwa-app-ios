//
// 🦠 Corona-Warn-App
//

import UIKit
import OpenCombine

/// A cell that visualizes the current risk and allows the user to calculate he/his current risk.
final class HomeRiskTableViewCell: UITableViewCell {

	// MARK: - Overrides

	override func awakeFromNib() {
		super.awakeFromNib()

		stackView.setCustomSpacing(16.0, after: riskViewStackView)
		setupAccessibility()
	}

	override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		super.traitCollectionDidChange(previousTraitCollection)

		button.titleLabel?.lineBreakMode = traitCollection.preferredContentSizeCategory >= .accessibilityMedium ? .byTruncatingMiddle : .byWordWrapping
	}

	// Ignore touches on the button when it's disabled
	override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
		let buttonPoint = convert(point, to: button)
		let containsPoint = button.bounds.contains(buttonPoint)
		if containsPoint, !button.isEnabled {
			return nil
		}

		return super.hitTest(point, with: event)
	}

	// MARK: - Internal

	func configure(with cellModel: HomeRiskCellModel) {
		cellModel.$title.assign(to: \.text, on: titleLabel).store(in: &subscriptions)
		cellModel.$title.assign(to: \.accessibilityLabel, on: topContainer).store(in: &subscriptions)

		cellModel.$titleColor.assign(to: \.textColor, on: titleLabel).store(in: &subscriptions)

		cellModel.$body.assign(to: \.text, on: bodyLabel).store(in: &subscriptions)
		cellModel.$bodyColor.assign(to: \.textColor, on: bodyLabel).store(in: &subscriptions)
		cellModel.$isBodyHidden.assign(to: \.isHidden, on: bodyLabel).store(in: &subscriptions)

		cellModel.$backgroundColor
			.sink { [weak self] in
				self?.containerView.backgroundColor = $0
			}
			.store(in: &subscriptions)

		cellModel.$buttonTitle
			.sink { [weak self] buttonTitle in
				UIView.performWithoutAnimation {
					self?.button.setTitle(buttonTitle, for: .normal)

					self?.button.layoutIfNeeded()
				}
			}
			.store(in: &subscriptions)

		cellModel.$isButtonInverted.assign(to: \.isInverted, on: button).store(in: &subscriptions)
		cellModel.$isButtonEnabled.assign(to: \.isEnabled, on: button).store(in: &subscriptions)
		cellModel.$isButtonHidden.assign(to: \.isHidden, on: button).store(in: &subscriptions)
		cellModel.$buttonTitle.assign(to: \.accessibilityLabel, on: button).store(in: &subscriptions)

		button.isAccessibilityElement = true
		button.accessibilityIdentifier = AccessibilityIdentifiers.Home.riskCardIntervalUpdateTitle

		cellModel.$itemViewModels
			.sink { [weak self] itemViewModels in
				guard let self = self else { return }

				self.riskViewStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

				for itemModel in itemViewModels {
					let nibName = String(describing: itemModel.ViewType)
					let nib = UINib(nibName: nibName, bundle: .main)

					if let itemView = nib.instantiate(withOwner: self, options: nil).first as? HomeItemViewAny {
						self.riskViewStackView.addArrangedSubview(itemView)
						itemView.configureAny(with: itemModel)
					}
				}

				if let riskItemView = self.riskViewStackView.arrangedSubviews.last as? HomeItemViewSeparatorable {
					riskItemView.hideSeparator()
				}

				self.riskViewStackView.isHidden = self.riskViewStackView.arrangedSubviews.isEmpty
			}
			.store(in: &subscriptions)

		// Retaining cell model so it gets updated
		self.cellModel = cellModel
	}

	// MARK: - Private

	@IBOutlet private weak var titleLabel: ENALabel!
	@IBOutlet private weak var chevronImageView: UIImageView!
	@IBOutlet private weak var bodyLabel: ENALabel!
	@IBOutlet private weak var button: ENAButton!

	@IBOutlet private weak var containerView: UIView!
	@IBOutlet private weak var topContainer: UIStackView!
	@IBOutlet private weak var stackView: UIStackView!
	@IBOutlet private weak var riskViewStackView: UIStackView!

	private var subscriptions = Set<AnyCancellable>()
	private var cellModel: HomeRiskCellModel?

	@IBAction private func buttonTapped(_: UIButton) {
		cellModel?.onButtonTap()
	}

	private func setupAccessibility() {
		titleLabel.isAccessibilityElement = false
		chevronImageView.isAccessibilityElement = false
		containerView.isAccessibilityElement = false
		stackView.isAccessibilityElement = false

		topContainer.isAccessibilityElement = true
		bodyLabel.isAccessibilityElement = true
		button.isAccessibilityElement = true

		topContainer.accessibilityTraits = [.updatesFrequently, .button]
		bodyLabel.accessibilityTraits = [.updatesFrequently]
		button.accessibilityTraits = [.updatesFrequently, .button]

		topContainer.accessibilityIdentifier = AccessibilityIdentifiers.RiskCollectionViewCell.topContainer
		bodyLabel.accessibilityIdentifier = AccessibilityIdentifiers.RiskCollectionViewCell.bodyLabel
		button.accessibilityIdentifier = AccessibilityIdentifiers.RiskCollectionViewCell.updateButton
	}

}
