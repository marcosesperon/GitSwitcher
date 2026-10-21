import Foundation

/// Avisa cuando cambia la configuración de gh (alguien hizo `gh auth switch` o
/// `gh auth login` desde la terminal, por ejemplo).
///
/// Vigilamos dos cosas, porque cada una cubre un caso distinto:
/// - **El fichero `hosts.yml`**: gh lo reescribe en el mismo sitio al cambiar de
///   cuenta, y eso solo lo ve quien vigila el propio fichero.
/// - **La carpeta**: por si el fichero aún no existe, o alguien lo borra o lo
///   sustituye por otro. En esos casos volvemos a engancharnos al fichero nuevo.
final class HostsWatcher: @unchecked Sendable {
    private let directory: URL
    private let file: URL
    private let onChange: @Sendable () -> Void
    private let queue = DispatchQueue(label: "com.marcosesperon.GitSwitcher.HostsWatcher")
    private var directorySource: DispatchSourceFileSystemObject?
    private var fileSource: DispatchSourceFileSystemObject?
    private var pendingNotification: DispatchWorkItem?
    private var retryTimer: DispatchSourceTimer?

    init(directory: URL, onChange: @escaping @Sendable () -> Void) {
        self.directory = directory
        self.file = directory.appendingPathComponent("hosts.yml")
        self.onChange = onChange
    }

    // Cancelar es seguro desde cualquier hilo; no usamos `stop()` para no
    // bloquearnos si el último uso del objeto ocurre dentro de `queue`.
    deinit {
        directorySource?.cancel()
        fileSource?.cancel()
        retryTimer?.cancel()
    }

    func start() {
        queue.async { self.attachAll() }
    }

    func stop() {
        queue.sync {
            directorySource?.cancel()
            directorySource = nil
            fileSource?.cancel()
            fileSource = nil
            retryTimer?.cancel()
            retryTimer = nil
            pendingNotification?.cancel()
        }
    }

    // Todo lo de abajo corre en `queue`.

    private func attachAll() {
        attachDirectory()
        attachFile()
    }

    private func attachDirectory() {
        guard directorySource == nil else { return }
        guard let source = makeSource(for: directory, events: [.write, .delete, .rename]) else {
            // La carpeta aún no existe (gh recién instalado y sin sesión). Lo
            // reintentamos cada poco hasta que aparezca.
            scheduleRetry()
            return
        }
        source.setEventHandler { [weak self] in
            guard let self else { return }
            if !source.data.intersection([.delete, .rename]).isEmpty {
                // Se han llevado la carpeta entera: soltamos todo y a esperar.
                self.directorySource?.cancel()
                self.directorySource = nil
                self.fileSource?.cancel()
                self.fileSource = nil
                self.scheduleRetry()
            } else {
                // Algo ha cambiado dentro: quizá hay un hosts.yml nuevo.
                self.reattachFile()
            }
            self.notifySoon()
        }
        directorySource = source
        source.resume()
    }

    private func attachFile() {
        guard fileSource == nil else { return }
        guard let source = makeSource(for: file, events: [.write, .extend, .delete, .rename, .revoke]) else {
            // Sin fichero todavía; el vigilante de la carpeta nos avisará cuando
            // aparezca.
            return
        }
        source.setEventHandler { [weak self] in
            guard let self else { return }
            // Si lo han borrado o sustituido, el descriptor apunta al fichero
            // viejo: hay que engancharse al nuevo.
            if !source.data.intersection([.delete, .rename, .revoke]).isEmpty {
                self.reattachFile()
            }
            self.notifySoon()
        }
        fileSource = source
        source.resume()
    }

    private func reattachFile() {
        fileSource?.cancel()
        fileSource = nil
        attachFile()
    }

    /// Abre `url` solo para recibir avisos (sin bloquear el borrado) y crea el
    /// vigilante. Devuelve `nil` si la ruta no existe.
    private func makeSource(
        for url: URL,
        events: DispatchSource.FileSystemEvent
    ) -> DispatchSourceFileSystemObject? {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor, eventMask: events, queue: queue
        )
        source.setCancelHandler { close(descriptor) }
        return source
    }

    private func scheduleRetry() {
        guard retryTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 5, repeating: 5)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.attachAll()
            if self.directorySource != nil {
                self.retryTimer?.cancel()
                self.retryTimer = nil
                self.notifySoon()
            }
        }
        retryTimer = timer
        timer.resume()
    }

    /// gh suele escribir varias veces seguidas; esperamos un momento y avisamos
    /// una sola vez en lugar de refrescar por cada escritura.
    private func notifySoon() {
        pendingNotification?.cancel()
        let work = DispatchWorkItem { [onChange] in onChange() }
        pendingNotification = work
        queue.asyncAfter(deadline: .now() + 0.3, execute: work)
    }
}
