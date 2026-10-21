# Decisiones

## 2026-10-21 — App de barra de menú para cambiar de cuenta de GitHub

### 1. La petición tal como se ha entendido

**GitSwitcher**: app nativa de macOS (14 Sonoma o posterior) que vive solo en la
barra de menú y sirve de interfaz gráfica para `gh auth switch`. Proyecto público
en `marcosesperon/GitSwitcher` (MIT), bundle ID `com.marcosesperon.GitSwitcher`.

Comportamiento:

- **Origen de las cuentas:** `gh auth status --json hosts`. La app no guarda ni
  maneja tokens; todo lo que sabe de las cuentas sale de `gh`.
- **Barra de menú:** icono + alias de la cuenta activa de `github.com` (alias
  configurable por cuenta; si no hay, el login). Opción en ajustes de «solo icono».
- **Menú:** lista de cuentas de `github.com` con la activa marcada; al pulsar otra
  se ejecuta `gh auth switch --hostname github.com --user <login>`. Además:
  «Añadir cuenta…» (abre Terminal con `gh auth login`), «Ajustes…» y «Salir».
- **Sin `gh` o sin sesión:** el menú lo indica y explica cómo instalarlo
  (`brew install gh`) o iniciar sesión.
- **Cambios externos:** se detectan vigilando `hosts.yml` de `gh` y refrescando al
  abrir el menú.
- **Ajustes:**
  - Alias por cuenta.
  - «Solo icono» en la barra.
  - Abrir al iniciar sesión (desactivado por defecto).
  - «Cambiar también el autor de git» (desactivado por defecto). Si se activa, al
    cambiar de cuenta se fijan `user.name` / `user.email` globales. Los valores de
    cada cuenta se autorrellenan desde GitHub (`gh api user`, con el correo noreply
    si el real no es público) y se pueden editar.
- **Idiomas:** inglés (base) y español, según el idioma del sistema.
- **Alcance de hosts:** solo `github.com` en la interfaz, pero el modelo guarda el
  host de cada cuenta para poder añadir GitHub Enterprise más adelante.
- **Distribución:** sin firmar. Un script local (`scripts/release.sh`) compila,
  empaqueta el `.zip`, crea la release con `gh release create` y actualiza el
  cask en `marcosesperon/homebrew-tap`. Instalación:
  `brew install --cask marcosesperon/tap/gitswitcher`.
- **Documentación:** README en inglés para el público; `docs/documentacion.md` en
  español según las normas del proyecto.
- **Limpieza:** al terminar, y con visto bueno, se borra la copia local del
  proyecto de referencia.

Fuera de alcance (por ahora): notificaciones al cambiar, atajo de teclado global,
GitHub Enterprise en la interfaz, firma/notarización, CI de releases.

**Confirmación:** confirmado por el autor el 2026-10-21. Añade una condición:
que ni la app, ni el código, ni la documentación hagan referencia a la app
usada como punto de partida.

Punto de partida: hoy se cambia de cuenta con dos scripts que ejecutan
`gh auth switch --user <cuenta>`. Se quiere una app nativa de macOS en la barra de
menú que muestre la cuenta activa y permita cambiar a las demás. Se aporta como
referencia un proyecto de terceros para analizarlo y decidir cambios o mejoras.

### 2. Preguntas y respuestas

**P1.** ¿Se parte de cero con una app mínima basada solo en `gh`, o se adapta y
recorta el proyecto de referencia?
**R1.** Desde cero, con la idea mínima basada en `gh`.

**P2.** Al cambiar de cuenta, ¿se cambian también `user.name` / `user.email` de
la config global de git, o solo `gh auth switch`?
**R2.** Configurable en los ajustes de la app. Por defecto, solo
`gh auth switch` (modo a); quien quiera puede activar que también se cambie el
autor global de git (modo b).

**P3.** En el modo b, ¿de dónde salen el nombre y el correo de cada cuenta: a mano,
de GitHub (`gh api user`) o ambas?
**R3.** Ambas: se rellenan con lo que devuelva GitHub y se pueden editar a mano.

**P4.** ¿Quién va a usar la app: solo el autor, compañeros de EDISA o público
general en GitHub?
**R4.** Proyecto público en GitHub.

