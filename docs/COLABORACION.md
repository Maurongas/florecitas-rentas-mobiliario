# Cómo subimos el proyecto entre los tres (cada quien con sus commits)

El proyecto completo está en el archivo **`Equipo_Florecitas_completo.zip`**. Para que en GitHub quede claro qué hizo cada quien, **cada integrante sube su parte desde su propia cuenta**, en su propia rama, con varios commits, y abre un *Pull Request*. Cada parte toca archivos distintos, así que **no hay conflictos** y se puede subir en cualquier orden.

| Integrante | Rama | Qué sube |
|---|---|---|
| Josselyn | `parte-josselyn-modelo` | Diagramas, esquema, datos de prueba, seguridad, reporte |
| Verónica | `parte-veronica-rutinas` | Rutinas (triggers, funciones, procedimientos), consultas, pruebas |
| Mauro | `parte-mauro-aplicacion` | La aplicación web (carpeta `Aplicacion`) |

---

## A. Preparación (una sola vez, cada integrante)

1. **Aceptar la invitación** al repositorio: llega al correo de GitHub, o entra a <https://github.com/Maurongas/florecitas-rentas-mobiliario/invitations> y da clic en **Accept invitation**. *(Mauro no la necesita: es el dueño.)*
2. Instalar **GitHub Desktop** (<https://desktop.github.com>) e iniciar sesión con tu cuenta de GitHub:
   **File → Options → Accounts → Sign in**.
3. En **File → Options → Git** revisa que *Name* y *Email* sean los de **tu** cuenta de GitHub (así los commits salen con tu nombre y foto).
4. **Descomprimir el zip:** clic derecho en `Equipo_Florecitas_completo.zip` → **Extraer todo…** → extráelo en una ruta corta, por ejemplo `C:\dev\completo`.
   Te queda la carpeta `C:\dev\completo\Equipo_Florecitas_ProyectoFinal_BD`. A esta carpeta le llamamos **ZIP** en los pasos siguientes.
   > Usa rutas cortas (como `C:\dev`). Si la ruta es muy larga, Windows da errores.
5. **Clonar el repositorio:** en GitHub Desktop → **File → Clone repository** → pestaña **GitHub.com** → elige `Maurongas/florecitas-rentas-mobiliario` → en *Local path* pon `C:\dev\repo` → **Clone**.
   Te queda la carpeta `C:\dev\repo\florecitas-rentas-mobiliario`. A esta carpeta le llamamos **REPO**.

## B. Crear tu rama

1. En GitHub Desktop, arriba al centro, **Current branch** debe decir `main`. Da clic en **Fetch origin** para tener lo último.
2. **Current branch → New branch** → escribe el nombre de tu rama (de la tabla de arriba, por ejemplo `parte-veronica-rutinas`) → **Create branch**.

## C. Hacer tus commits (uno por paso)

Para **cada fila** de tu tabla (sección D):

1. Abre dos ventanas del Explorador de archivos: una en **ZIP** y otra en **REPO**.
2. **Copia** lo que dice la columna *Qué copiar* de ZIP a REPO, **en la misma ubicación** (si la carpeta no existe en REPO, créala con el mismo nombre). Copia solo eso, nada más.
3. Regresa a GitHub Desktop: en la pestaña **Changes** aparecen los archivos nuevos (todos con palomita).
4. Abajo a la izquierda, en **Summary**, pega el *Mensaje del commit* de esa fila.
5. Clic en **Commit to tu-rama**.
6. Repite con la siguiente fila.

Al terminar todas tus filas:

7. Clic en **Publish branch** (arriba a la derecha).
8. Clic en **Create Pull Request** (o en GitHub: pestaña *Pull requests* → *New pull request*, base `main`, compare tu rama) → escribe un título (por ejemplo "Parte de Verónica: rutinas y pruebas") → **Create pull request**.
9. Avisa al equipo. Otra integrante lo revisa (pestaña *Files changed*) y da clic en **Merge pull request → Confirm merge**.

Cuando estén los 3 Pull Requests unidos, `main` tiene el proyecto completo.

## D. Qué copia cada quien

### Josselyn (`parte-josselyn-modelo`)
| # | Qué copiar (de ZIP a REPO) | Mensaje del commit |
|---|---|---|
| 1 | Carpeta `Diagramas` completa | Agrega diagramas del modelo en las 5 notaciones (Crow's Foot, Chen, Connect to Columns, UML e IDEF1X) |
| 2 | `Sql\01_esquema.sql` | Agrega el esquema de la base de datos: tablas, llaves y restricciones |
| 3 | `Sql\03_datos.sql` | Agrega datos de prueba ficticios y reproducibles |
| 4 | `Sql\06_seguridad_respaldo.sql` y `Sql\instalar_bd.ps1` | Agrega usuario de la aplicación, respaldo e instalador de la base de datos |
| 5 | Carpeta `docs\reporte` completa | Agrega el generador y los textos del reporte técnico |
| 6 | `Reporte.pdf` (está en la raíz) | Agrega el reporte técnico en PDF |

### Verónica (`parte-veronica-rutinas`)
| # | Qué copiar (de ZIP a REPO) | Mensaje del commit |
|---|---|---|
| 1 | `Sql\02_rutinas.sql` | Agrega funciones, procedimientos almacenados y triggers |
| 2 | `Sql\04_consultas_vistas.sql` | Agrega vistas, 12 consultas documentadas y transacciones COMMIT/ROLLBACK |
| 3 | `Sql\05_pruebas.sql` y la carpeta `Pruebas\salidas_sql` | Agrega 41 casos de prueba de la base de datos con su resultado observado |
| 4 | `Pruebas\e2e_capturas.py`, `Pruebas\resultados_ui.json` y la carpeta `Pruebas\capturas` | Agrega pruebas automatizadas de interfaz y capturas de evidencia |
| 5 | `Pruebas\matriz_pruebas.csv`, `Pruebas\incidencias.md` y `Pruebas\evidencia_persistencia_mysql.txt` | Agrega matriz de pruebas, incidencias y evidencia de persistencia |

### Mauro (`parte-mauro-aplicacion`)
Todo está dentro de `Aplicacion`. La carpeta del proyecto es `Aplicacion\src\Florecitas.Rentas.Web` (abajo se abrevia **WEB**).

| # | Qué copiar (de ZIP a REPO) | Mensaje del commit |
|---|---|---|
| 1 | `Aplicacion\Florecitas.Rentas.slnx` y, de **WEB**: `Florecitas.Rentas.Web.csproj`, `Program.cs`, `appsettings.json`, `appsettings.Development.json` y la carpeta `Properties` | Crea la solución .NET 10 y la configuración de la aplicación |
| 2 | De **WEB**: carpetas `Data`, `Models` y `Security` | Agrega la capa de acceso a datos con Dapper, modelos y cifrado de contraseñas |
| 3 | De **WEB**: carpeta `wwwroot`; y de `WEB\Pages`: carpetas `Shared` y `Cuenta`, y los archivos `_ViewImports.cshtml`, `_ViewStart.cshtml`, `PaginaBase.cs`, `Error.cshtml`, `Error.cshtml.cs` | Agrega el sistema de diseño, layout, componentes compartidos e inicio de sesión |
| 4 | De `WEB\Pages`: `Index.cshtml`, `Index.cshtml.cs`, `Disponibilidad.cshtml`, `Disponibilidad.cshtml.cs` y la carpeta `Reservaciones` | Agrega tablero, disponibilidad y el flujo de reservaciones, entregas y devoluciones |
| 5 | De `WEB\Pages`: carpetas `Clientes`, `Articulos`, `Categorias` y `Empleados` | Agrega CRUD de clientes, artículos, categorías y empleados |
| 6 | De `WEB\Pages`: carpetas `Reportes` y `Bitacora` | Agrega módulo de reportes con filtros, exportación CSV y auditoría |

> **No copies** las carpetas `bin`, `obj` ni `.vs` si llegaran a aparecer: el `.gitignore` las ignora.

**Alternativa con un comando:** quien prefiera PowerShell puede hacer todos sus commits de una vez con
`docs\colaboracion\subir_parte.ps1 -Integrante josselyn -Origen C:\dev\completo\Equipo_Florecitas_ProyectoFinal_BD` (cambiar el nombre según quién seas). Hace exactamente lo mismo que la tabla.

---

## E. Cambios después de la entrega (por ejemplo, tu conclusión)

1. GitHub Desktop → **Current branch: main** → **Fetch origin / Pull origin**.
2. **New branch** (por ejemplo `ajuste-conclusion-josselyn`).
3. Edita el archivo (las conclusiones están en `docs\reporte\contenido.py`).
4. Haz **Commit**, luego **Publish branch** y **Create Pull Request**.

---

## F. Cómo ejecutar el sistema (para la demostración)

Clonar y darle al botón verde **casi** funciona; antes hay que tener la base de datos y la conexión configuradas. Solo se hace una vez por computadora.

**Necesitas:** MySQL Server 8.0 (con su contraseña de `root`) y Visual Studio 2026 con la carga de trabajo *Desarrollo de ASP.NET y web*.

1. **Instalar la base de datos**
   - **Opción Workbench:** abre MySQL Workbench, conéctate a tu servidor local y abre y ejecuta (rayo ⚡) **en este orden**: `Sql\01_esquema.sql`, `02_rutinas.sql`, `03_datos.sql`, `04_consultas_vistas.sql`, `06_seguridad_respaldo.sql`.
   - **Opción PowerShell:** en la carpeta `Sql`, ejecuta
     `powershell -ExecutionPolicy Bypass -File .\instalar_bd.ps1` y escribe la contraseña de root.
2. **Abrir el proyecto:** Visual Studio → *Clonar un repositorio* (o *Abrir un proyecto o una solución*) → abre `Aplicacion\Florecitas.Rentas.slnx`.
3. **Configurar la conexión (una vez):** en el *Explorador de soluciones*, clic derecho en el proyecto **Florecitas.Rentas.Web → Administrar secretos de usuario**. Se abre `secrets.json`; pega esto y guarda:
   ```json
   {
     "ConnectionStrings:Rentas": "Server=localhost;Port=3306;Database=rentas_mobiliario;User ID=rentas_app;Password=Florecitas_App_2026!;Allow User Variables=true;"
   }
   ```
   (Así la contraseña no queda en el repositorio.)
4. **Ejecutar:** junto al botón verde ▶ elige el perfil **http** y presiona el botón (o F5). Se abre el navegador en `http://localhost:5207`.
5. **Entrar:** usuario `admin`, contraseña `Admin2026!` (Administrador) o `carlos.ibarra` / `Encargado2026!` (Encargado).

Si sale "Sin conexión con la base de datos": revisa que el servicio MySQL esté encendido (Servicios de Windows → *MySQL80*), que corriste los 5 scripts y que el `secrets.json` esté guardado.

**Para reiniciar los datos** antes de presentar: vuelve a ejecutar los scripts 01 → 04 y 06 (el 01 borra y crea la base de nuevo).
