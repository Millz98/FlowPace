import Foundation
import Combine
import UIKit

@MainActor
class TimerManager: ObservableObject {
    @Published var state: TimerState = .idle
    @Published var currentStep: TimerStep?
    @Published var nextStep: TimerStep?
    @Published var timeRemaining: TimeInterval = 0
    @Published var overallProgress: Double = 0
    @Published var stepProgress: Double = 0

    private var timer: Timer?
    private var routine: Routine?
    private var currentStepIndex = 0
    private var currentGroupIndex = 0
    private var currentLoopIndex = 0
    private var totalElapsed: TimeInterval = 0
    private var totalDuration: TimeInterval = 0

    private var flattenedSteps: [Step] = []
    private var stepStartTimes: [TimeInterval] = []

    // Date-based timing: snapshot the wall-clock time on each tick
    private var lastTickDate: Date?
    private var accumulatedElapsed: TimeInterval = 0

    // Persistence keys
    private let persistedRoutineIdKey = "timerPersistedRoutineId"
    private let persistedStepIndexKey = "timerPersistedStepIndex"
    private let persistedAccumulatedElapsedKey = "timerPersistedAccumulatedElapsed"
    private let persistedTotalDurationKey = "timerPersistedTotalDuration"
    private let persistedFlattenedStepsKey = "timerPersistedFlattenedSteps"

    // Computed properties to ensure progress values are always valid
    var safeStepProgress: Double {
        return stepProgress.isNaN || stepProgress.isInfinite ? 0 : max(0, min(1, stepProgress))
    }

    var safeOverallProgress: Double {
        return overallProgress.isNaN || overallProgress.isInfinite ? 0 : max(0, min(1, overallProgress))
    }

