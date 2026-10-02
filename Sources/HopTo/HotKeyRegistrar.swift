import Carbon
import Foundation
import HopToCore

/// Registers a system-wide hot key with Carbon. Needs no permissions, unlike event taps.
final class HotKeyRegistrar {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var onPress: (() -> Void)?
    private static let signature: OSType = 0x484F5054  // 'HOPT'

    deinit { unregister() }

    func register(_ hotKey: HotKey, onPress: @escaping () -> Void) {
        unregister()
        self.onPress = onPress

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            let me = Unmanaged<HotKeyRegistrar>.fromOpaque(userData).takeUnretainedValue()
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            if id.signature == HotKeyRegistrar.signature { me.onPress?() }
            return noErr
        }, 1, &spec, selfPtr, &handler)

        let id = EventHotKeyID(signature: Self.signature, id: 1)
        RegisterEventHotKey(hotKey.keyCode, Self.carbonModifiers(hotKey.modifiers), id,
                            GetApplicationEventTarget(), 0, &ref)
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref); self.ref = nil }
        if let handler { RemoveEventHandler(handler); self.handler = nil }
    }

    static func carbonModifiers(_ m: HotKey.Modifiers) -> UInt32 {
        var flags: UInt32 = 0
        if m.contains(.command) { flags |= UInt32(cmdKey) }
        if m.contains(.option) { flags |= UInt32(optionKey) }
        if m.contains(.control) { flags |= UInt32(controlKey) }
        if m.contains(.shift) { flags |= UInt32(shiftKey) }
        return flags
    }
}
