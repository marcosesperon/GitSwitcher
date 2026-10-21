# GitSwitcher — Documentación

## 1. Introducción

GitSwitcher es una app de la barra de menú de macOS que sirve para cambiar de
cuenta de GitHub CLI (`gh`) con un clic. Viene a sustituir a los típicos scripts
de una línea del estilo `gh auth switch --user <cuenta>`.

La idea clave es que **la app no gestiona cuentas ni credenciales: se las pide
todas a gh**. gh ya sabe tener varias cuentas, guarda los tokens en el llavero y,
si es el *credential helper* de git (`gh auth setup-git`), también decide con qué
cuenta se hace `git push`. La app solo pone una cara amable encima.

### Cómo funciona por dentro

```
Barra de menú (StatusMenuController)   Ajustes (SettingsView)
                 \                      /
                  AccountsStore  ←  el «cerebro»: estado y acciones
                 /      |       \
          GhClient  GitConfigWriter  HostsWatcher
              |           |              |
             gh          git       carpeta de config de gh
```

- **`GhLocator`** busca gh. Una app abierta desde el Finder no ve el `PATH` de la
  terminal, así que le pregunta una vez al shell del usuario (`$SHELL -l -i`) y,
  si no responde, mira en los sitios habituales (`/opt/homebrew/bin`,
  `/usr/local/bin`…). También averigua si el usuario cambió `GH_CONFIG_DIR` o
  `XDG_CONFIG_HOME`, para que la app y la terminal miren la misma configuración.
- **`GhClient`** es el único que habla con gh:
  - `gh auth status --json hosts` → lista de cuentas y cuál está activa.
  - `gh auth switch --hostname github.com --user X` → cambiar de cuenta.
  - `gh auth token --user X` + `gh api user` → perfil de una cuenta **sin
    cambiar la activa** (el token se pasa solo a esa llamada y no se guarda).
  - `openInTerminal` → lanza gh a la vista en Terminal (con `TerminalLauncher`)
    para `gh auth login` y `gh auth setup-git`.
- **`HostsWatcher`** vigila `hosts.yml` y su carpeta. El fichero, porque
  `gh auth switch` lo reescribe en su sitio (y eso no cuenta como cambio de la
  carpeta); la carpeta, por si el fichero aún no existe o alguien lo sustituye
  por otro, para volver a engancharse. Así, si cambias de cuenta desde la
  terminal, la barra se actualiza sola.
  Además, cada vez que se abre el menú se vuelve a preguntar a gh, por si acaso.
- **`SetupChecker`** hace las comprobaciones de la pestaña Guía, sin cambiar
  nada: ruta y versión de gh (`gh --version`), si git pide las credenciales de
  github.com a gh (`git config --get-all credential.https://github.com.helper`
  contiene `gh auth git-credential`) y si hay Homebrew.
- **`TerminalLauncher`** abre Terminal con un comando a la vista: escribe un
  `.command` temporal y lo abre, sin pedir permisos de automatización. Lo usan
  el botón «Añadir cuenta…» de Ajustes › Cuentas y los botones «Abrir en
  Terminal» de la guía.
- **Actualizaciones** (`UpdateStore` + `ReleaseFeed` + `UpdateInstaller` +
  `InstallMethod`):
  - `ReleaseFeed` pide a la API pública de GitHub la última release
    (`/repos/marcosesperon/GitSwitcher/releases/latest`): versión, notas,
    página y el `GitSwitcher-X.Y.Z.zip` con su huella SHA-256 (campo `digest`,
    que GitHub calcula solo). `AppVersion` compara versiones número a número.
  - `UpdateStore` comprueba al arrancar y cada 24 h si está activada la casilla,
    y a mano con «Buscar actualizaciones…». Si hay versión nueva, el icono lleva
    un puntito y el menú empieza con «Actualización disponible».
  - `InstallMethod` decide cómo actualizar: si existe
    `…/Caskroom/gitswitcher` y la app está en `/Applications`, es de Homebrew y
    se lanza `brew update && brew upgrade --cask gitswitcher` en Terminal (el
    `brew update` hace falta porque Homebrew solo refresca los taps una vez al
    día); si no, se autoactualiza.
  - `UpdateInstaller` no toca la app instalada hasta el final: comprueba que
    puede escribir en su carpeta, descarga, compara la huella, descomprime con
    `ditto`, comprueba identificador, versión y firma (`codesign --verify`), y
    solo entonces cambia la app vieja por la nueva de una vez
    (`replaceItemAt`). Luego un script espera a que la app se cierre y abre la
    nueva.
- **Icono y color por cuenta** (`AccountAppearance.swift`): `AccountIcon` (24
  iconos) y `AccountColor` (12 colores de sistema) se guardan por su nombre
  (`briefcase`, `blue`…), no por el del símbolo, para poder cambiar el símbolo
  sin perder la elección. `AccountBadge` dibuja el icono: sin color, imagen
  plantilla (como el resto de la barra); con color, el símbolo pintado de ese
  color. Las preferencias antiguas sin icono ni color se siguen leyendo, y un
  icono desconocido no borra el alias ni el autor de git de la cuenta.
