# antiRant

**Dictado por voz que escribe lo que *quisiste* decir, no lo que dijiste.**

Hablás como hablás: con "ehh", corrigiéndote a la mitad, saltando de idea en idea, contestándole a alguien que te habla mientras dictás. antiRant pasa esa transcripción por una IA y escribe en el cursor la versión limpia.

| Dijiste | Se escribe |
|---|---|
| *"ehh bueno nada, quería decirte que mañana, no, el jueves, sí ya voy, el jueves paso a buscar las cosas"* | *Quería decirte que el jueves paso a buscar las cosas.* |

Está pensado para [Omarchy](https://omarchy.org) (Arch + Hyprland) y funciona como **addon de [voxtype](https://github.com/peteonrails/voxtype)**, el dictado por voz que trae Omarchy. No reemplaza nada: agrega un segundo atajo de dictado "inteligente" y deja el normal como está.

## Cómo funciona

```
 🎤 voz
  │
  ▼
 voxtype ──────────── graba el audio y lo transcribe con Whisper
  │                   (local o remoto, según tu config de voxtype)
  │  texto crudo
  ▼
 antirant ─────────── manda el texto a Gemini 3.8 Flash con prompt.md
  │                   y valida la respuesta
  │  texto limpio
  ▼
 voxtype ──────────── lo escribe donde está el cursor
```

1. voxtype tiene **perfiles** con un `post_process_command`: un comando que recibe la transcripción por stdin y devuelve el texto final por stdout. antiRant es ese comando.
2. `install.sh` crea el perfil `[profiles.antirant]` en la config de voxtype y un atajo de Hyprland que graba usando ese perfil (`voxtype record toggle --profile antirant`).
3. `antirant` le manda la transcripción a Gemini junto con las instrucciones de [`prompt.md`](prompt.md):
   - saca muletillas ("ehh", "o sea", "tipo"…), repeticiones y frases cortadas;
   - si te corregís ("el martes, no, el miércoles"), deja sólo la versión final;
   - descarta lo que le dijiste a otra persona en el medio ("sí, ya voy");
   - ordena ideas sueltas y corrige puntuación;
   - **no** agrega contenido, **no** cambia tu tono ni tu idioma, y **no** responde lo que dictaste (si dictás una pregunta, escribe la pregunta).
4. **Modo seguro:** si Gemini falla, tarda más de lo configurado, devuelve vacío o un texto sospechosamente más largo que el original, se escribe la transcripción original. Nunca perdés lo que dictaste.

El tiempo extra es lo que tarda Gemini (normalmente menos de un segundo con `thinking_level = "low"`). El texto aparece cuando terminás de hablar, no mientras hablás: para entender lo que quisiste decir, el modelo necesita la frase completa.

## Requisitos

- [voxtype](https://github.com/peteonrails/voxtype) instalado y funcionando (viene con Omarchy)
- Python 3.11+ (sólo stdlib, sin dependencias)
- Una API key de Gemini: <https://aistudio.google.com/apikey>
- Hyprland con `~/.config/hypr/bindings.lua` (Omarchy) para el atajo automático. En otro entorno, ver [Instalación manual](#instalación-manual).

## Instalación

```bash
git clone https://github.com/4rc4n70s/antiRant.git ~/Applications/antiRant
cd ~/Applications/antiRant
./install.sh
```

El instalador:

- pide la API key y la guarda en `~/.config/antirant/gemini_key` (permisos `600`, fuera del repo);
- agrega el perfil `antirant` a `~/.config/voxtype/config.toml` (hace backup antes);
- agrega el atajo **`SUPER+ALT+R`** a `~/.config/hypr/bindings.lua` (hace backup antes). Si ese atajo ya está en uso, no lo pisa y te avisa. Para usar otro: `ANTIRANT_HOTKEY="SUPER + ALT + X" ./install.sh`;
- reinicia voxtype y recarga Hyprland.

Se puede correr varias veces: sólo agrega lo que falta.

### Instalación manual

Agregá esto a `~/.config/voxtype/config.toml`:

```toml
[profiles.antirant]
post_process_command = "/ruta/a/antiRant/antirant"
post_process_timeout_ms = 6000
```

Guardá la key en `~/.config/antirant/gemini_key` o exportala como `GEMINI_API_KEY`, y asociá a un atajo el comando:

```bash
voxtype record toggle --profile antirant
```

## Uso

Apretá el atajo, hablá, y apretalo de nuevo para terminar. El texto limpio aparece donde está el cursor.

Para probarlo sin hablar:

```bash
echo "ehh bueno quería decirte que mañana, no, el jueves, sí ya voy, el jueves paso a buscar las cosas" | ./antirant
```

## Configuración

| Archivo | Qué controla |
|---|---|
| [`prompt.md`](prompt.md) | Cómo reescribe el modelo. **Acá se afina el comportamiento**, sin tocar código. |
| [`config.toml`](config.toml) | Modelo, `thinking_level` (`low` es más rápido, `medium`/`high` entienden mejor dictados caóticos), timeout, límite de seguridad y log. |

## Privacidad

- **Lo que dictás sale de tu máquina:** el texto transcripto se manda a la API de Google Gemini. El audio va a donde lo mande voxtype: queda local si usás Whisper local, o va al proveedor remoto que hayas configurado.
- **Log local:** con `[log] enabled = true` (valor por defecto), cada dictado se guarda en `~/.local/state/antirant/log.jsonl` (original, resultado, latencia) para poder ajustar el prompt. Si no querés historial, desactivalo en `config.toml`.
- La API key nunca se guarda en el repo.

## Desinstalar

Borrá el bloque `[profiles.antirant]` de `~/.config/voxtype/config.toml`, la línea de antiRant en `~/.config/hypr/bindings.lua` y la carpeta `~/.config/antirant/`.

## Licencia

[MIT](LICENSE)

## Modo JSON (para otras herramientas)

`antirant --json` devuelve, en la misma llamada a Gemini, el texto limpio y una traducción al inglés:

```bash
echo "abrí espotifai y, esperá que estoy grabando, y mandalo al workspace tres" | ./antirant --json
# {"clean": "Abrí Spotify y mandalo al workspace tres.", "en": "Open Spotify and send it to workspace three."}
```

Ante cualquier falla devuelve `{"clean": <original>, "en": null}`. Lo usa [tetsuHelper](https://github.com/4rc4n70s/tetsuHelper) para pasarle el pedido en inglés a modelos que rinden mejor en ese idioma. Sin `--json` funciona exactamente igual que siempre.

## Vocabulario propio (`--context`)

`antirant --context ~/.config/tetsuhelper/tetsu.md` (o la variable `ANTIRANT_CONTEXT`) suma al prompt **sólo** la sección `## Vocabulario` de ese Markdown: nombres y palabras tuyas, para que las escriba bien. Se ignoran los comentarios `<!-- … -->` y el resto del archivo no sale de tu máquina. Sin la opción, funciona igual que siempre.
