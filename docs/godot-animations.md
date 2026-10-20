# Animaciones en Godot 4.7

Motor del proyecto: **Godot 4.7**. Documentación oficial (*latest* / 4.7):

- Home: https://docs.godotengine.org/en/latest/
- Sección Animation: https://docs.godotengine.org/en/latest/tutorials/animation/index.html
- Introduction (AnimationPlayer): https://docs.godotengine.org/en/latest/tutorials/animation/introduction.html

## Qué usar en este proyecto (prioridad)

Este juego es 2D / UI procedural (GDScript). Preferir en este orden:

1. **`Tween` / `create_tween()`** — UI, overlays, menús, feedback corto, entradas de botones, fades. Es el patrón ya usado en `scripts/` (victory, main_menu, etc.).
2. **`AnimationPlayer`** — secuencias más largas o varias pistas (posición, color, llamadas a métodos) cuando un Tween se vuelve difícil de mantener.
3. **`AnimationTree`** — solo si hay máquina de estados de animación (poco habitual aquí).
4. **Sprites animados / `AnimatedSprite2D`** — cuando hay frames gráficos, no motion de propiedades.
5. **Vídeo (`VideoStreamPlayer`)** — solo si se debe reproducir un MP4 tal cual; no sustituye animación editable de UI.

Referencias útiles:

- Track types: https://docs.godotengine.org/en/latest/tutorials/animation/animation_track_types.html
- Cutout: https://docs.godotengine.org/en/latest/tutorials/animation/cutout_animation.html
- 2D skeletons: https://docs.godotengine.org/en/latest/tutorials/animation/2d_skeletons.html
- AnimationTree: https://docs.godotengine.org/en/latest/tutorials/animation/animation_tree.html
- Playing videos: https://docs.godotengine.org/en/latest/tutorials/animation/playing_videos.html
- Creating movies: https://docs.godotengine.org/en/latest/tutorials/animation/creating_movies.html

## Convenciones del proyecto

- Respetar código que ya anima con Tween: **no migrar a AnimationPlayer** salvo petición explícita.
- Animaciones de UI: `TRANS_*` + `EASE_*` coherentes con pantallas cercanas; duración corta (≈0.12–0.4 s) salvo cinemáticas.
- No bloquear input de forma permanente; usar `await` solo donde el flujo ya lo hace (overlays, cinemáticas).
- Efectos de partículas / brillos: respetar `SettingsManager.fx_enabled`.
- Si el usuario aporta un **MP4 de referencia**: usarlo como guía visual (timing, easing, trayectoria). Reconstruir con Tween/AnimationPlayer + assets; no asumir importación automática del vídeo como animación de nodos.

## Class reference (buscar en docs)

- `Tween`, `MethodTweener`, `PropertyTweener`
- `AnimationPlayer`, `Animation`, `AnimationLibrary`
- `AnimationTree`, `AnimationNode*`
- `AnimatedSprite2D`, `SpriteFrames`
- `VideoStreamPlayer`

Índice de clases: https://docs.godotengine.org/en/latest/classes/index.html
