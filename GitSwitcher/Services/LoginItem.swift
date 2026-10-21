import Foundation
import ServiceManagement

/// «Abrir al iniciar sesión». Usa el sistema moderno de macOS (SMAppService), que
/// además hace que la app aparezca en Ajustes del Sistema › General › Ítems de
/// inicio, donde el usuario también puede quitarla.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
