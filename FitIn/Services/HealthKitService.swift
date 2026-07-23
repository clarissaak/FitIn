//
//  HealthKitService.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/22/26.
//
import Foundation
import HealthKit

// Wraps HealthKit access for step count data. Scoped to steps only for now —
// expand `typesToRead` (and add corresponding query methods) when broader
// Activity Ring / workout data is brought in later.
@MainActor
final class HealthKitService {

    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()

    private init() {}

    enum HealthKitError: Error {
        case notAvailableOnDevice
        case stepCountTypeUnavailable
        case queryFailed(Error)
    }

    private var stepCountType: HKQuantityType {
        HKQuantityType(.stepCount)
    }

    // MARK: - Authorization

    // Requests read authorization for step count. Must be called before
    // `todaysSteps()` will return real data.
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailableOnDevice
        }

        let typesToRead: Set<HKObjectType> = [stepCountType]

        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
    }

    // MARK: - Today's steps

    // Returns the cumulative step count for the current day, using the
    // device's local calendar to define "today".
    func todaysSteps() async throws -> Double {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailableOnDevice
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let now = Date()

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepCountType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }

                let sum = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: sum)
            }

            healthStore.execute(query)
        }
    }
}
