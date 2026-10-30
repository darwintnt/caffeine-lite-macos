import Cocoa
import IOKit.pwr_mgt
import Carbon.HIToolbox

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var assertionID: IOPMAssertionID = 0
    var isActive = false
    var hotKeyRef: EventHotKeyRef?
    var hotKeyHandlerRef: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Crear el ícono en la barra de menú
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon()

        // Crear el menú
        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: "Activar",
            action: #selector(toggleCaffeine),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.tag = 1
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let hideItem = NSMenuItem(
            title: "Ocultar icono  (⌥⌘C)",
            action: #selector(hideIcon),
            keyEquivalent: ""
        )
        hideItem.target = self
        menu.addItem(hideItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Salir",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        registerHotKey()
    }

    func updateIcon() {
        let symbolName = isActive ? "cup.and.saucer.fill" : "cup.and.saucer"
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Caffeine")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    // MARK: - Activar / desactivar

    @objc func toggleCaffeine() {
        if isActive {
            // Desactivar: liberar la reserva de energía
            IOPMAssertionRelease(assertionID)
            isActive = false
        } else {
            // Activar: crear una reserva que evita que la pantalla/sistema duerma
            let reason = "Caffeine app activa" as CFString
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &assertionID
            )
            isActive = (result == kIOReturnSuccess)
        }

        // Actualizar el texto del menú y el ícono
        if let toggleItem = statusItem.menu?.item(withTag: 1) {
            toggleItem.title = isActive ? "Desactivar" : "Activar"
        }
        updateIcon()
    }

    // MARK: - Ocultar / mostrar el icono

    @objc func hideIcon() {
        statusItem.isVisible = false
    }

    func showIcon() {
        statusItem.isVisible = true
    }

    func toggleIconVisibility() {
        if statusItem.isVisible {
            hideIcon()
        } else {
            showIcon()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showIcon()
        return true
    }

    // MARK: - Atajo global ⌥⌘C

    func registerHotKey() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, event, userData in
            guard let event = event, let userData = userData else { return noErr }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if status == noErr && hotKeyID.signature == OSType(0x43414646) {
                DispatchQueue.main.async {
                    delegate.toggleIconVisibility()
                }
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &hotKeyHandlerRef
        )

        var hotKeyID = EventHotKeyID(signature: OSType(0x43414646), id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_C),
            UInt32(cmdKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    // MARK: - Salir

    @objc func quitApp() {
        if isActive {
            IOPMAssertionRelease(assertionID)
        }
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        NSApplication.shared.terminate(self)
    }
}

// MARK: - Punto de entrada

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // No mostrar en el Dock, solo en la barra de menú
app.run()
