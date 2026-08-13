
import Foundation
import os

/// A menu bar app has no console, so `print` is invisible once it ships. `os_log`
/// is visible in Console.app and readable from the terminal:
///
///     log show --predicate 'subsystem == "Islam-AlorabI.Salat-Times"' --last 10m
///
/// Use `.notice` or `.error` for anything you want to read back later: `.info` and
/// `.debug` are memory-only and never appear in `log show`.
///
nonisolated enum Log {
    static let schedule = Logger(subsystem: "Islam-AlorabI.Salat-Times", category: "schedule")
    static let notifications = Logger(subsystem: "Islam-AlorabI.Salat-Times", category: "notifications")
    static let data = Logger(subsystem: "Islam-AlorabI.Salat-Times", category: "data")
}