**P5.** ¿Idioma de la interfaz: solo inglés, o inglés y español?
**R5.** Inglés y español (String Catalog, según el idioma del sistema).

**P6.** ¿Distribución: sin firmar (zip en Releases), firmada y notarizada, o sin
firmar más Homebrew?
**R6.** Sin firmar con `.zip` en GitHub Releases, y además instalación por
Homebrew.

**P7.** ¿Versión mínima de macOS: 13, 14 o 15+?
**R7.** macOS 14 Sonoma.

**P8.** ¿Qué se ve en la barra de menú: solo icono, icono + login, o icono + alias?
**R8.** Icono + alias corto configurable por cuenta (si no hay alias, el login),
con opción en ajustes de mostrar solo el icono.

**P9.** ¿Cómo detecta la app cambios hechos fuera (terminal, `gh auth login`)?
**R9.** Ambas: vigilando el fichero de configuración de `gh` y refrescando
también al abrir el menú.

**P10.** ¿Se soportan servidores GitHub Enterprise además de `github.com`?
**R10.** Solo `github.com` por ahora, pero con el modelo preparado para varios
servidores.

**P11.** ¿Qué extras se incluyen? (abrir al iniciar sesión, notificación al cambiar,
«Añadir cuenta…», atajo global, aviso si falta `gh`)
**R11.** Los recomendados: abrir al iniciar sesión, «Añadir cuenta…» y aviso si
falta `gh` o no hay sesión.

**P12.** ¿Nombre `GitSwitcher`, bundle ID `com.marcosesperon.GitSwitcher` y tap
`marcosesperon/homebrew-tap`?
**R12.** Sí, valen.

**P13.** ¿Qué se hace con la copia local del proyecto de referencia al terminar:
borrarla o ignorarla en git?
**R13.** Borrarla, una vez la app nueva funcione y con visto bueno previo.

**P14.** ¿Releases a mano (script local), automáticas (GitHub Actions al etiquetar)
o ambas?
**R14.** A mano, con un script local.

### 3. Fuentes analizadas

- Proyecto de terceros usado como referencia: app SwiftUI de barra de menú
  (~5.400 líneas), macOS 13+.
- `gh` 2.102.0 instalado en `/opt/homebrew/bin/gh`, con las dos cuentas ya
  autenticadas en el llavero (`gh auth status --json hosts` funciona).
- Config global de git: `gh auth git-credential` ya es el credential helper de
  `github.com`, así que `gh auth switch` por sí solo cambia también las
  credenciales que usa `git push/pull`.

### 4. Decisiones

- **App nueva desde cero, apoyada solo en `gh`.** Las cuentas se leen de
  `gh auth status --json hosts` y el cambio se hace con `gh auth switch`. Por qué:
  `gh` ya guarda los tokens en el llavero y ya es el credential helper de git, así
  que no hace falta gestionar tokens propios.
- **Cambio del autor de git opcional y desactivado por defecto.** Por defecto la
  app solo hace `gh auth switch`, igual que los scripts actuales. En ajustes se
  puede activar que también fije `user.name` / `user.email` globales según la
  cuenta. Por qué: tocar la config global afecta a todos los repos, y quien ya
  usa `includeIf` o config por repo no lo quiere; pero hay quien sí lo prefiere.
- **Nombre/correo por cuenta: autorrelleno desde GitHub + edición manual.** Se
  proponen con `gh api user` (si el correo no es público, se usa el noreply
  `ID+login@users.noreply.github.com`) y el usuario puede sobrescribirlos. Por qué:
  cero trabajo si vale lo de GitHub, control total si no.
- **Proyecto público, interfaz en inglés y español.** Inglés como idioma base y
  español vía String Catalog. Por qué: público en GitHub pide inglés; el español
  cuesta poco con tan pocos textos y deja la puerta abierta a más idiomas.
- **Distribución sin firmar: `.zip` en Releases + cask de Homebrew en un tap
  propio** (`homebrew-tap` del autor). Por qué: no exige cuenta de Apple Developer.
  El repositorio oficial `homebrew/cask` exige apps firmadas y notarizadas, así que
  un cask sin firmar solo puede vivir en un tap propio. El cask puede quitar la
  cuarentena al instalar para evitar el aviso de Gatekeeper.