    init() {
        // Listen for app lifecycle to handle background/foreground
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods

    func startRoutine(_ routine: Routine) {
        self.routine = routine
        self.totalDuration = max(0, routine.totalDuration)
        self.flattenedSteps = flattenRoutine(routine)
        self.stepStartTimes = calculateStepStartTimes()

        guard !flattenedSteps.isEmpty else {
            print("TimerManager: No valid steps found in routine")
            return
        }

        let invalidSteps = flattenedSteps.filter { $0.duration <= 0 }
        guard invalidSteps.isEmpty else {
            print("TimerManager: Found steps with invalid durations: \(invalidSteps)")
            return
        }

        resetToBeginning()

        // Initialize the first step before starting the timer
        updateCurrentStep()
        startTimer()
    }

    func stopRoutine() {
        stopTimer()
        resetToBeginning()
        clearPersistedState()
    }

    func togglePlayPause() {
        switch state {
        case .running:
            pauseTimer()
        case .paused:
            resumeTimer()
        default:
            break
        }
    }

    func skipForward() {
        moveToNextStep()
    }

    func skipBackward() {
        moveToPreviousStep()
    }

    func resetRoutine() {
        resetToBeginning()
    }

    // MARK: - Background / Foreground Handling

    @objc private func appDidEnterBackground() {
        guard state == .running else { return }
        // Snapshot the elapsed time so we can adjust on foreground
        if let lastTick = lastTickDate {
            let elapsedSinceTick = Date().timeIntervalSince(lastTick)
            accumulatedElapsed += max(0, elapsedSinceTick)
        }
        // Persist state so we survive a kill
        persistState()
        // Invalidate the timer -- it won't fire in background
        timer?.invalidate()
        timer = nil
    }

    @objc private func appWillEnterForeground() {
        guard state == .running else { return }
        // Recalculate based on wall-clock time accumulated while backgrounded
        // accumulatedElapsed was already captured in didEnterBackground
        // Now just restart the tick loop
        lastTickDate = Date()
        startTimer()
    }

    // MARK: - State Persistence

    private func persistState() {
        guard let routine = routine else { return }
        let defaults = UserDefaults.standard
        defaults.set(routine.id.uuidString, forKey: persistedRoutineIdKey)
        defaults.set(currentStepIndex, forKey: persistedStepIndexKey)
        defaults.set(accumulatedElapsed, forKey: persistedAccumulatedElapsedKey)
        defaults.set(totalDuration, forKey: persistedTotalDurationKey)
        if let data = try? JSONEncoder().encode(flattenedSteps) {
            defaults.set(data, forKey: persistedFlattenedStepsKey)
        }
    }

    private func clearPersistedState() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: persistedRoutineIdKey)
        defaults.removeObject(forKey: persistedStepIndexKey)
        defaults.removeObject(forKey: persistedAccumulatedElapsedKey)
        defaults.removeObject(forKey: persistedTotalDurationKey)
        defaults.removeObject(forKey: persistedFlattenedStepsKey)
    }

    func restorePersistedState(using routineManager: RoutineManager) -> Bool {
        let defaults = UserDefaults.standard
        guard let routineIdString = defaults.string(forKey: persistedRoutineIdKey),
              let routineId = UUID(uuidString: routineIdString),
              let routine = routineManager.getRoutine(by: routineId) else {
            return false
        }

        let stepIndex = defaults.integer(forKey: persistedStepIndexKey)
        let savedAccumulated = defaults.double(forKey: persistedAccumulatedElapsedKey)
        let savedTotalDuration = defaults.double(forKey: persistedTotalDurationKey)

        guard let stepsData = defaults.data(forKey: persistedFlattenedStepsKey),
              let savedSteps = try? JSONDecoder().decode([Step].self, from: stepsData) else {
            return false
        }

        // Only restore if the timer was actually running
        guard stepIndex < savedSteps.count else { return false }

        self.routine = routine
        self.flattenedSteps = savedSteps
        self.currentStepIndex = stepIndex
        self.accumulatedElapsed = savedAccumulated
        self.totalDuration = max(0, savedTotalDuration)
        self.totalElapsed = savedAccumulated
        self.stepStartTimes = calculateStepStartTimes()

        // Restore the current step display
        updateCurrentStep()

        // Resume the timer
        state = .running
        startTimer()

        return true
    }

    // MARK: - Private Timer Methods

    private func startTimer() {
        state = .running
        lastTickDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTimer()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        state = .idle
        lastTickDate = nil
    }

    private func pauseTimer() {
        // Snapshot elapsed before pausing
        if let lastTick = lastTickDate {
            let elapsedSinceTick = Date().timeIntervalSince(lastTick)
            accumulatedElapsed += max(0, elapsedSinceTick)
        }
        timer?.invalidate()
        timer = nil
        state = .paused
        lastTickDate = nil
    }

    private func resumeTimer() {
        startTimer()
    }

    private func updateTimer() {
        guard let currentStep = currentStep else { return }
        guard currentStep.step.duration > 0 else { return }

        // Date-based elapsed calculation: accumulated + time since last tick
        var elapsedSinceTick: TimeInterval = 0
        if let lastTick = lastTickDate {
            elapsedSinceTick = max(0, Date().timeIntervalSince(lastTick))
        }
        let currentTotalElapsed = accumulatedElapsed + elapsedSinceTick
        lastTickDate = Date()

        totalElapsed = currentTotalElapsed

        // Calculate remaining time for current step
        let stepStartTime = stepStartTimes.indices.contains(currentStepIndex) ? stepStartTimes[currentStepIndex] : 0
        let stepElapsed = max(0, currentTotalElapsed - stepStartTime)
        let newRemaining = max(0, currentStep.step.duration - stepElapsed)
        timeRemaining = newRemaining

        // Update step progress with safety checks
        if currentStep.step.duration > 0 {
            stepProgress = max(0, min(1, stepElapsed / currentStep.step.duration))
        } else {
            stepProgress = 0
        }

        // Update overall progress with safety checks
        if totalDuration > 0 {
            overallProgress = max(0, min(1, currentTotalElapsed / totalDuration))
        } else {
            overallProgress = 0
        }

        // Check if current step is complete
        if timeRemaining <= 0 {
            // Commit accumulated time before moving to next step
            accumulatedElapsed = currentTotalElapsed
            moveToNextStep()
        }
    }

    // MARK: - Step Navigation

    private func moveToNextStep() {
        currentStepIndex += 1

        if currentStepIndex >= flattenedSteps.count {
            // Routine completed
            completeRoutine()
        } else {
            // Commit accumulated time
            if let lastTick = lastTickDate {
                let elapsedSinceTick = max(0, Date().timeIntervalSince(lastTick))
                accumulatedElapsed += elapsedSinceTick
                lastTickDate = Date()
            }
            // Move to next step
            updateCurrentStep()
        }
    }

    private func moveToPreviousStep() {
        currentStepIndex = max(0, currentStepIndex - 1)
        // Recalculate accumulated elapsed to match the start of the new step
        if stepStartTimes.indices.contains(currentStepIndex) {
            accumulatedElapsed = stepStartTimes[currentStepIndex]
        }
        updateCurrentStep()
    }

    private func updateCurrentStep() {
        guard currentStepIndex < flattenedSteps.count else { return }

        let step = flattenedSteps[currentStepIndex]

        // Calculate remaining based on accumulated elapsed
        let stepStartTime = stepStartTimes.indices.contains(currentStepIndex) ? stepStartTimes[currentStepIndex] : 0
        let stepElapsed = max(0, accumulatedElapsed - stepStartTime)
        timeRemaining = max(0, step.duration - stepElapsed)

        // Update current step
        currentStep = TimerStep(
            step: step,
            remainingTime: timeRemaining,
            isActive: true,
            stepIndex: currentStepIndex,
            totalSteps: flattenedSteps.count
        )

        // Update next step
        if currentStepIndex + 1 < flattenedSteps.count {
            let nextStep = flattenedSteps[currentStepIndex + 1]
            self.nextStep = TimerStep(
                step: nextStep,
                remainingTime: max(0, nextStep.duration),
                isActive: false,
                stepIndex: currentStepIndex + 1,
                totalSteps: flattenedSteps.count
            )
        } else {
            self.nextStep = nil
        }

        // Reset step progress
        stepProgress = 0
        overallProgress = 0
    }

    private func resetToBeginning() {
        currentStepIndex = 0
        currentGroupIndex = 0
        currentLoopIndex = 0
        totalElapsed = 0
        accumulatedElapsed = 0
        timeRemaining = 0
        overallProgress = 0
        stepProgress = 0
        currentStep = nil
        nextStep = nil
        state = .idle
        lastTickDate = nil
    }

    private func completeRoutine() {
        stopTimer()
        state = .completed
        currentStep = nil
        nextStep = nil
        overallProgress = 1.0

        // Record the completed routine for stats tracking
        if let routine = routine {
            NotificationCenter.default.post(
                name: NSNotification.Name("RoutineCompleted"),
                object: nil,
                userInfo: [
                    "routine": routine,
                    "totalDuration": totalDuration
                ]
            )
        }
        stepProgress = 1.0
        clearPersistedState()
    }

    // MARK: - Helper Methods

    private func flattenRoutine(_ routine: Routine) -> [Step] {
        var steps: [Step] = []

        for item in routine.steps {
            switch item {
            case .step(let step):
                if step.duration > 0 {
                    steps.append(step)
                }
            case .group(let group):
                for _ in 0..<group.loopCount {
                    for step in group.steps {
                        if step.duration > 0 {
                            steps.append(step)
                        }
                    }
                }
            }
        }

        return steps
    }

    private func calculateStepStartTimes() -> [TimeInterval] {
        var startTimes: [TimeInterval] = []
        var currentTime: TimeInterval = 0

        for step in flattenedSteps {
            startTimes.append(currentTime)
            currentTime += step.duration
        }

        return startTimes
    }

    // MARK: - Computed Properties

    var isRunning: Bool {
        state == .running
    }

    var isPaused: Bool {
        state == .paused
    }

    var isCompleted: Bool {
        state == .completed
    }

    var currentStepName: String? {
        currentStep?.step.name
    }

    var nextStepName: String? {
        nextStep?.step.name
    }

    var currentStepColor: StepColor? {
        currentStep?.step.color
    }
}
