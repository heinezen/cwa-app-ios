////
// 🦠 Corona-Warn-App
//

import UIKit

class HomeStatisticsTableViewCell: UITableViewCell {

	// MARK: - Overrides

    override func awakeFromNib() {
        super.awakeFromNib()

		self.addGestureRecognizer(scrollView.panGestureRecognizer)
    }

	// MARK: - Internal

	func configure(onInfoButtonTap: @escaping () -> Void) {
		stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

		for _ in 0...3 {
			let nibName = String(describing: HomeStatisticsCardView.self)
			let nib = UINib(nibName: nibName, bundle: .main)

			if let statisticsCardView = nib.instantiate(withOwner: self, options: nil).first as? HomeStatisticsCardView {
				stackView.addArrangedSubview(statisticsCardView)

				statisticsCardView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
				statisticsCardView.configure(onInfoButtonTap: {
					onInfoButtonTap()
				})
			}
		}
	}

	// MARK: - Private

	@IBOutlet private weak var scrollView: UIScrollView!
	@IBOutlet private weak var stackView: UIStackView!

}
