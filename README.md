# Florecitas · Control de rentas de mobiliario para eventos

Proyecto final de **Base de Datos** y **Ambientes de Programación Visual** — UABC, FIAD, Ingeniería en Software y Tecnologías Emergentes.

**Equipo Florecitas**

| Integrante | Matrícula | Parte principal |
|---|---|---|
| Arango Gomez Mauro Daniel | 379620 | **La aplicación:** conexión con MySQL, pantallas, interfaz, inicio de sesión y pruebas de interfaz |
| Acevedo Carrillo Veronica | 380207 | **La lógica en MySQL:** procedimientos, triggers y vistas que usa la aplicación, y sus pruebas |
| Rivera Chavez Josselyn Alexa | 379219 | **La base de datos y la documentación:** tablas, usuario de conexión, datos de prueba, instalación, diagramas, presentación y reporte |

Sistema que controla el inventario de mobiliario y las reservaciones por fecha, **impide comprometer más piezas de las disponibles** (la regla la hace cumplir la propia base de datos) y registra entregas, devoluciones, faltantes y daños.

**Tecnologías:** MySQL 8.0 · .NET 10 · ASP.NET Core Razor Pages · Bootstrap 5 · Dapper + MySqlConnector · Chart.js · Visual Studio 2026 · Git/GitHub.

---

## Estructura

```
Equipo_Florecitas_ProyectoFinal_APV/
├── Reporte.pdf                     Reporte técnico (Ambientes de Programación Visual)
├── Reportes_individuales/          Un reporte individual por integrante
├── Presentacion.pdf                Presentación del proyecto
├── README.md
├── Aplicacion/                     Solución .NET (Florecitas.Rentas.slnx)
│   └── src/Florecitas.Rentas.Web/
│       ├── Data/                   Acceso al SGBD (Dapper): repositorios y traducción de errores
│       ├── Models/                 Clases de entidades y vistas
│       ├── Security/               Cifrado de contraseñas (PBKDF2)
│       ├── Pages/                  Razor Pages: Tablero, Disponibilidad, Reservaciones, Clientes,
│       │                           Artículos, Categorías, Empleados, Reportes, Auditoría, Cuenta
│       └── wwwroot/                CSS (sistema de diseño), JS y librerías locales
├── Sql/
│   ├── 01_esquema.sql              DDL: 11 tablas, PK, FK, UNIQUE, CHECK, índices
│   ├── 02_rutinas.sql              3 funciones, 5 procedimientos, 19 triggers
│   ├── 03_datos.sql                Datos de prueba ficticios (fechas relativas a hoy)
│   ├── 04_consultas_vistas.sql     4 vistas, 12 consultas, transacciones COMMIT / ROLLBACK
│   ├── 05_pruebas.sql              41 casos de prueba con resultado observado
│   ├── 06_seguridad_respaldo.sql   Usuario de la app (mínimo privilegio) y respaldo
│   └── instalar_bd.ps1             Ejecuta todo en orden
├── Diagramas/                      5 notaciones (SVG editable + PNG + PDF)
├── Pruebas/                        Matriz de pruebas, salidas reales, capturas e incidencias
└── Video/                          Video demostrativo (ProyectoFinal_Florecitas.mp4)
```

> `02_rutinas` va antes de los datos para que los datos de prueba también pasen por las reglas de negocio; `05_pruebas` contiene las pruebas de rutinas.

> **Windows:** clona el repositorio en una ruta corta (por ejemplo `C:\dev\florecitas`). Rutas de más de 260 caracteres provocan errores de compilación y de Git.

## Requisitos

- MySQL Server 8.0 (y opcionalmente MySQL Workbench)
- .NET 10 SDK (o Visual Studio 2026 con la carga de trabajo ASP.NET)

## 1. Instalar la base de datos

Desde PowerShell, en la carpeta `Sql`:

```powershell
.\instalar_bd.ps1
```

Pide la contraseña de `root` y ejecuta 01 → 02 → 03 → 04 → 06. Para correr también las pruebas: `.\instalar_bd.ps1 -Pruebas`.
También se pueden abrir los scripts en MySQL Workbench y ejecutarlos en ese orden.

El script 06 crea el usuario de la aplicación `rentas_app` (solo SELECT/INSERT/UPDATE/DELETE/EXECUTE). **Cambia su contraseña** si el equipo no es de uso escolar.

## 2. Configurar la conexión (sin exponer credenciales)

La cadena de conexión **no está en el repositorio**. Se guarda en los *user-secrets* del servidor:

```powershell
cd Aplicacion\src\Florecitas.Rentas.Web
dotnet user-secrets set "ConnectionStrings:Rentas" "Server=localhost;Port=3306;Database=rentas_mobiliario;User ID=rentas_app;Password=Florecitas_App_2026!;Allow User Variables=true;"
```

En producción se usa la variable de entorno `ConnectionStrings__Rentas`.

## 3. Ejecutar la aplicación

```powershell
cd Aplicacion\src\Florecitas.Rentas.Web
dotnet run --launch-profile http
```

Abrir http://localhost:5207. En Visual Studio: abrir `Aplicacion/Florecitas.Rentas.slnx` y presionar F5.

**Usuarios de prueba** (solo para el entorno escolar):

| Usuario | Contraseña | Rol |
|---|---|---|
| `admin` | `Admin2026!` | Administrador |
| `carlos.ibarra` | `Encargado2026!` | Encargado |
| `diana.soto` | `Encargado2026!` | Encargado |
| `jorge.pena` | `Encargado2026!` | Encargado **inactivo** (no puede entrar) |

**Demostración:**
1. *Disponibilidad* → elegir el viernes que aparece en la agenda: quedan 10 sillas Tiffany (100 − 60 − 30, el ejemplo del análisis).
2. *Nueva reservación* para ese viernes con 20 sillas Tiffany → la BD la rechaza (RN-03) y el formulario conserva los datos. Con 10 sí se guarda.
3. En el detalle: *Registrar entrega* (el trigger la marca Entregada) → *Registrar devolución* con una pieza dañada (pasa a Finalizada).
4. Verificar en MySQL: `SELECT * FROM vw_reservacion_resumen ORDER BY id_reservacion DESC LIMIT 3;` y `SELECT * FROM bitacora ORDER BY id_bitacora DESC LIMIT 5;`
5. Cerrar y volver a abrir la app: los datos siguen ahí (persistencia).

## 4. Pruebas

- **Base de datos:** `Sql/05_pruebas.sql` (41 casos, válidos y no válidos). Muestra una tabla con el resultado observado de cada caso.
- **Interfaz:** 29 casos ejecutados sobre la aplicación; resultados en `Pruebas/resultados_ui.json` y capturas en `Pruebas/capturas/`.
- Matriz completa: `Pruebas/matriz_pruebas.csv`. Incidencias reales: `Pruebas/incidencias.md`.