- **macOS 14 Sonoma como mínimo.** Por qué: permite `@Observable` sin rodeos, y cubre a casi todos los usuarios de `gh`.
- **Etiqueta de la barra: icono + alias por cuenta**, con el login como valor por
  defecto y opción de «solo icono» en ajustes. Por qué: se ve la cuenta activa de
  un vistazo sin ocupar demasiado.
- **Sincronización con cambios externos: vigilar `hosts.yml` + refresco al abrir
  el menú.** Ruta: `$GH_CONFIG_DIR/hosts.yml` o, si no existe la variable,
  `~/.config/gh/hosts.yml`. Por qué: la barra se mantiene al día sola y el refresco
  al abrir cubre casos que el vigilante no vea.
- **Solo `github.com` en la interfaz, modelo con `host` en cada cuenta.** Se parsea
  el JSON completo de `gh auth status` (todos los hosts) y se filtra a
  `github.com` al pintar. Por qué: menú simple hoy, y soportar Enterprise mañana es
  quitar el filtro y agrupar.
- **Extras incluidos:** abrir al iniciar sesión (`SMAppService`, desactivado por
  defecto); «Añadir cuenta…» que abre Terminal con `gh auth login` (la app nunca
  toca tokens); aviso con instrucciones si `gh` no está instalado o no hay sesión.
- **Identidad:** app `GitSwitcher`, bundle ID `com.marcosesperon.GitSwitcher`,
  repo `marcosesperon/GitSwitcher` (MIT), tap `marcosesperon/homebrew-tap`.
- **La copia local del proyecto de referencia se borra al final** (con visto
  bueno). Por qué: el análisis ya queda aquí y no conviene mezclar código de otro
  autor en un repo público. Por petición del autor, ni la app ni su documentación
  lo mencionan.
- **Plan aprobado el 2026-10-21** (respuesta «dale»). Decisiones técnicas del plan:
  - **Swift 6, sin dependencias, proyecto con XcodeGen** (`project.yml` versionado,
    `.xcodeproj` ignorado). Por qué: evita conflictos en el `.pbxproj` y el
    proyecto se describe en un fichero legible.
  - **Menú con AppKit (`NSStatusItem` + `NSMenu`), ajustes en SwiftUI** dentro de
    una ventana propia. Por qué: `NSMenuDelegate` avisa de forma fiable cada vez
    que se abre el menú (necesario para el refresco al abrir), cosa que
    `MenuBarExtra` no garantiza; y la ventana propia evita depender del selector
    privado para abrir `Settings` desde AppKit.
  - **Autorrelleno sin cambiar la cuenta activa:** `gh auth token --user X` y el
    token se pasa como `GH_TOKEN` solo a la llamada `gh api user`; nunca se guarda.
  - **`release.sh` publica siempre con la cuenta dueña del repo** vía `GH_TOKEN`,
    sea cual sea la activa, y pide confirmación antes de publicar.
  - **Comentarios del código en español coloquial**, según las normas del autor.
    Se preguntó si pasarlos a inglés por ser proyecto público; la respuesta «dale»
    no lo concreta, así que se sigue la norma y queda en pendientes.
- **Releases a mano con un script local.** Por qué: preferencia del autor; evita
  gestionar secrets y runners de macOS en GitHub Actions.

- **Repo asociado a la cuenta personal** (2026-10-21, tras la prueba del autor):
  autor local `Marcos Esperón <marcosesperon@gmail.com>` (git config del repo, no
  global) y `github.account = marcosesperon`. Hooks locales `pre-commit` y
  `pre-push` (en `.git/hooks`, no versionados) que bloquean si la cuenta activa
  de gh no es esa. Por qué en `.git/hooks` y no versionados: es una regla del
  equipo del autor, no del proyecto; a un colaborador externo le bloquearía.
- **Primer commit rehecho antes del primer push** con el autor personal y sin la
  regla de `.gitignore` de la copia de referencia, para que el historial público
  no la mencione.

### 5. Alternativas descartadas

- **Releases automáticas con GitHub Actions** (con versión calculada a partir de
  los commits). Descartado por preferencia de hacerlo a mano; el script
  local podría reutilizarse en CI si se quiere más adelante.
