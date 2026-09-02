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

    // MARK: - Background delivery

    // Enables HealthKit background delivery for steps and heart rate, so
    // iOS can relaunch the app shortly after new data is written (e.g.
    // right after a Watch sync). Requires authorization to already be
    // granted — safe to call repeatedly otherwise.
    func enableBackgroundDelivery() async {
        _ = try? await healthStore.enableBackgroundDelivery(for: stepCountType, frequency: .immediate)
        _ = try? await healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate)
    }

    // Registers observer queries for steps and heart rate; `onChange`
    // fires whenever new data of either type is written, including when
    // iOS relaunches the app in the background specifically to deliver
    // this. Must be called on every launch (including background
    // relaunches) — HealthKit persists the background-delivery setting,
    // but not the observer query itself across process launches.
    func startObservingHealthChanges(onChange: @escaping () async -> Void) {
        for sampleType in [stepCountType, heartRateType] {
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { _, completionHandler, error in
                guard error == nil else {
                    completionHandler()
                    return
                }
                Task {
                    await onChange()
                    completionHandler()
                }
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Steps

    // Returns the cumulative step count for the current day. Thin wrapper
    // around steps(on:) for today, kept so existing call sites don't need
    // to change.
    func todaysSteps() async throws -> Double {
        try await steps(on: Date())
    }

    // Returns the cumulative step count for the given day, clamped to
    // "now" if `date` is today. Missing samples (e.g. right after
    // midnight) are treated as 0 rather than an error.
    func steps(on date: Date) async throws -> Double {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailableOnDevice
        }

        let (start, end) = Self.dayBounds(for: date)

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepCountType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == HKErrorDomain, nsError.code == HKError.Code.errorNoData.rawValue {
                        continuation.resume(returning: 0)
                    } else {
                        continuation.resume(throwing: HealthKitError.queryFailed(error))
                    }
                    return
                }

                let sum = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: sum)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Elevated heart rate minutes

    // Returns elevated minutes for today. Thin wrapper around
    // elevatedHeartRateMinutes(on:threshold:maxGapMinutes:).
    func elevatedHeartRateMinutesToday(threshold: Double = 120, maxGapMinutes: Double = 5) async throws -> Double {
        try await elevatedHeartRateMinutes(on: Date(), threshold: threshold, maxGapMinutes: maxGapMinutes)
    }

    // Estimates minutes above `threshold` BPM on the given day, by summing
    // gaps between consecutive samples where the earlier sample is above
    // threshold, capped at `maxGapMinutes` per gap so missing readings
    // (e.g. watch removed) aren't counted as elevated.
    func elevatedHeartRateMinutes(on date: Date, threshold: Double = 120, maxGapMinutes: Double = 5) async throws -> Double {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailableOnDevice
        }

        let (start, end) = Self.dayBounds(for: date)

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
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

    // Returns (start, end) for `date`'s local calendar day, clamped to
    // "now" if `date` is today.
    private static func dayBounds(for date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let end = min(startOfNextDay, Date())
        return (startOfDay, end)
    }
}
