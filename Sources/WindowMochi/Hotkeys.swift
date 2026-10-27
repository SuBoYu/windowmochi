import Carbon

// Register only the requested combinations; this does not capture typed text.
final class Hotkeys {
    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private let callback: (UInt32) -> Void
    private let signature: OSType = 0x57484254 // WHBT
    init(callback: @escaping (UInt32) -> Void) { self.callback = callback }
    func register() -> [String] {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event = event, let context = context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard status == noErr else { return status }
            let owner = Unmanaged<Hotkeys>.fromOpaque(context).takeUnretainedValue()
            guard id.signature == owner.signature else { return OSStatus(eventNotHandledErr) }
            owner.callback(id.id)
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { return ["⌃⌥⌘1–9 / ← / →"] }
        let keys: [Int] = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9, kVK_RightArrow, kVK_LeftArrow]
        var conflicts: [String] = []
        for (index, key) in keys.enumerated() {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: signature, id: UInt32(index + 1))
            let result = RegisterEventHotKey(UInt32(key), UInt32(controlKey | optionKey | cmdKey), id, GetApplicationEventTarget(), 0, &ref)
            if result == noErr, let ref = ref { refs.append(ref) }
            else { conflicts.append("⌃⌥⌘" + (index < 9 ? String(index + 1) : index == 9 ? "→" : "←")) }
        }
        return conflicts
    }
    deinit {
        for ref in refs { UnregisterEventHotKey(ref) }
        if let handler = handler { RemoveEventHandler(handler) }
    }
}
