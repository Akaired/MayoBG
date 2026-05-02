import Carbon
import OSLog

@MainActor
final class HotkeyService {
    static let shared = HotkeyService()

    var onHotkey: (@MainActor () -> Void)?
    private var hotkeyRef: EventHotKeyRef?
    private var handler: EventHandlerRef?

    private static let hotkeyID = EventHotKeyID(signature: 0x4D594247, id: 1) // "MYBG"

    private init() {}

    func register() {
        let hotkeyID = Self.hotkeyID
        let keyCode = UInt32(kVK_ANSI_W)
        let modifiers = UInt32(cmdKey | shiftKey)

        let status = RegisterEventHotKey(
            keyCode, modifiers, hotkeyID,
            GetApplicationEventTarget(), 0,
            &hotkeyRef
        )

        guard status == noErr else {
            os_log(.error, "HotkeyService: RegisterEventHotKey failed with status \(status)")
            return
        }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                let service = Unmanaged<HotkeyService>.fromOpaque(userData!).takeUnretainedValue()
                Task { @MainActor in
                    service.onHotkey?()
                }
                return noErr
            },
            1, &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )

        os_log(.info, "HotkeyService: global Cmd+Shift+W registered")
    }

    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        if let handler {
            RemoveEventHandler(handler)
            self.handler = nil
        }
    }
}
