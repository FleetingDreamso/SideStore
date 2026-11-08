//
//  SetProfileAlertViewController.swift
//  SideStore
//
//  Created by Magesh K on 14/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

@preconcurrency import UIKit
import Foundation
import SideSign

final class SetProfileAlertViewController: UIViewController {
    let installedApp: InstalledApp
    let targetProfile: ALTProvisioningProfile
    let targetCertificate: ALTCertificate?

    init(installedApp: InstalledApp, profile: ALTProvisioningProfile, certificate: ALTCertificate?) {
        self.installedApp = installedApp
        self.targetProfile = profile
        self.targetCertificate = certificate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let currentProfile = ProfileManager.shared.getAssignedProfile(for: installedApp.bundleIdentifier)
        let currentCertName: String
        if let currentProfile = currentProfile,
           let matchingCert = ProfileManager.shared.getMatchingCertificate(for: currentProfile) {
            currentCertName = matchingCert.name
        } else if let signingCert = CertificateManager.shared.getSigningCertificate(for: installedApp) {
            currentCertName = signingCert.name
        } else {
            currentCertName = "活跃开发者证书"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none

        let currentProfileName = currentProfile?.name ?? "默认（Apple ID 管理）"
        let currentProfileBundleID = currentProfile?.bundleIdentifier ?? installedApp.bundleIdentifier
        let currentProfileExpiry = currentProfile != nil ? formatter.string(from: currentProfile!.expirationDate) : formatter.string(from: installedApp.expirationDate)

        let targetProfileName = targetProfile.name
        let targetProfileBundleID = targetProfile.bundleIdentifier
        let targetProfileExpiry = formatter.string(from: targetProfile.expirationDate)
        let targetCertName = targetCertificate?.name ?? "无"
        let targetCertSerial = targetCertificate?.serialNumber ?? "N/A"
        let targetTeam = "\(targetProfile.teamName)（\(targetProfile.teamIdentifier)）"

        let details = """
          • 应用：\(installedApp.name)
          • Bundle ID：\(installedApp.resignedBundleIdentifier)

        [当前描述文件]
          • 名称：\(currentProfileName)
          • Bundle ID：\(currentProfileBundleID)
          • 到期时间：\(currentProfileExpiry)
          • 签名者：\(currentCertName)

        [目标描述文件]
          • 名称：\(targetProfileName)
          • Bundle ID：\(targetProfileBundleID)
          • 到期时间：\(targetProfileExpiry)
          • 团队：\(targetTeam)
          • 签名者：\(targetCertName)
          • 序列号：\(targetCertSerial)
        """

        let detailsLabel = UILabel()
        detailsLabel.text = details
        detailsLabel.font = .systemFont(ofSize: 11, weight: .regular)
        detailsLabel.textColor = .secondaryLabel
        detailsLabel.numberOfLines = 0
        detailsLabel.textAlignment = .left
        detailsLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(detailsLabel)

        NSLayoutConstraint.activate([
            detailsLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            detailsLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),
            detailsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            detailsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10)
        ])

        self.preferredContentSize = CGSize(width: 290, height: 290)
    }
}
