# Caffeine

App nativa de macOS que mantiene tu Mac despierta desde la barra de menús. Sin ventanas, sin Dock, sin dependencias: un solo archivo Swift y un script de build.

Mientras está activa, la pantalla no se apaga por inactividad y, por lo tanto, el sistema tampoco entra en reposo por inactividad.

## Características

- Vive solo en la barra de menús (`LSUIElement`), sin icono en el Dock.
- Activar y desactivar con un clic; el icono cambia entre taza vacía y taza llena.
- Ocultar el icono de la barra sin cerrar la app; se recupera con `⌥⌘C` o reabriendo la app.
- Libera la reserva de energía al desactivar o al salir.
- Sin red, sin permisos especiales, sin estado persistente.
- Build reproducible con `build_app.sh` (app, `.dmg` y `.zip`).

## Requisitos

- macOS 11 Big Sur o superior.
- Para compilar: Command Line Tools (`xcode-select --install`), que incluyen `swiftc`.
- Arquitectura: el build por defecto genera **Apple Silicon (arm64)**. Ver [Arquitecturas](#arquitecturas) para Intel y binario universal.

## Instalación

### Opción A: con el DMG

1. Abre `dist/Caffeine-1.0.0.dmg`.
2. Arrastra **Caffeine** a la carpeta **Applications**.
3. En el primer arranque, macOS bloqueará la app porque está firmada ad-hoc (no notarizada). Autorízala una vez:

   ```bash
   xattr -dr com.apple.quarantine /Applications/Caffeine.app
   open /Applications/Caffeine.app
   ```

   También puedes hacerlo desde la interfaz: **Ajustes del Sistema → Privacidad y seguridad → “Abrir igualmente”**. En macOS 15 y posteriores, el viejo atajo de clic derecho → Abrir ya no evita Gatekeeper.

4. El icono de la taza aparece en la barra de menús. No hay ventana ni icono en el Dock: es normal.

### Opción B: compilar desde el código

```bash
./build_app.sh
open Caffeine.app
```

El script deja `Caffeine.app` en la raíz del proyecto y los artefactos en `dist/`.

## Uso

Haz clic en el icono de la barra de menús:

| Acción | Efecto |
| --- | --- |
| **Activar** | Crea una reserva de energía; la pantalla no se apaga por inactividad. |
| **Desactivar** | Libera la reserva y vuelve al comportamiento normal de macOS. |
| **Salir** | Libera la reserva (si estaba activa) y cierra la app. Atajo: `⌘Q`. |
| **Ocultar icono** | Quita el icono de la barra de menús; la app sigue corriendo y la reserva sigue activa. Vuelve con `⌥⌘C`. |

La app arranca siempre desactivada; no recuerda el estado entre ejecuciones.

### Qué sí y qué no evita

- **Sí** evita el reposo por inactividad del usuario mientras está activa.
- **No** evita el reposo al cerrar la tapa, por batería baja, por el menú Apple ni por otros motivos del sistema.
- La reserva se libera automáticamente si el proceso termina, incluso si la app se cierra de forma inesperada.

### Ocultar el icono de la barra

El menú incluye **Ocultar icono (⌥⌘C)**. Al ocultarlo:

- La app **no se cierra**: sigue corriendo en segundo plano.
- Si estaba activa, la reserva de energía **sigue vigente**: la Mac sigue despierta.
- Para recuperarlo, pulsa `⌥⌘C` desde cualquier app o vuelve a abrir `Caffeine.app` desde Finder/Spotlight. Ambos caminos muestran el icono otra vez.

El atajo es global y no requiere permisos de Accesibilidad. El estado oculto no se guarda: cada vez que abres la app, el icono aparece visible.

## Compilar

```bash
./build_app.sh
```

Salida:

```
Caffeine.app                     # app lista para ejecutar
dist/Caffeine-1.0.0.dmg          # instalador drag & drop
dist/Caffeine-1.0.0.zip          # app comprimida
```

### Variables de entorno

| Variable | Por defecto | Descripción |
| --- | --- | --- |
| `VERSION` | `1.0.0` | `CFBundleShortVersionString` y nombre de los artefactos. |
| `BUILD_NUMBER` | `1` | `CFBundleVersion`. |
| `BUNDLE_ID` | `com.local.caffeine` | Identificador del bundle. Cámbialo si vas a distribuir la app. |
| `MIN_MACOS` | `11.0` | Versión mínima de macOS del binario y del `Info.plist`. |
| `ARCHS` | `arm64 x86_64` | Arquitecturas a intentar. Las que el toolchain no soporte se omiten con un aviso. |
| `SIGN_IDENTITY` | vacío | Identidad de firma (`Developer ID Application: ...`). Si está vacío, firma ad-hoc. |
| `NOTARY_PROFILE` | vacío | Perfil de `notarytool`. Activa la notarización (requiere `SIGN_IDENTITY`). |

Ejemplo:

```bash
VERSION=1.0.1 BUILD_NUMBER=2 ./build_app.sh
```

### Arquitecturas

El script intenta compilar cada arquitectura de `ARCHS` y arma el binario con `lipo`.

- **Apple Silicon:** funciona con Command Line Tools.
- **Intel:** compila desde el código en el propio Mac Intel; el script detecta la arquitectura al fallar la cruzada y genera un binario válido para esa máquina.
- **Universal (arm64 + x86_64):** requiere el toolchain completo de Xcode. Las Command Line Tools incluyen la SDK, pero no las librerías de compatibilidad de Swift para la arquitectura cruzada, así que la compilación x86_64 falla al enlazar. Con Xcode instalado:

  ```bash
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  ./build_app.sh
  lipo -info Caffeine.app/Contents/MacOS/Caffeine   # arm64 x86_64
  ```

## Distribuir sin advertencias de Gatekeeper

Para que la app se abra con doble clic en cualquier Mac, sin `xattr` ni “Abrir igualmente”, necesita firma **Developer ID** y notarización. Requiere una cuenta de Apple Developer Program y un certificado **Developer ID Application** en el llavero.

1. Guarda las credenciales de notarización una sola vez:

   ```bash
   xcrun notarytool store-credentials "caffeine-notary" \
     --apple-id "tu@email.com" \
     --team-id "TEAMID" \
     --password "app-specific-password"
   ```

2. Compila firmando y notarizando:

   ```bash
   SIGN_IDENTITY="Developer ID Application: Tu Nombre (TEAMID)" \
   NOTARY_PROFILE="caffeine-notary" \
   ./build_app.sh
   ```

El script firma con hardened runtime y timestamp, notariza la app, la grapa (`stapler`), y repite el proceso con el DMG. Sin esas variables, la app queda con firma ad-hoc y Gatekeeper pedirá confirmación en cada Mac nueva.

## Cómo funciona

- `AppDelegate` crea un `NSStatusItem` y su menú (`Activar`/`Desactivar`, `Ocultar icono`, `Salir`).
- Al activar, llama a `IOPMAssertionCreateWithName` con `kIOPMAssertionTypeNoDisplaySleep`: mientras la pantalla no puede apagarse por inactividad, el sistema tampoco entra en reposo por esa causa.
- Al desactivar o salir, llama a `IOPMAssertionRelease`.
- `applicationDidFinishLaunching` usa `setActivationPolicy(.accessory)` y el `Info.plist` marca `LSUIElement`, por eso no hay Dock ni ventana.
- El icono se dibuja con SF Symbols (`cup.and.saucer` / `cup.and.saucer.fill`) como plantilla, así se adapta a modo claro y oscuro.
- `Ocultar icono` pone `statusItem.isVisible` en `false` sin cerrar la app; `⌥⌘C` alterna la visibilidad desde cualquier app con `RegisterEventHotKey` (Carbon), sin permisos de Accesibilidad.
- `applicationShouldHandleReopen` vuelve a mostrar el icono si abres la app otra vez desde Finder o Spotlight.

No usa sandbox, entitlements ni red. La reserva de energía es del sistema (IOKit) y desaparece con el proceso.

## Estructura del proyecto

```
caffeine/
├── Caffeine.swift        # código de la app (único archivo)
├── build_app.sh          # build, firma y artefactos
├── README.md
├── Caffeine.app          # generado por el script
└── dist/                 # generado por el script (.dmg y .zip)
```

## Problemas comunes

| Síntoma | Causa y solución |
| --- | --- |
| “Caffeine está dañada y no se puede abrir” | Cuarentena de Gatekeeper sobre una app ad-hoc. `xattr -dr com.apple.quarantine /Applications/Caffeine.app`. |
| “No se puede verificar al desarrollador” | Ajustes del Sistema → Privacidad y seguridad → “Abrir igualmente”. |
| El icono no aparece al abrir la app | La barra de menús está llena o una app como Bartender/Ice lo oculta; comprueba que el proceso siga vivo con `pgrep -fl Caffeine`. |
| Oculté el icono y no sé cómo recuperarlo | Pulsa `⌥⌘C` o vuelve a abrir `Caffeine.app`; el icono reaparece. |
| `swiftc: command not found` | Instala las herramientas: `xcode-select --install`. |
| `ld: symbol(s) not found for architecture x86_64` | Normal con solo Command Line Tools. Usa el Mac de esa arquitectura o instala Xcode completo para el binario universal. |
| La app no evita el reposo | Comprueba que el icono esté en modo lleno (`cup.and.saucer.fill`) y que el sistema no esté durmiendo por tapa cerrada o batería baja. |

## Notas

- El bundle ID por defecto es `com.local.caffeine`; usa uno propio antes de distribuir.
- No incluye icono de app para Finder; el icono de la barra de menús es un SF Symbol del sistema.
- Este proyecto no tiene relación con otras apps llamadas Caffeine.