- **Mantener la copia de referencia ignorada en git.** Descartado: no aporta nada
  que no esté ya en este documento.

- **`MenuBarExtra` de SwiftUI para el menú.** Descartado: no da un aviso fiable de
  apertura del menú para refrescar.
- **Notificación del sistema al cambiar de cuenta y atajo de teclado global.**
  Descartados por ahora: no son imprescindibles; la etiqueta de la barra ya
  muestra el cambio, y el atajo añade dependencias/permisos. Se pueden añadir más
  adelante.

- **Adaptar el proyecto de referencia.** Descartado porque duplica lo que ya
  hace `gh` (alta manual de PAT, sobrescritura de la entrada `osxkeychain` de
  `github.com`), guarda el PAT en claro en `UserDefaults` pese a decir que va al
  llavero, y trae mucha interfaz que no se necesita (ventana principal,
  bienvenida, efectos visuales, Dock dinámico, pipeline de releases). Recortarlo
  costaría más que escribir lo mínimo.

### 6. Pendiente de comprobar

Resuelto durante el desarrollo:

- ~~`gh api user` con otra cuenta sin cambiar la activa~~ → comprobado: funciona
  con `gh auth token --user X` + `GH_TOKEN`. Si el correo es privado o no hay
  nombre, gh devuelve `null` y se usan el noreply y el login.
- ~~Vigilante y escrituras atómicas~~ → en la primera versión se vigilaba solo la
  carpeta, suponiendo que gh sustituía el fichero. **Error detectado en la prueba
  del autor:** la barra no se actualizaba al cambiar de cuenta desde la terminal.
  Causa: gh 2.102 reescribe `hosts.yml` en su sitio (mismo inodo, la fecha de la
  carpeta no cambia), así que la carpeta no avisa. Ahora se vigilan el fichero
  (escritura) y la carpeta (creación/sustitución, para re-engancharse), con tests
  para los tres casos. Además, un aviso que llegue durante un refresco ya no se
  pierde: se repite el refresco al terminar.
- ~~`PATH`/`GH_CONFIG_DIR` en apps abiertas desde Finder~~ → `GhLocator` pregunta
  al shell de login interactivo (con 5 s de margen) y, si falla, mira las rutas
  habituales.
- ~~git en `release.sh` con la cuenta dueña~~ → comprobado que
  `gh auth git-credential` respeta `GH_TOKEN`, así que el `push` al tap usa esa
  cuenta aunque la activa sea otra.

Sigue abierto:

- Revisar la política vigente de Homebrew sobre casks sin firmar en taps propios.
  El cask quita la cuarentena en `postflight`; confirmar en la primera release
  real que `brew install` lo acepta sin avisos.
- En macOS 15+ el clic derecho → Abrir ya no salta Gatekeeper con apps sin
  firmar; el README indica «Abrir igualmente» en Privacidad y seguridad o `xattr`.
- Prueba manual de la interfaz (menú, cambio de cuenta, ajustes, idioma español)
  por parte del autor: en la barra del autor el icono queda oculto tras el gestor
  de iconos y no se pudo verificar visualmente de forma automática.
- Confirmar con el autor si los comentarios del código van en español (norma) o
  en inglés (proyecto público).
- El repositorio `marcosesperon/homebrew-tap` no existe todavía; `release.sh`
  ofrece crearlo en la primera publicación.

## 2026-10-21 — Guía de instalación y configuración en los ajustes

### 1. La petición tal como se ha entendido

Los ajustes pasan a tener tres pestañas:

