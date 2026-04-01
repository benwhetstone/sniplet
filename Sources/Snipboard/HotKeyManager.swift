import Carbon

enum SnipHotKey: UInt32 {
    case selection = 1
    case currentScreen = 2
    case selectionWithMarkup = 3
    case currentScreenWithMarkup = 4
}

final class HotKeyManager {
    private var hotKeyRefs: [SnipHotKey: EventHotKeyRef] = [:]
    private let handler: (SnipHotKey) -> Void

    init(handler: @escaping (SnipHotKey) -> Void) {
        self.handler = handler
        installHandler()
    }

    func register(_ hotKey: SnipHotKey, keyCode: UInt32, modifiers: UInt32) {
        var hotKeyRef: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: OSType(0x534E4950), id: hotKey.rawValue)

        RegisterEventHotKey(
            keyCode,
            modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if let hotKeyRef {
            hotKeyRefs[hotKey] = hotKeyRef
        }
    }

    private func installHandler() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let eventRef else { return noErr }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr,
                      let userData,
                      let key = SnipHotKey(rawValue: hotKeyID.id)
                else {
                    return noErr
                }

                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handler(key)
                return noErr
            },
            1,
            &eventSpec,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            nil
        )
    }
}
