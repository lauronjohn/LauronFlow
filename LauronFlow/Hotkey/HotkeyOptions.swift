import AppKit
import Carbon.HIToolbox

/// The physical modifier keys offered as push-to-talk hotkey choices. Restricted to
/// modifier-only keys (not Fn, not any regular key) because the global monitor that
/// detects this hotkey only *observes* events — it can't swallow them — so a regular
/// key would still get typed into whatever app has focus while held.
///
/// No `Int` raw value here: Carbon's `kVK_*` constants are computed `var`s, not
/// compile-time literals, so Swift won't accept them as enum raw values. `keyCode`
/// below is the runtime equivalent.
enum ModifierHotkeyOption: CaseIterable, Identifiable, Hashable {
    case rightOption, leftOption, rightCommand, leftCommand, rightControl, leftControl, rightShift, leftShift

    static let `default`: ModifierHotkeyOption = .rightOption

    init?(keyCode: Int) {
        guard let match = Self.allCases.first(where: { $0.keyCode == keyCode }) else { return nil }
        self = match
    }

    var id: Int { keyCode }

    var keyCode: Int {
        switch self {
        case .rightOption: return kVK_RightOption
        case .leftOption: return kVK_Option
        case .rightCommand: return kVK_RightCommand
        case .leftCommand: return kVK_Command
        case .rightControl: return kVK_RightControl
        case .leftControl: return kVK_Control
        case .rightShift: return kVK_RightShift
        case .leftShift: return kVK_Shift
        }
    }

    var displayName: String {
        switch self {
        case .rightOption: return "Right ⌥ Option"
        case .leftOption: return "Left ⌥ Option"
        case .rightCommand: return "Right ⌘ Command"
        case .leftCommand: return "Left ⌘ Command"
        case .rightControl: return "Right ⌃ Control"
        case .leftControl: return "Left ⌃ Control"
        case .rightShift: return "Right ⇧ Shift"
        case .leftShift: return "Left ⇧ Shift"
        }
    }

    /// The device-independent modifier bit this physical key sets in
    /// `NSEvent.modifierFlags` — shared by both keys of a pair (e.g. Left/Right
    /// Option both set `.option`), which is fine since `HotkeyManager` also gates
    /// on the exact `keyCode` to tell them apart.
    var modifierFlag: NSEvent.ModifierFlags {
        switch self {
        case .rightOption, .leftOption: return .option
        case .rightCommand, .leftCommand: return .command
        case .rightControl, .leftControl: return .control
        case .rightShift, .leftShift: return .shift
        }
    }
}

/// The letter keys offered for the undo hotkey. See `ModifierHotkeyOption`'s doc
/// comment for why this isn't a `kVK_ANSI_*`-backed `Int` raw value enum.
enum UndoHotkeyLetter: CaseIterable, Identifiable, Hashable {
    case a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z

    static let `default`: UndoHotkeyLetter = .z

    init?(keyCode: Int) {
        guard let match = Self.allCases.first(where: { $0.keyCode == keyCode }) else { return nil }
        self = match
    }

    var id: Int { keyCode }

    var keyCode: Int {
        switch self {
        case .a: return kVK_ANSI_A
        case .b: return kVK_ANSI_B
        case .c: return kVK_ANSI_C
        case .d: return kVK_ANSI_D
        case .e: return kVK_ANSI_E
        case .f: return kVK_ANSI_F
        case .g: return kVK_ANSI_G
        case .h: return kVK_ANSI_H
        case .i: return kVK_ANSI_I
        case .j: return kVK_ANSI_J
        case .k: return kVK_ANSI_K
        case .l: return kVK_ANSI_L
        case .m: return kVK_ANSI_M
        case .n: return kVK_ANSI_N
        case .o: return kVK_ANSI_O
        case .p: return kVK_ANSI_P
        case .q: return kVK_ANSI_Q
        case .r: return kVK_ANSI_R
        case .s: return kVK_ANSI_S
        case .t: return kVK_ANSI_T
        case .u: return kVK_ANSI_U
        case .v: return kVK_ANSI_V
        case .w: return kVK_ANSI_W
        case .x: return kVK_ANSI_X
        case .y: return kVK_ANSI_Y
        case .z: return kVK_ANSI_Z
        }
    }

    var displayName: String { String(describing: self).uppercased() }
}

/// The undo hotkey's modifiers, togglable independently (unlike the push-to-talk key,
/// which is a single physical key). Command is deliberately not offered: a global
/// monitor can't consume the event, and Command+letter is far more likely to already
/// be bound to something in the frontmost app, which would cause a double action.
struct UndoHotkeyModifiers: OptionSet {
    let rawValue: Int

    static let control = UndoHotkeyModifiers(rawValue: 1 << 0)
    static let option = UndoHotkeyModifiers(rawValue: 1 << 1)
    static let shift = UndoHotkeyModifiers(rawValue: 1 << 2)

    static let `default`: UndoHotkeyModifiers = [.control, .option]

    var nsEventFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if contains(.control) { flags.insert(.control) }
        if contains(.option) { flags.insert(.option) }
        if contains(.shift) { flags.insert(.shift) }
        return flags
    }
}