- **General:** abrir al iniciar sesión y «solo icono en la barra».
- **Cuentas:** alias por cuenta y el bloque de autor de git (lo que hoy hay).
- **Guía:** pasos numerados, cada uno con su estado real comprobado en vivo
  (✓ hecho / ✗ falta) y una explicación corta:
  1. **Instalar GitHub CLI.** ✓ si la app encuentra gh (muestra versión y ruta).
     Comando `brew install gh` con «Copiar» y «Abrir en Terminal», y enlace a
     cli.github.com para otras formas de instalarlo.
  2. **Iniciar sesión con cada cuenta.** ✓ si hay al menos una cuenta en
     github.com (muestra cuáles). Comando `gh auth login`, repetir por cada cuenta.
  3. **Que git use la cuenta activa.** ✓ si gh es el credential helper de git
     para github.com. Comando `gh auth setup-git`. Se explica que sin esto
     `git push` no sigue a la cuenta elegida.
  4. **(Opcional) Autor de los commits.** Sin comprobación: explica la opción de
     la pestaña Cuentas y la alternativa `includeIf`.

  Las comprobaciones se repiten al abrir la pestaña y con un botón «Comprobar de
  nuevo». Pasos con comando: «Copiar» y «Abrir en Terminal» (se ejecuta al
  momento, a la vista).
- **Menú:** si falta gh o no hay ninguna cuenta, aparece «Guía de configuración…»
  y abre los ajustes en la pestaña Guía (sustituye a «Cómo instalar gh…»). El paso
  3 no dispara este aviso: solo se ve dentro de la guía.
- Textos en inglés y español, como el resto de la app.

**Confirmación:** confirmado por el autor el 2026-10-21.

Punto de partida: añadir en los ajustes de la app una sección de guía que explique
los requisitos de instalación y los pasos para que las cuentas aparezcan en la app.

### 2. Preguntas y respuestas

**P1.** ¿Dónde va la guía: sección al final del formulario, ajustes en pestañas
(General / Cuentas / Guía) o ventana aparte?
**R1.** Ajustes en pestañas: «General», «Cuentas» y «Guía».

**P2.** ¿Guía solo de texto o con comprobaciones en vivo del estado del equipo?
**R2.** Con comprobaciones en vivo (✓/✗ por paso): gh instalado (y versión),
alguna cuenta con sesión, gh como credential helper de git.

**P3.** ¿Los pasos solo explican, permiten copiar el comando, o además lo abren en
Terminal?
**R3.** Explican, permiten copiar y tienen «Abrir en Terminal»; para instalar gh,
además, enlace a su web.

**P4.** ¿La guía se abre sola en algún momento?
**R4.** Cuando falta algo: si gh no está o no hay cuentas, el menú ofrece «Guía de
configuración…», que abre los ajustes en la pestaña Guía (sustituye a «Cómo
instalar gh…»).

### 3. Fuentes analizadas

- `GitSwitcher/UI/SettingsView.swift` (commit `8eca1f6`): hoy los ajustes son un
  único formulario con tres secciones (General, Nombre en la barra, Autor de git).

### 4. Decisiones

- **Ajustes en pestañas: General, Cuentas y Guía.** Por qué: es el patrón estándar
  de macOS, la guía tiene espacio propio y la ventana no crece sin límite.
- **Guía con comprobaciones en vivo.** Por qué: quien la lee ve al momento qué le
  falta en su equipo, en vez de seguir pasos que quizá ya tiene hechos.
- **Cada comando con «Copiar» y «Abrir en Terminal».** Se reutiliza el mecanismo
  del `.command` temporal de «Añadir cuenta…»: el comando se ejecuta a la vista en
  Terminal, lanzado por el usuario. Para instalar gh, enlace a cli.github.com
  por si no se usa Homebrew.
- **La guía se ofrece desde el menú solo cuando falta algo imprescindible** (gh o
  cuentas). Por qué: quien ya lo tiene todo no ve nada nuevo; quien no, la
  encuentra donde la necesita.

- **Plan aprobado el 2026-10-21** (respuesta «dale»). Decisiones técnicas:
  - `TerminalLauncher` extraído de `GhClient` para reutilizar el `.command`.
  - `SetupChecker` separado y sin efectos; el análisis de salidas (versión de gh,
    helpers de git) en funciones puras con tests.
  - La pestaña activa vive en `AccountsStore.settingsTab` para que el menú abra
    los ajustes en la Guía.
  - Mejora surgida al implementar: si gh no estaba al arrancar, cada refresco lo
    vuelve a buscar, para que la guía y el menú se enteren de que se ha instalado.
- **Comprobación visual** con un test temporal que dibuja los ajustes en una
  ventana y guarda la imagen (inglés y español); se borró tras revisarlo.

### 5. Alternativas descartadas

