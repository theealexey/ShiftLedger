import Testing
import UIKit

@testable import ShiftLedger

@MainActor
struct EditShiftViewControllerTests {
  private let shiftID = UUID(
    uuid: (0x86, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
  )
  private let start = Date(timeIntervalSinceReferenceDate: 300_000)
  private let end = Date(timeIntervalSinceReferenceDate: 328_800)
  @Test("Screen prefill, identifiers и unchanged Save сохраняют UUID")
  func prefillAndSave() throws {
    let workType = try makeWorkType(
      id: UUID(
        uuid: (0x86, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)
      ),
      name: "Lectures"
    )
    let unpaidBreak = UnpaidBreak(
      start: start.addingTimeInterval(3_600),
      end: start.addingTimeInterval(5_400)
    )
    let shift = try Shift(
      id: shiftID,
      workTypeID: workType.id,
      start: start,
      end: end,
      unpaidBreak: unpaidBreak
    )
    var saved: Shift?
    var completions = 0
    let viewModel = EditShiftViewModel(
      timeZoneIdentifier: "UTC",
      workTypes: [workType],
      shift: shift,
      saveShift: { updated in
        saved = updated
        return .success(())
      }
    )
    let dateFormattingLocale = Locale(identifier: "en_US")
    let viewController = EditShiftViewController(
      viewModel: viewModel,
      dateFormattingLocale: dateFormattingLocale
    )
    viewController.onSaved = { _ in
      completions += 1
    }
    viewController.loadViewIfNeeded()
    #expect(viewController.title == EditShiftStrings.title)
    #expect(
      viewController.navigationItem.rightBarButtonItem?.title
        == EditShiftStrings.save
    )
    #expect(
      viewController.navigationItem.rightBarButtonItem?.accessibilityIdentifier
        == "editShift.save"
    )
    let screen: UIScrollView = try requireView(
      "editShift.screen",
      in: viewController.view
    )
    #expect(screen.alwaysBounceVertical)
    let workTypeRow: UIControl = try requireView(
      "editShift.workType",
      in: viewController.view
    )
    #expect(workTypeRow.accessibilityValue == "Lectures")
    #expect(workTypeRow.isUserInteractionEnabled == false)
    let startRow: UIControl = try requireView(
      "editShift.start",
      in: viewController.view
    )
    let endRow: UIControl = try requireView(
      "editShift.end",
      in: viewController.view
    )
    let breakSwitch: UISwitch = try requireView(
      "editShift.unpaidBreak",
      in: viewController.view
    )
    let breakStartRow: UIControl = try requireView(
      "editShift.breakStart",
      in: viewController.view
    )
    let breakEndRow: UIControl = try requireView(
      "editShift.breakEnd",
      in: viewController.view
    )
    expectDate(
      start,
      in: startRow,
      timeZoneIdentifier: "UTC",
      locale: dateFormattingLocale
    )
    expectDate(
      end,
      in: endRow,
      timeZoneIdentifier: "UTC",
      locale: dateFormattingLocale
    )
    #expect(breakSwitch.isOn)
    expectDate(
      unpaidBreak.start,
      in: breakStartRow,
      timeZoneIdentifier: "UTC",
      locale: dateFormattingLocale
    )
    expectDate(
      unpaidBreak.end,
      in: breakEndRow,
      timeZoneIdentifier: "UTC",
      locale: dateFormattingLocale
    )
    try tapSave(on: viewController)
    #expect(saved == shift)
    #expect(saved?.id == shiftID)
    #expect(completions == 1)
    #expect(viewController.presentedViewController == nil)
  }
  @Test("Multi WorkType picker сохраняет текущий exact ID и позволяет сменить его")
  func multiWorkTypePickerUsesExactSelection() async throws {
    let first = try makeWorkType(
      id: UUID(
        uuid: (0x87, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
      ),
      name: "Lectures"
    )
    let second = try makeWorkType(
      id: UUID(
        uuid: (0x87, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)
      ),
      name: "Exams"
    )
    let shift = try Shift(
      id: shiftID,
      workTypeID: second.id,
      start: start,
      end: end
    )
    let viewModel = EditShiftViewModel(
      timeZoneIdentifier: "UTC",
      workTypes: [first, second],
      shift: shift,
      saveShift: { _ in .success(()) }
    )
    let viewController = EditShiftViewController(viewModel: viewModel)
    let window = makeVisibleWindow(root: viewController)
    defer {
      hide(window)
    }
    let row: UIControl = try requireView(
      "editShift.workType",
      in: viewController.view
    )
    #expect(row.accessibilityValue == "Exams")
    row.sendActions(for: .touchUpInside)
    try await waitUntil {
      viewController.presentedViewController is UINavigationController
    }
    let navigation = try #require(
      viewController.presentedViewController as? UINavigationController
    )
    let picker = try #require(
      navigation.topViewController as? WorkTypeSelectionViewController
    )
    picker.loadViewIfNeeded()
    let selectedCell = picker.tableView(
      picker.tableView,
      cellForRowAt: IndexPath(row: 1, section: 0)
    )
    #expect(selectedCell.accessibilityTraits.contains(.selected))
    picker.tableView(
      picker.tableView,
      didSelectRowAt: IndexPath(row: 0, section: 0)
    )
    #expect(viewModel.selectedWorkTypeID == first.id)
    #expect(row.accessibilityValue == "Lectures")
    try await waitUntil {
      viewController.presentedViewController == nil
    }
  }
  @Test("Date pickers сохраняют границы Shift form")
  func datePickersUseEstablishedBounds() async throws {
    let workType = try makeWorkType(
      id: UUID(
        uuid: (0x8a, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
      ),
      name: "Lectures"
    )
    let unpaidBreak = UnpaidBreak(
      start: start.addingTimeInterval(3_600),
      end: start.addingTimeInterval(5_400)
    )
    let shift = try Shift(
      id: shiftID,
      workTypeID: workType.id,
      start: start,
      end: end,
      unpaidBreak: unpaidBreak
    )
    let viewController = EditShiftViewController(
      viewModel: EditShiftViewModel(
        timeZoneIdentifier: "UTC",
        workTypes: [workType],
        shift: shift,
        saveShift: { _ in .success(()) }
      )
    )
    let window = makeVisibleWindow(root: viewController)
    defer {
      hide(window)
    }
    let endPicker = try await presentDatePicker(
      for: "editShift.end",
      from: viewController
    )
    #expect(endPicker.minimumDate == nil)
    #expect(
      endPicker.maximumDate
        == start.addingTimeInterval(48 * 60 * 60)
    )
    viewController.dismiss(animated: false)
    try await waitUntil {
      viewController.presentedViewController == nil
    }
    let breakStartPicker = try await presentDatePicker(
      for: "editShift.breakStart",
      from: viewController
    )
    #expect(breakStartPicker.minimumDate == start)
    #expect(breakStartPicker.maximumDate == end)
    viewController.dismiss(animated: false)
    try await waitUntil {
      viewController.presentedViewController == nil
    }
    let breakEndPicker = try await presentDatePicker(
      for: "editShift.breakEnd",
      from: viewController
    )
    #expect(breakEndPicker.minimumDate == start)
    #expect(breakEndPicker.maximumDate == end)
    viewController.dismiss(animated: false)
    try await waitUntil {
      viewController.presentedViewController == nil
    }
  }
  @Test("Unknown sole WorkType остаётся несохранённым, но доступен для явного recovery")
  func unknownSoleWorkTypeCanBeExplicitlyRecovered() async throws {
    let workType = try makeWorkType(
      id: UUID(
        uuid: (0x8b, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
      ),
      name: "Lectures"
    )
    let unknownWorkTypeID = UUID(
      uuid: (0x8b, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)
    )
    let shift = try Shift(
      id: shiftID,
      workTypeID: unknownWorkTypeID,
      start: start,
      end: end
    )
    let viewModel = EditShiftViewModel(
      timeZoneIdentifier: "UTC",
      workTypes: [workType],
      shift: shift,
      saveShift: { _ in .success(()) }
    )
    let viewController = EditShiftViewController(viewModel: viewModel)
    let window = makeVisibleWindow(root: viewController)
    defer {
      hide(window)
    }
    let row: UIControl = try requireView(
      "editShift.workType",
      in: viewController.view
    )
    #expect(viewModel.selectedWorkTypeID == nil)
    #expect(row.accessibilityValue == AddShiftStrings.select)
    #expect(row.isUserInteractionEnabled)
    #expect(row.accessibilityTraits.contains(.button))
    #expect(
      viewController.navigationItem.rightBarButtonItem?.isEnabled
        == false
    )
    row.sendActions(for: .touchUpInside)
    try await waitUntil {
      viewController.presentedViewController is UINavigationController
    }
    let navigation = try #require(
      viewController.presentedViewController as? UINavigationController
    )
    let picker = try #require(
      navigation.topViewController as? WorkTypeSelectionViewController
    )
    picker.loadViewIfNeeded()
    picker.tableView(
      picker.tableView,
      didSelectRowAt: IndexPath(row: 0, section: 0)
    )
    #expect(viewModel.selectedWorkTypeID == workType.id)
    #expect(row.accessibilityValue == "Lectures")
    #expect(
      viewController.navigationItem.rightBarButtonItem?.isEnabled
        == true
    )
    try await waitUntil {
      viewController.presentedViewController == nil
    }
  }
  @Test("Accessibility Dynamic Type сохраняет Edit Shift form достижимой")
  func accessibilityDynamicTypeKeepsFormReachable() throws {
    let workType = try makeWorkType(
      id: UUID(
        uuid: (0x8c, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
      ),
      name: "Lectures"
    )
    let breakStart = start.addingTimeInterval(3_600)
    let breakEnd = start.addingTimeInterval(5_400)
    let shift = try Shift(
      id: shiftID,
      workTypeID: workType.id,
      start: start,
      end: end,
      unpaidBreak: UnpaidBreak(
        start: breakStart,
        end: breakEnd
      )
    )
    let viewController = EditShiftViewController(
      viewModel: EditShiftViewModel(
        timeZoneIdentifier: "UTC",
        workTypes: [workType],
        shift: shift,
        saveShift: { _ in .success(()) }
      )
    )
    viewController.traitOverrides.preferredContentSizeCategory = .large
    let window = makeVisibleWindow(root: viewController)
    defer {
      hide(window)
    }
    let screen: UIScrollView = try requireView(
      "editShift.screen",
      in: viewController.view
    )
    #expect(screen.alwaysBounceVertical)
    let workTypeRow: UIControl = try requireView(
      "editShift.workType",
      in: viewController.view
    )
    let startRow: UIControl = try requireView(
      "editShift.start",
      in: viewController.view
    )
    let endRow: UIControl = try requireView(
      "editShift.end",
      in: viewController.view
    )
    let _: UISwitch = try requireView(
      "editShift.unpaidBreak",
      in: viewController.view
    )
    let breakStartRow: UIControl = try requireView(
      "editShift.breakStart",
      in: viewController.view
    )
    let breakEndRow: UIControl = try requireView(
      "editShift.breakEnd",
      in: viewController.view
    )
    let rows = [
      (row: workTypeRow, title: AddShiftStrings.workType),
      (row: startRow, title: AddShiftStrings.start),
      (row: endRow, title: AddShiftStrings.end),
      (row: breakStartRow, title: AddShiftStrings.breakStart),
      (row: breakEndRow, title: AddShiftStrings.breakEnd)
    ]
    func expectHorizontalRows() throws {
      for entry in rows {
        let labels = try valueRowLabels(in: entry.row, title: entry.title)
        let titleFrame = labels.title.convert(labels.title.bounds, to: entry.row)
        let valueFrame = labels.value.convert(labels.value.bounds, to: entry.row)
        #expect(titleFrame.maxX + 11 <= valueFrame.minX)
        #expect(titleFrame.minY < valueFrame.maxY)
        #expect(valueFrame.minY < titleFrame.maxY)
        #expect(labels.value.textAlignment == .right)
      }
    }
    try expectHorizontalRows()

    viewController.traitOverrides.preferredContentSizeCategory =
      .accessibilityExtraExtraExtraLarge
    window.layoutIfNeeded()
    viewController.view.layoutIfNeeded()
    for entry in rows {
      let labels = try valueRowLabels(in: entry.row, title: entry.title)
      let titleFrame = labels.title.convert(labels.title.bounds, to: entry.row)
      let valueFrame = labels.value.convert(labels.value.bounds, to: entry.row)
      let rowBounds = entry.row.bounds.insetBy(dx: -0.5, dy: -0.5)
      #expect(titleFrame.maxY <= valueFrame.minY)
      #expect(abs(valueFrame.minX - entry.row.bounds.minX) <= 0.5)
      #expect(labels.value.numberOfLines == 0)
      #expect(labels.value.textAlignment == .natural)
      #expect(rowBounds.contains(titleFrame))
      #expect(rowBounds.contains(valueFrame))
      #expect(labels.value.bounds.height + 0.5 >= labels.value.sizeThatFits(
        CGSize(width: labels.value.bounds.width, height: CGFloat.greatestFiniteMagnitude)
      ).height)
      if entry.row.isUserInteractionEnabled {
        let chevron = try #require(firstDescendant(of: UIImageView.self, in: entry.row))
        let chevronFrame = chevron.convert(chevron.bounds, to: entry.row)
        #expect(abs(chevronFrame.minX - valueFrame.maxX - 12) <= 1)
        #expect(abs(chevronFrame.midY - valueFrame.midY) <= 1)
      } else {
        let chevron = try #require(firstDescendant(of: UIImageView.self, in: entry.row))
        #expect(chevron.isHidden)
        #expect(abs(valueFrame.maxX - entry.row.bounds.maxX) <= 0.5)
      }
    }

    viewController.traitOverrides.preferredContentSizeCategory = .large
    window.layoutIfNeeded()
    viewController.view.layoutIfNeeded()
    try expectHorizontalRows()
    #expect(screen.alwaysBounceVertical)
    #expect(
      viewController.navigationItem.rightBarButtonItem?.isEnabled
        == true
    )
  }
  @Test("Failure показывает точный alert и оставляет форму доступной для retry")
  func failureAlertPreservesForm() async throws {
    let workType = try makeWorkType(
      id: UUID(
        uuid: (0x88, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
      ),
      name: "Lectures"
    )
    let shift = try Shift(
      id: shiftID,
      workTypeID: workType.id,
      start: start,
      end: end
    )

    var outcome: Result<Void, EditShiftSaveFailure> = .failure(.overlap)
    let viewModel = EditShiftViewModel(
      timeZoneIdentifier: "UTC",
      workTypes: [workType],
      shift: shift,
      saveShift: { _ in outcome }
    )
    let viewController = EditShiftViewController(viewModel: viewModel)

    let animationsWereEnabled = UIView.areAnimationsEnabled
    UIView.setAnimationsEnabled(false)

    let window = makeVisibleWindow(root: viewController)
    defer {
      UIView.setAnimationsEnabled(animationsWereEnabled)
      hide(window)
    }

    #expect(viewController.view.window != nil)

    try tapSave(on: viewController)

    let overlapAlert = try #require(
      presentedViewController(from: viewController) as? UIAlertController
    )
    #expect(overlapAlert.title == EditShiftStrings.overlapTitle)
    #expect(overlapAlert.message == EditShiftStrings.overlapMessage)

    await dismissPresentedViewController(from: viewController)

    #expect(presentedViewController(from: viewController) == nil)
    #expect(viewModel.start == shift.start)
    #expect(viewModel.end == shift.end)
    #expect(viewModel.canSave)

    outcome = .failure(.generic)

    try tapSave(on: viewController)

    let genericAlert = try #require(
      presentedViewController(from: viewController) as? UIAlertController
    )
    #expect(genericAlert.title == EditShiftStrings.genericErrorTitle)
    #expect(genericAlert.message == EditShiftStrings.genericErrorMessage)
    #expect(viewModel.start == shift.start)
    #expect(viewModel.end == shift.end)
    #expect(viewModel.canSave)

    await dismissPresentedViewController(from: viewController)
  }

  private func presentedViewController(
    from viewController: UIViewController
  ) -> UIViewController? {
    viewController.presentedViewController
      ?? viewController.navigationController?.presentedViewController
  }

  private func dismissPresentedViewController(
    from viewController: UIViewController
  ) async {
    let presenter: UIViewController?
    if viewController.presentedViewController != nil {
      presenter = viewController
    } else if viewController.navigationController?.presentedViewController != nil {
      presenter = viewController.navigationController
    } else {
      presenter = nil
    }

    guard let presenter else {
      return
    }

    await withCheckedContinuation { continuation in
      presenter.dismiss(animated: false) {
        continuation.resume()
      }
    }
  }

  private func makeVisibleWindow(
    root: UIViewController
  ) -> UIWindow {
    let navigation = UINavigationController(
      rootViewController: root
    )
    let window = UIWindow(
      frame: CGRect(
        x: 0,
        y: 0,
        width: 390,
        height: 844
      )
    )
    window.rootViewController = navigation
    navigation.loadViewIfNeeded()
    root.loadViewIfNeeded()
    window.makeKeyAndVisible()
    window.layoutIfNeeded()
    navigation.view.layoutIfNeeded()
    root.view.layoutIfNeeded()
    return window
  }
  private func hide(_ window: UIWindow) {
    window.isHidden = true
    window.rootViewController = nil
  }
  private func tapSave(
    on viewController: EditShiftViewController
  ) throws {
    guard
      let action =
        viewController.navigationItem.rightBarButtonItem?.action
    else {
      throw EditShiftViewControllerTestError.saveActionUnavailable
    }
    _ = viewController.perform(action)
  }
  private func presentDatePicker(
    for rowIdentifier: String,
    from viewController: EditShiftViewController
  ) async throws -> UIDatePicker {
    let row: UIControl = try requireView(
      rowIdentifier,
      in: viewController.view
    )
    row.sendActions(for: .touchUpInside)
    try await waitUntil {
      viewController.presentedViewController
        is UINavigationController
    }
    let navigationController = try #require(
      viewController.presentedViewController
        as? UINavigationController
    )
    let pickerViewController = try #require(
      navigationController.topViewController
        as? ShiftDateTimePickerViewController
    )
    pickerViewController.loadViewIfNeeded()
    return try #require(
      firstDescendant(
        of: UIDatePicker.self,
        in: pickerViewController.view
      )
    )
  }
  private func expectDate(
    _ date: Date,
    in row: UIControl,
    timeZoneIdentifier: String,
    locale: Locale
  ) {
    let expectedAccessibilityValue =
      AddShiftDateFormatting.accessibilityString(
        for: date,
        timeZoneIdentifier: timeZoneIdentifier,
        locale: locale
      )
    let expectedDisplayValue =
      AddShiftDateFormatting.string(
        for: date,
        timeZoneIdentifier: timeZoneIdentifier,
        locale: locale
      )
    #expect(
      row.accessibilityValue
        == expectedAccessibilityValue
    )
    #expect(
      containsLabel(
        with: expectedDisplayValue,
        in: row
      )
    )
  }
  private func containsLabel(
    with text: String?,
    in root: UIView
  ) -> Bool {
    guard let text else {
      return false
    }
    if let label = root as? UILabel,
      label.text == text
    {
      return true
    }
    return root.subviews.contains {
      containsLabel(with: text, in: $0)
    }
  }
  private func valueRowLabels(
    in row: UIControl,
    title: String
  ) throws -> (title: UILabel, value: UILabel) {
    let labels = labelDescendants(in: row)
    try #require(labels.count == 2)
    let titleLabel = try #require(labels.first { $0.text == title })
    let valueLabel = try #require(labels.first { $0 !== titleLabel })
    return (titleLabel, valueLabel)
  }
  private func labelDescendants(in root: UIView) -> [UILabel] {
    root.subviews.flatMap { subview in
      if let label = subview as? UILabel {
        return [label]
      }
      return labelDescendants(in: subview)
    }
  }
  private func firstDescendant<View: UIView>(
    of type: View.Type,
    in root: UIView
  ) -> View? {
    if let match = root as? View {
      return match
    }
    for subview in root.subviews {
      if let match = firstDescendant(
        of: type,
        in: subview
      ) {
        return match
      }
    }
    return nil
  }
  private func makeWorkType(
    id: UUID,
    name: String
  ) throws -> WorkType {
    WorkType(
      id: id,
      name: name,
      basePayBasis: .hourly,
      payRateHistory: try PayRateHistory(
        payRates: [
          try PayRate(
            id: UUID(
              uuid: (
                0x89,
                0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 1
              )
            ),
            amount: 100,
            effectiveFrom: nil
          )
        ]
      )
    )
  }
  private func requireView<View: UIView>(
    _ identifier: String,
    in root: UIView
  ) throws -> View {
    if root.accessibilityIdentifier == identifier,
      let root = root as? View
    {
      return root
    }
    for subview in root.subviews {
      if let match: View = try? requireView(
        identifier,
        in: subview
      ) {
        return match
      }
    }
    throw EditShiftViewControllerTestError.viewNotFound(
      identifier
    )
  }
  private func waitUntil(
    _ condition: @escaping @MainActor () -> Bool
  ) async throws {
    for _ in 0..<100 {
      if condition() {
        return
      }
      await Task.yield()
    }
    throw EditShiftViewControllerTestError.timedOut
  }
}
private enum EditShiftViewControllerTestError: Error {
  case saveActionUnavailable
  case viewNotFound(String)
  case timedOut
}
