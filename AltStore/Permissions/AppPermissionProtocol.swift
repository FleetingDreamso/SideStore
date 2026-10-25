//
//  AppPermissionProtocol.swift
//  AltStore
//
//  Created by Riley Testut on 5/23/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

@dynamicMemberLookup
protocol AppPermissionProtocol: Hashable
{
    var permission: any ALTAppPermission { get }
    var usageDescription: String? { get }
    
    subscript<T>(dynamicMember dynamicMember: KeyPath<any ALTAppPermission, T>) -> T { get }
}

extension AppPermission: AppPermissionProtocol {}

struct PreviewAppPermission: AppPermissionProtocol
{
    var permission: any ALTAppPermission
    var usageDescription: String? { "允许 Delta 使用你照片图库中的图片作为游戏封面。" }
    
    subscript<T>(dynamicMember dynamicMember: KeyPath<any ALTAppPermission, T>) -> T
    {
        return self.permission[keyPath: dynamicMember]
    }
}

extension PreviewAppPermission
{
    static func ==(lhs: PreviewAppPermission, rhs: PreviewAppPermission) -> Bool
    {
        return lhs.permission.isEqual(rhs.permission)
    }
    
    func hash(into hasher: inout Hasher)
    {
        hasher.combine(self.permission)
    }
}