- **Abrir la guía en el primer arranque.** Molesta a quien ya lo tiene todo listo.
- **Guía solo de texto.** Igual para todos; no dice qué falta en cada equipo.
- **Guía como sección al final del formulario único.** Alarga la ventana y la guía
  queda escondida abajo.
- **Ventana aparte para la guía.** Una ventana más que gestionar sin ganar nada
  frente a una pestaña.

### 6. Pendiente de comprobar

- Prueba del autor: botones «Abrir en Terminal» de cada paso y que la entrada
  «Guía de configuración…» del menú abre la pestaña correcta (en este Mac no se
  ve, porque gh y las cuentas ya están; se puede probar con `gh auth logout` de
  todas las cuentas, o en otro Mac).
- Aspecto de los pasos en estado ✗ (pendiente): no se ha visto en este Mac
  porque los tres pasos están hechos.

## 2026-10-21 — «Añadir cuenta» pasa del menú a los ajustes

### 1. La petición tal como se ha entendido

- **Menú de la barra:** desaparece «Añadir cuenta…». Se mantienen la lista de
  cuentas, «Ajustes…», «Salir» y, si falta gh o no hay cuentas, «Guía de
  configuración…».
- **Ajustes › Cuentas:** en la sección «Nombre en la barra», debajo de la lista de
  cuentas, un botón «Añadir cuenta…» que abre Terminal con `gh auth login` (como
  hacía el menú), con la nota «La cuenta nueva aparecerá aquí al terminar». La
  lista se actualiza sola gracias al vigilante de `hosts.yml`.
- **Guía:** el paso 2 conserva su propio «Abrir en Terminal» con `gh auth login`.
- Textos en inglés y español; README y documentación actualizados.

**Confirmación:** confirmado por el autor el 2026-10-21.

Punto de partida: quitar «Añadir cuenta…» del menú de la barra y poner un botón
para añadir cuenta en la pestaña Cuentas de los ajustes.

### 2. Preguntas y respuestas

**P1.** ¿Dónde va el botón: debajo de la lista de cuentas (sección «Nombre en la
barra») o en una sección propia nueva con la lista?
**R1.** Debajo de la lista de cuentas.

### 3. Fuentes analizadas

- `GitSwitcher/UI/StatusMenuController.swift` y `GitSwitcher/UI/SettingsView.swift`
  (cambios sin commitear sobre `8eca1f6`, con la pestaña Guía ya hecha).

### 4. Decisiones

- **Botón «Añadir cuenta…» debajo de la lista de cuentas** en Ajustes › Cuentas.
  Por qué: cambio mínimo y el botón queda junto a lo que afecta.
- **Plan aprobado el 2026-10-21.** Se quitó la entrada y su acción del menú; el
  botón se desactiva si no hay gh. De paso se corrigió en `documentacion.md` una
  línea que seguía atribuyendo el `.command` a `GhClient` (ahora es
  `TerminalLauncher`). Revisión visual con el test temporal de capturas (borrado).

### 5. Alternativas descartadas

- **Sección propia «Cuentas con sesión en gh» con lista y botón.** Reorganiza más
  la pestaña sin aportar nada para este cambio.

### 6. Pendiente de comprobar

- Prueba del autor: el botón abre Terminal con `gh auth login` y, al terminar,
  la cuenta nueva aparece en la lista sin reabrir los ajustes.

## 2026-10-21 — Publicación de la v1.0.0

*(Modo directo: petición «publica todo», sin fase de preguntas salvo confirmar
que incluía la release.)*

### 1. La petición tal como se ha entendido

Commit y push de los cambios pendientes (guía y botón «Añadir cuenta…») y
publicación de la primera versión con `scripts/release.sh 1.0.0`. **Confirmación:**
el autor eligió «Sí, v1.0.0».

### 2. Preguntas y respuestas

**P1.** ¿Publicar también la primera versión ahora?
**R1.** Sí, v1.0.0.

### 3. Fuentes analizadas

- `scripts/release.sh` en `9f9b12c`.

### 4. Decisiones

- **Autor del commit del tap = autor local de este repo.** El clon temporal del
  tap habría usado el git global (correo de trabajo). Corregido en `e159a0f`.
