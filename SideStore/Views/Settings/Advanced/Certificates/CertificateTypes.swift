//
//  CertificateTypes.swift
//  SideStore
//
//  Created by Magesh K on 2026-07-03.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SideSign

enum SortOption: String, CaseIterable, Identifiable {
    case creationDate = "创建日期"
    case expiryDate   = "到期日期"
    case name         = "名称"
    case keys         = "密钥"
    case type         = "类型"
    var id: String { rawValue }
}

enum GroupOption: String, CaseIterable, Identifiable {
    case none         = "无"
    case creationDate = "创建日期"
    case expiryDate   = "到期日期"
    case name         = "名称"
    case keys         = "密钥"
    case type         = "类型"
    var id: String { rawValue }
}

enum FileImportMode {
    case certificate
    case privateKey
}

struct KeyTextImportItem: Identifiable {
    let id: String
    let cert: ALTX509Certificate
}

struct GroupedCertificates: Identifiable {
    var id: String { name }
    let name: String
    let certificates: [ALTX509Certificate]
}