- **`AccountsStore`** junta todo: estado, cambio de cuenta, autor de git y
  preferencias. El menú y los ajustes solo leen de aquí.
- **`CommandRunner`** lanza los procesos sin bloquear la interfaz, siempre con los
  argumentos como lista (nada de montar cadenas para el shell) y con un tiempo
  máximo para que un comando colgado no deje la app esperando.

Solo se enseñan las cuentas de `github.com`, pero cada cuenta guarda su host:
soportar GitHub Enterprise sería quitar el filtro de `visibleAccounts` y agrupar
el menú por host.

## 2. Parametrización

### Pestaña Guía

Los ajustes tienen tres pestañas: **General**, **Cuentas** y **Guía**. La Guía
explica qué hace falta y comprueba en vivo en qué punto está el Mac:

| Paso | Se marca ✓ cuando… | Comando |
|---|---|---|
| 1. Instalar GitHub CLI | la app encuentra gh (enseña versión y ruta) | `brew install gh` (solo si hay Homebrew) o enlace a cli.github.com |
| 2. Iniciar sesión con cada cuenta | hay al menos una cuenta en github.com | `gh auth login` |
| 3. Que git use la cuenta activa | gh es el credential helper de git para github.com | `gh auth setup-git` |
| 4. Autor de los commits | (opcional, no se comprueba) | botón a la pestaña Cuentas |

Las comprobaciones se repiten al entrar en la pestaña y con «Comprobar de nuevo».
Si al arrancar no había gh y se instala después, la app lo vuelve a buscar sola.
Cuando falta gh o no hay ninguna cuenta, el menú ofrece «Guía de configuración…»,
que abre los ajustes directamente en esta pestaña.

### Ajustes

Todo se cambia desde **Ajustes…** en el menú y se guarda en las preferencias de
macOS (`com.marcosesperon.GitSwitcher`). No se guarda nada secreto.

| Ajuste | Por defecto | Qué hace |
|---|---|---|
| Abrir al iniciar sesión | No | Registra la app como ítem de inicio (`SMAppService`). También se puede quitar desde Ajustes del Sistema › General › Ítems de inicio. |
| Buscar actualizaciones automáticamente | Sí | Pregunta a GitHub por la última versión al arrancar y cada 24 h. Sin datos del usuario. |
| Solo icono en la barra | No | Oculta el nombre de la cuenta activa y deja solo el icono. |
| Alias (por cuenta) | vacío | Nombre corto en la barra. Si está vacío, se ve el login de GitHub. |
| Icono (por cuenta) | Predeterminado | Uno de 24 símbolos (`AccountIcon`). Se ve en la barra (cuenta activa), en el menú y en Ajustes › Cuentas. |
| Color (por cuenta) | Sin color | Uno de 12 colores de sistema de macOS (`AccountColor`). Sin color, el icono es «plantilla» y macOS lo pinta en blanco/negro según la barra. |
| Cambiar también el autor de git | No | Al cambiar de cuenta, fija `user.name` y `user.email` en el `~/.gitconfig` global. |
| Nombre / Correo (por cuenta) | autorrelleno | Solo con la opción anterior activa. Se rellenan desde el perfil de GitHub al activarla o con «Rellenar desde GitHub»; si el correo es privado se usa `ID+login@users.noreply.github.com`. Se pueden editar. |

Claves internas en `UserDefaults`: `iconOnly`, `changeGitAuthor`,
`checkForUpdates` y
`accountPreferences` (JSON con alias, nombre, correo, icono y color por cuenta, indexado por
`host/login`).

### Publicar una versión

```sh
scripts/release.sh 1.2.0
```

El script:

1. Comprueba que no hay cambios sin commitear, que `HEAD` está subido a
   `origin/main` y que la release no existe.
2. Compila en Release (universal, Intel + Apple Silicon) con firma *ad hoc*.
3. Genera `dist/GitSwitcher-1.2.0.zip` y su SHA-256.
4. **Pide confirmación** y entonces crea la release `v1.2.0` en GitHub y
   actualiza `Casks/gitswitcher.rb` en `marcosesperon/homebrew-tap` (si el tap no
   existe, ofrece crearlo).

Todo se publica con la cuenta `marcosesperon` aunque la activa en gh sea otra: el
script toma su token con `gh auth token --user` y lo usa como `GH_TOKEN` solo
mientras dura.

El cask sale de `packaging/gitswitcher.rb.template`. Como la app no está firmada
con Developer ID, el cask le quita la cuarentena tras instalarla.

### Web (GitHub Pages)