- **`${TAG}` con llaves.** Bash con locale no UTF-8 tomaba el primer byte de «…»
  como parte del nombre de la variable (`TAG…: unbound variable`). Falló antes
  de publicar nada; corregido en `aeb12bf`.
- Resultado: release `v1.0.0` con `GitSwitcher-1.0.0.zip`
  (sha256 `ef501f29…79b1eb`), tap `marcosesperon/homebrew-tap` creado (público)
  con `Casks/gitswitcher.rb`. Comprobado que el SHA del cask coincide con el zip
  descargado y que los commits del tap van con el correo personal.

### 5. Alternativas descartadas

- Ninguna.

### 6. Pendiente de comprobar

- ~~Instalar con Homebrew y comprobar la cuarentena~~ → comprobado en el Mac del
  autor (Homebrew 7.0.9): se instala en `/Applications`, sin atributo
  `com.apple.quarantine`, y abre sin aviso. Homebrew 7 tiene «Tap Trust» para
  taps no oficiales; al instalar el cask por su nombre completo lo añadió solo a
  `trust.json`. Vigilar si en futuras versiones de Homebrew hay que pedir
  `brew trust` explícito y, si es así, documentarlo en el README.

## 2026-10-21 — Página de presentación para GitHub Pages

### 1. La petición tal como se ha entendido

**Página web de GitSwitcher** en `site/index.html`, una sola página estática
(HTML + CSS + un poco de JS, sin dependencias externas), publicada en
`https://marcosesperon.github.io/GitSwitcher/`.

- **Idiomas:** inglés y español en la misma página, con selector EN/ES; por
  defecto, el idioma del navegador (y se recuerda la elección).
- **Contenido**, de arriba abajo:
  1. **Presentación:** nombre, frase corta, botón de instalación con Homebrew y de
     descarga (Releases), y el menú de la barra recreado en HTML/CSS con cuentas
     ficticias.
  2. **Qué hace y por qué:** se apoya en gh, no guarda tokens, se sincroniza con la
     terminal.
  3. **Requisitos:** macOS 14+, GitHub CLI.
  4. **Instalación:** Homebrew (con el comando) y manual (zip + cómo abrir una app
     sin firmar).
  5. **Configuración paso a paso**, con botón «Copiar» en cada comando:
     `brew install gh` → `gh auth login` (una vez por cuenta) →
     `gh auth setup-git` → (opcional) autor de los commits, por la opción de la
     app o con `includeIf` (ejemplo incluido).
  6. **Ajustes:** capturas de las pestañas General, Cuentas y Guía.
  7. **Pie:** licencia MIT, enlace al repositorio, versión.
- **Capturas:** reales, de la ventana de ajustes con datos ficticios (cuentas
  `octo-*`, rutas genéricas), en modo claro y oscuro, EN y ES; la página muestra
  la que toca según idioma y tema del visitante. Se regeneran con
  `scripts/screenshots.sh` (test aparte que no se ejecuta con los normales y no
  consulta gh).
- **Publicación:** flujo de GitHub Actions que publica solo `site/` al cambiar;
  activar Pages; *website* del repo y enlace en el README. Antes de publicar, el
  autor revisa la página en local.

**Confirmación:** confirmado por el autor el 2026-10-21 («dale»).

Punto de partida: un `index.html` publicable en GitHub Pages que presente la app,
explique qué hace y cómo configurarla (requisitos y comandos), con capturas en
las que no aparezcan datos personales del autor.

### 2. Preguntas y respuestas

**P1.** ¿Idioma de la página: solo inglés, EN+ES en la misma página con selector,
o dos páginas?
**R1.** Inglés y español en la misma página, con selector EN/ES (por defecto, el
idioma del navegador).

**P2.** ¿Desde dónde se publica: carpeta `site/` con GitHub Actions, `docs/`, o
rama `gh-pages`?
**R2.** Carpeta `site/` publicada con GitHub Actions.

**P3.** ¿Capturas reales con datos ficticios, todo redibujado en HTML/CSS, o
capturas hechas por el autor?
**R3.** Capturas reales de los ajustes con cuentas ficticias (claro/oscuro,
EN/ES); el menú de la barra, redibujado en HTML/CSS.

