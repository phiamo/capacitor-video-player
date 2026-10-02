//
//  FullscreenPlayerContainerViewController.swift
//  CapacitorVideoPlayer
//

import AVKit
import UIKit

/// Plugin-owned fullscreen host. `AVPlayerViewController` is a child for playback chrome only;
/// dismiss is this container's Close, for the whole presentation.
final class FullscreenPlayerContainerViewController: UIViewController {
    let playerViewController: AVPlayerViewController
    private let closeButton = UIButton(type: .system)
    private var didNotifyDismiss = false

    init(playerViewController: AVPlayerViewController) {
        self.playerViewController = playerViewController
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        isModalInPresentation = false
        modalPresentationCapturesStatusBarAppearance = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        embedPlayer()
        installCloseButton()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.bringSubviewToFront(closeButton)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed {
            notifyDismiss()
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        playerViewController.supportedInterfaceOrientations
    }

    override var prefersStatusBarHidden: Bool { true }

    override var prefersHomeIndicatorAutoHidden: Bool { true }

    func detachPlayer() {
        guard playerViewController.parent === self else { return }
        playerViewController.willMove(toParent: nil)
        playerViewController.view.removeFromSuperview()
        playerViewController.removeFromParent()
    }

    @objc func closeTapped() {
        notifyDismiss()
        if !isBeingDismissed {
            presentingViewController?.dismiss(animated: true)
        }
    }

    private func embedPlayer() {
        addChild(playerViewController)
        playerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playerViewController.view)
        NSLayoutConstraint.activate([
            playerViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            playerViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        playerViewController.didMove(toParent: self)
    }

    private func installCloseButton() {
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.accessibilityIdentifier = "capacitor-video-player-close"
        closeButton.accessibilityLabel = "Close"
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        closeButton.setImage(
            UIImage(systemName: "xmark.circle.fill", withConfiguration: config),
            for: .normal
        )
        closeButton.tintColor = .white
        closeButton.layer.shadowColor = UIColor.black.cgColor
        closeButton.layer.shadowOpacity = 0.6
        closeButton.layer.shadowRadius = 4
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            closeButton.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func notifyDismiss() {
        guard !didNotifyDismiss else { return }
        didNotifyDismiss = true
        let wasPlaying = (playerViewController.player?.rate ?? 0) > 0
        NotificationCenter.default.post(
            name: .playerFullscreenDismiss,
            object: playerViewController,
            userInfo: ["wasPlaying": wasPlaying]
        )
    }
}