La web de presentación vive en `site/` y se publica en
<https://marcosesperon.github.io/GitSwitcher/>.

- **`site/index.html`**: una sola página, sin librerías externas, con el CSS y el
  JS dentro. Todos los textos están dos veces (`<span lang="en">` y
  `<span lang="es">`) y el CSS enseña solo el idioma elegido. El idioma sale del
  navegador, se recuerda si el visitante lo cambia y se puede forzar con
  `?lang=es` o `?lang=en` en la dirección.
- La barra de navegación imita la barra de menús de macOS y el icono de
  GitSwitcher es una demo que funciona: al cambiar de cuenta, la terminal de al
  lado enseña el `gh auth switch` equivalente. Todo con cuentas inventadas.
- La versión del pie se pide a la API de GitHub (última release); si falla, no
  sale número.
- **Publicación:** `.github/workflows/pages.yml` sube `site/` a Pages cada vez que
  cambia en `main` (o a mano desde la pestaña Actions).

Para verla en local:

```sh
cd site && python3 -m http.server 8000   # y abrir http://localhost:8000
```

### Capturas de la web

Las capturas de los ajustes (`site/img/settings-<pestaña>-<idioma>-<tema>.png`)
y de la ventana de actualización (`site/img/update-<idioma>-<tema>.png`, con una
versión 9.9.9 inventada)
se regeneran con:

```sh
scripts/screenshots.sh
```

Lanza el test `ScreenshotTests` dos veces (inglés y español). Ese test no corre
con los tests normales: solo cuando el script le pasa la variable
`GITSWITCHER_SCREENSHOTS_DIR`. Usa cuentas inventadas (`octo-work`,
`octo-personal`) cargadas con `AccountsStore.loadSampleData`, que solo existe en
compilaciones Debug y nunca pregunta a gh, así que en las capturas no puede salir
ninguna cuenta real. Las preferencias van a un dominio temporal de
`UserDefaults`, sin tocar las del usuario.

### Icono

`swift scripts/make-icon.swift` vuelve a generar todas las medidas del icono en
`GitSwitcher/Resources/Assets.xcassets/AppIcon.appiconset`.

### Traducciones

La app está en 9 idiomas: inglés (base), español, francés, alemán, italiano,
portugués de Brasil, japonés, chino simplificado y coreano. macOS elige según el
idioma del sistema o el que el usuario fije para la app.

- Los textos están en `GitSwitcher/Resources/Localizable.xcstrings`. Al añadir
  textos nuevos en el código, abre el catálogo en Xcode: los detecta al compilar
  y solo hay que traducirlos a los 8 idiomas.
- Cuando un texto tiene varios huecos (`%@`), las traducciones usan posiciones
  (`%1$@`, `%2$@`) para que cada idioma pueda ordenar la frase a su manera.
- `LocalizationTests` falla si un texto no está en todos los idiomas, si una
  traducción pierde o añade huecos, o si la app compilada no incluye algún
  `.lproj`. Los idiomas también deben estar en `CFBundleLocalizations`
  (`project.yml`).
- Para revisar a ojo cómo queda un idioma: el test de capturas acepta cualquier
  idioma (`GITSWITCHER_SCREENSHOTS_LANG` + `-testLanguage`); `screenshots.sh` solo
  genera inglés y español porque son los de la web.

## 3. Ejemplos de uso

**Cambiar de cuenta.** Clic en el icono → elegir la cuenta. Es lo mismo que:

```sh
gh auth switch --hostname github.com --user mi-cuenta-personal
```

**Configurar un Mac desde cero.** Ajustes → Guía, y seguir los pasos que salgan
con ✗ usando «Abrir en Terminal». Al volver a la pestaña se comprueban otra vez.

**Añadir una cuenta.** Ajustes → Cuentas → «Añadir cuenta…». Se abre Terminal
con `gh auth login`; al terminar, la cuenta nueva aparece sola en la lista y en
el menú.

**Actualizar la app.** Menú → «Buscar actualizaciones…» (o esperar al aviso).
En la ventana, «Instalar y reiniciar»; si se instaló con Homebrew, «Actualizar
con Homebrew». Para probar el instalador sin publicar nada están los tests
`UpdateInstallerTests`, que montan una app falsa en una carpeta temporal.

**Que `git push` use la cuenta activa.** Una sola vez:

```sh
gh auth setup-git
```

**Autor de git por carpeta en vez de global** (alternativa a activar «Cambiar
también el autor de git»). En `~/.gitconfig`:

```ini
[includeIf "gitdir:~/trabajo/"]
    path = ~/.gitconfig-trabajo
```

y en `~/.gitconfig-trabajo`:

```ini
[user]
    name = Nombre Apellido
    email = nombre@empresa.example
```

**Compilar y probar:**

```sh
xcodegen generate
xcodebuild -project GitSwitcher.xcodeproj -scheme GitSwitcher test
```