**P4.** ¿Las capturas se generan una vez o quedan preparadas para regenerarlas?
**R4.** Preparadas: test de capturas que solo se ejecuta bajo demanda
(`scripts/screenshots.sh`) y escribe en `site/img/`.

**P5.** ¿Se activa GitHub Pages y se publica al terminar?
**R5.** Sí: activar Pages (fuente GitHub Actions), push, web en
`https://marcosesperon.github.io/GitSwitcher/`, *website* del repo y enlace en el
README. Antes, revisión en local por el autor.

### 3. Fuentes analizadas

- Repo en `2344ef8` (v1.0.0 publicada). README en inglés; `docs/` contiene
  `decisiones.md` y `documentacion.md`.

### 4. Decisiones

- **Una sola página bilingüe con selector EN/ES.** Por qué: la app ya es bilingüe
  y un único fichero es más fácil de mantener.
- **Web en `site/`, desplegada con GitHub Actions** (solo esa carpeta). Por qué:
  publicar desde `docs/` convertiría `decisiones.md` y `documentacion.md` en
  páginas públicas de la web.
- **Capturas reales con datos ficticios.** Ventanas de ajustes renderizadas desde
  la app con un store de ejemplo (cuentas `octo-*`), en claro/oscuro y EN/ES. El
  menú de la barra (NSMenu, difícil de capturar de forma automática) se recrea en
  HTML/CSS. Por qué: fidelidad real sin exponer datos del autor.
- **Capturas reproducibles con `scripts/screenshots.sh`.** El test no consulta gh:
  usa solo datos ficticios, así que no puede colarse una cuenta real.

- **Plan aprobado el 2026-10-21** («dale»). Detalles de la implementación:
  - Diseño: la navegación es una barra de menús de macOS funcional; el icono de
    GitSwitcher despliega una demo con cuentas `octo-*` y una terminal al lado
    enseña el `gh auth switch` equivalente. Tipografía monoespaciada del sistema
    en titulares (sin fuentes externas), acento verde de «cuenta activa».
  - Capturas: `cacheDisplay` deja transparente la zona de pestañas y en oscuro
    no se veían; se pinta debajo el color de fondo de ventana del tema.
  - `?lang=es|en` en la URL fuerza idioma (surgió para poder revisar con Chrome
    sin ventana, y sirve para compartir enlaces).
  - Revisión: Chrome sin ventana en claro/oscuro, EN/ES y a 390 px (dentro de un
    iframe, porque Chrome sin ventana no baja de ~500 px).
- **Visto bueno del autor tras revisar en local** («me parece bien»).

- **Ajustes tras publicar (comentarios del autor):**
  - Las pestañas de las capturas estaban en orden inverso al de la app; ahora
    General, Cuentas, Guía (con Guía seleccionada al entrar).
  - En oscuro la barra no se reconocía como la de macOS. Opción elegida por el
    autor: la portada hace de escritorio, con un fondo de degradados (verde/azul
    y un toque cálido) que sube por detrás de la barra translúcida y se funde con
    la página; y un halo en el icono de GitSwitcher hasta el primer clic.

### 5. Alternativas descartadas

- **Solo más contraste en la barra.** Cambio mínimo, pero se reconoce menos como
  barra de macOS.

- **Solo inglés.** Deja fuera el español, que la app ya soporta.
- **Dos páginas (`index.html` + `es/index.html`).** Algo mejor para buscadores,
  pero duplica el contenido a mantener.
- **Publicar desde `docs/`.** Expondría los documentos internos como páginas.
- **Rama `gh-pages`.** Aislada pero fácil de dejar desactualizada.
- **Todo redibujado en HTML/CSS.** Ligero, pero no es la app real y se desfasa.
- **Capturas manuales del autor.** Riesgo de que se cuele un dato personal y no
  son reproducibles.
- **Dejarla solo preparada sin publicar.** El autor prefiere publicarla ya, tras
  revisarla en local.
- **Capturas generadas una sola vez.** Se desfasan con el primer cambio de UI.

### 6. Pendiente de comprobar

- El interruptor «Abrir al iniciar sesión» de la captura General refleja el
  estado real del Mac donde se generan las capturas (no es dato personal; se
  comentó al autor por si prefiere fijarlo apagado).
