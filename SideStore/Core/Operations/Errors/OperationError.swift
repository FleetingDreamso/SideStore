//
//  OperationError.swift
//  SideStore
//
//  Created by Magesh K on 3/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import Foundation

public enum OperationError: LocalizedError, CustomNSError, Sendable, Equatable {
    case noInstalledApps
    case noSources
    case notAuthenticated
    case timedOut
    case unableToConnectSideJIT
    case unableToRespondSideJITDevice
    case unknownResult

    case cacheClearError(errors: [String])
    case certificateExpired(appName: String)
    case certificateRevoked(appName: String)
    case customCertificateExpired(appName: String, activeTeam: String)
    case customCertificateRevoked(appName: String, activeTeam: String)
    case forbidden(failureReason: String, file: String = #fileID, line: UInt = #line)
    case invalidApp(reason: String)
    case invalidPairingFile(reason: String)
    case invalidParameters(String)
    case invalidResponse(reason: String)
    case invalidVPN(reason: String)
    case minimuxerNotStarted(reason: String)
    case missingAppBundle(reason: String)
    case missingAppGroup(name: String)
    case missingInfoPlist(reason: String)
    case missingProvisioningProfile(reason: String)
    case missingUpdate(appName: String)
    case noConnection(reason: String)
    case noDevice(reason: String)
    case noVPN(reason: String)
    case notReachable(reason: String)
    case openAppFailed(name: String)
    case pairingNotComplete(reason: String)
    case pledgeInactive(appName: String)
    case SideJITIssue(error: String)
    case unknownUDID(reason: String)

    public static var cancelled: CancellationError { CancellationError() }

    public var rawDescription: String {
        switch self {
        case .noInstalledApps:
            return "没有可刷新的已激活侧载应用。"
        case .noSources:
            return "没有 SideStore 源。"
        case .notAuthenticated:
            return "你尚未登录。"
        case .timedOut:
            return "操作超时。"
        case .unableToConnectSideJIT:
            return "无法连接到 SideJITServer。请确认你与服务器处于同一 Wi-Fi，且服务器上的防火墙设置正确。"
        case .unableToRespondSideJITDevice:
            return "SideJITServer 无法连接到你的 iDevice。请确认你已运行“SideJITServer -y”完成配对，或尝试在设置中重新启动 SideJITServer。"
        case .unknownResult:
            return "操作返回了未知结果。"

        case .cacheClearError(let errors):
            return "清除缓存时发生错误：\(errors.joined(separator: "\n"))"
        case .certificateExpired(let appName):
            return "用于安装“\(appName)”的签名证书已过期。请重新签名或重新安装该应用。"
        case .certificateRevoked(let appName):
            return "用于安装“\(appName)”的签名证书已在 Apple 开发者后台中被吊销。请重新签名或重新安装该应用。"
        case .customCertificateExpired(_, let activeTeam):
            return "你当前使用的自定义/第三方签名证书（团队：\(activeTeam)）已过期。\n\n如果你并不打算使用自定义证书，请在“设置 -> 高级 -> 证书”中重置它。"
        case .customCertificateRevoked(_, let activeTeam):
            return "你当前使用的自定义/第三方签名证书（团队：\(activeTeam)）已在开发者后台中被吊销。\n\n如果你并不打算使用自定义证书，请在“设置 -> 高级 -> 证书”中重置它。"
        case .forbidden(let reason, _, _):
            return reason
        case .invalidApp(let reason):
            return "应用格式无效：\(reason)"
        case .invalidPairingFile(let reason):
            return "当前配对文件无效。原因：\(reason)\n\n请确保输入有效的配对文件！如果问题仍然存在，请使用 iloader 或 idevice_pair 重新生成配对文件。"
        case .invalidParameters(let msg):
            return "参数无效：\n\(msg)"
        case .invalidResponse(let reason):
            return "服务器响应无效：\(reason)"
        case .invalidVPN(let reason):
            return "VPN 连接错误：\n\(reason)\n\n请确保 LocalDevVPN 已连接并正常运行。"
        case .minimuxerNotStarted(let reason):
            return "Minimuxer 尚未启动：\(reason)\n\n请先完成配对或启动 minimuxer，然后再执行操作。"
        case .missingAppBundle(let reason):
            return "找不到应用包：\(reason)"
        case .missingAppGroup(let name):
            return "无法访问 SideStore 的共享 App Group“\(name)”。"
        case .missingInfoPlist(let reason):
            return "找不到应用的 Info.plist：\(reason)"
        case .missingProvisioningProfile(let reason):
            return "找不到该应用的描述文件：\(reason)"
        case .missingUpdate(let appName):
            return "未找到“\(appName)”可用的受支持更新。"
        case .noConnection(let reason):
            return "网络连接错误：\n\(reason)\n\n请先连接 Wi-Fi 再尝试后续操作。"
        case .noDevice(let reason):
            return "SideStore 无法连接设备端点：\n\(reason)\n\n请检查“设置”中的连接配置。"
        case .noVPN(let reason):
            return "VPN 连接错误：\n\(reason)\n\n请确保 LocalDevVPN 已连接并正常运行。"
        case .notReachable(let reason):
            return reason.isEmpty ? "无法通过指定的 IP 或端点访问设备。" : reason
        case .openAppFailed(let name):
            return "SideStore 没有启动 \(name) 的权限。"
        case .pairingNotComplete(let reason):
            return "需要配对：\(reason)\n\n没有有效的配对文件，SideStore 的操作就无法连接到你的设备。请配对设备或导入有效的配对文件。"
        case .pledgeInactive(let appName):
            return "你的赞助已失效。请续订以继续正常使用 \(appName)。"
        case .SideJITIssue(let error):
            return "使用 SideJIT 时发生错误：\(error)"
        case .unknownUDID(let reason):
            return "SideStore 无法确定此设备的 UDID：\(reason)\n\n请使用 iloader 或 idevice_pair 重新生成配对文件。"
        }
    }

    public var errorDescription: String? {
        return self.failureReason
    }

    public var failureReason: String? {
        return NSLocalizedString(self.rawDescription, comment: "")
    }

    public var recoverySuggestion: String? {
        switch self {
        case .invalidPairingFile:
            return NSLocalizedString("导入有效的 mobiledevicepairing 文件。", comment: "")
        case .invalidVPN, .noVPN:
            return NSLocalizedString("请确保 LocalDevVPN 已连接并正在运行！", comment: "")
        case .noConnection:
            return NSLocalizedString("请连接到 Wi-Fi 网络、网桥或有线网络连接！", comment: "")
        default:
            return nil
        }
    }
}
