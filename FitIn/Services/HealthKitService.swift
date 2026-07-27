//
//  HealthKitService.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/22/26.
//
import Foundation
import HealthKit

// Wraps HealthKit access for step count and heart rate data. Expand
// `typesToRead` (and add corresponding query methods) when broader
// Activity Ring / workout data is brought in later.
@MainActor
final class HealthKitService {

    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()

    private init() {}

    enum HealthKitError: Error {
        case notAvailableOnDevice
        case queryFailed(Error)
    }

    private var stepCountType: HKQuantityType {
        HKQuantityType(.stepCount)
    }

    private var heartRateType: HKQuantityType {
        HKQuantityType(.heartRate)
    }

    // MARK: - Authorization

    // Requests read authorization for step count and heart rate. Must be
    // called before todaysSteps() / elevatedHeartRateMinutesToday() will
    // return real data.
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailableOnDevice
        }

        let typesToRead: Set<HKObjectType> = [stepCountType, heartRateType]

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

    // MARK: - Today's elevated heart rate minutes

    // Returns the approximate number of minutes today where heart rate was
    // above `threshold` BPM. Heart rate samples are discrete points in time,
    // not continuous, so this is an estimate: for each pair of consecutive
    // samples where the earlier sample's value is above threshold, the gap
    // between them is counted as elevated time, capped at `maxGapMinutes`
    // per pair so a long stretch without a reading (e.g. watch removed)
    // doesn't get counted as elevated.
    func elevatedHeartRateMinutesToday(threshold: Double = 120, maxGapMinutes: Double = 5) async throws -> Double {
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

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }
                continuation.resume(returning: (results as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }

        guard samples.count > 1 else { return 0 }

        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        var elevatedMinutes: Double = 0

        for i in 0..<(samples.count - 1) {
            let current = samples[i]
            let next = samples[i + 1]
            let bpm = current.quantity.doubleValue(for: bpmUnit)

            guard bpm > threshold else { continue }

            let gapMinutes = next.startDate.timeIntervalSince(current.startDate) / 60
            elevatedMinutes += min(gapMinutes, maxGapMinutes)
        }

        return elevatedMinutes
    }
}
