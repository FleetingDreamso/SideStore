//
//  UIAlertAction+Actions.swift
//  AltStore
//
//  Created by Magesh K on 8/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import UIKit

public extension UIAlertAction {
    static var ok: UIAlertAction {
        return UIAlertAction(title: systemLocalizedString("好"), style: .default, handler: nil)
    }

    static var cancel: UIAlertAction {
        return UIAlertAction(title: systemLocalizedString("取消"), style: .cancel, handler: nil)
    }
}
