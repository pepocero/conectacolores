# Godot Shaders (recursos externos)

Biblioteca comunitaria de shaders para Godot:

**https://godotshaders.com/**

No está embebida en el repo. Es una **fuente de búsqueda e integración**: el agente debe consultar el sitio (o la página concreta del shader) cuando haga falta un efecto, no inventar shaders complejos si ya existe uno adecuado.

## Cuándo usarla

- Efectos visuales 2D (`canvas_item`) del menú, tablero, fondo, post-proceso ligero.
- Efectos 3D (`spatial`) solo si el proyecto los necesita (este juego es sobre todo 2D/UI).
- Snippets reutilizables publicados en la misma web.

## Flujo obligatorio al traer un shader

1. Buscar en https://godotshaders.com/ un shader compatible con **Godot 4.x**.
2. Abrir la ficha del shader y **leer la licencia** (y créditos del autor).
3. Copiar el código `.gdshader` (y texturas/recursos asociados si los hay) al proyecto, p. ej.:
   - `shaders/` o `assets/shaders/`
4. Integrar con `ShaderMaterial` / material del nodo correspondiente.
5. Anotar en un comentario breve del archivo: URL de origen, autor y licencia.
6. Probar en Godot 4.7; ajustar `render_mode` / uniforms si la API del shader es de una versión anterior.

## Qué no hacer

- No asumir que “está en docs” = catálogo local descargado.
- No pegar shaders sin revisar licencia.
- No sustituir animaciones UI simples (Tween) por shaders salvo que el efecto lo requiera.
- No añadir dependencias de addons de terceros solo para un shader si basta un `.gdshader` suelto.

## Relación con la doc oficial

Shading / materials en Godot 4.7:

- https://docs.godotengine.org/en/latest/tutorials/shaders/index.html
- https://docs.godotengine.org/en/latest/tutorials/shaders/shader_reference/index.html
