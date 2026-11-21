using Florecitas.Rentas.Web.Models;

namespace Florecitas.Rentas.Web.Data;

/// <summary>CRUD de CATEGORIA y ARTICULO.</summary>
public sealed class CatalogoRepositorio(Db db)
{
    // ----------------------------- Categorías -----------------------------
    public Task<IReadOnlyList<Categoria>> CategoriasAsync() => db.ConsultarAsync<Categoria>(@"
        SELECT c.id_categoria, c.nombre, c.descripcion, COUNT(a.id_articulo) AS articulos
          FROM categoria c
          LEFT JOIN articulo a ON a.id_categoria = c.id_categoria
         GROUP BY c.id_categoria, c.nombre, c.descripcion
         ORDER BY c.nombre");

    public Task<Categoria?> CategoriaAsync(int id) => db.UnoAsync<Categoria>(
        "SELECT id_categoria, nombre, descripcion FROM categoria WHERE id_categoria = @id", new { id });

    public Task<int> CrearCategoriaAsync(Categoria c) => db.EscalarAsync<int>(@"
        INSERT INTO categoria (nombre, descripcion) VALUES (@Nombre, @Descripcion);
        SELECT LAST_INSERT_ID();", c);

    public Task<int> ActualizarCategoriaAsync(Categoria c) => db.EjecutarAsync(
        "UPDATE categoria SET nombre = @Nombre, descripcion = @Descripcion WHERE id_categoria = @IdCategoria", c);

    // ON DELETE RESTRICT impide borrar una categoría con artículos (error 1451)
    public Task<int> EliminarCategoriaAsync(int id) =>
        db.EjecutarAsync("DELETE FROM categoria WHERE id_categoria = @id", new { id });

    // ----------------------------- Artículos ------------------------------
    public async Task<IReadOnlyList<Articulo>> ArticulosAsync(string? buscar, int? idCategoria, bool incluirInactivos)
    {
        return await db.ConsultarAsync<Articulo>(@"
            SELECT a.id_articulo, a.id_categoria, c.nombre AS categoria, a.nombre, a.descripcion,
                   a.cantidad_total, a.precio_dia, a.activo,
                   (SELECT COUNT(*) FROM detalle_reservacion d WHERE d.id_articulo = a.id_articulo) AS veces_rentado,
                   fn_disponible(a.id_articulo, CURDATE(), CURDATE(), NULL) AS disponible_hoy
              FROM articulo a
              JOIN categoria c ON c.id_categoria = a.id_categoria
             WHERE (@buscar IS NULL OR a.nombre LIKE CONCAT('%', @buscar, '%') OR a.descripcion LIKE CONCAT('%', @buscar, '%'))
               AND (@idCategoria IS NULL OR a.id_categoria = @idCategoria)
               AND (@incluirInactivos = 1 OR a.activo = 1)
             ORDER BY c.nombre, a.nombre",
            new { buscar = string.IsNullOrWhiteSpace(buscar) ? null : buscar.Trim(), idCategoria, incluirInactivos });
    }

    public Task<Articulo?> ArticuloAsync(int id) => db.UnoAsync<Articulo>(@"
        SELECT a.id_articulo, a.id_categoria, c.nombre AS categoria, a.nombre, a.descripcion,
               a.cantidad_total, a.precio_dia, a.activo,
               (SELECT COUNT(*) FROM detalle_reservacion d WHERE d.id_articulo = a.id_articulo) AS veces_rentado
          FROM articulo a JOIN categoria c ON c.id_categoria = a.id_categoria
         WHERE a.id_articulo = @id", new { id });

    public Task<int> CrearArticuloAsync(Articulo a) => db.EscalarAsync<int>(@"
        INSERT INTO articulo (id_categoria, nombre, descripcion, cantidad_total, precio_dia, activo)
        VALUES (@IdCategoria, @Nombre, @Descripcion, @CantidadTotal, @PrecioDia, @Activo);
        SELECT LAST_INSERT_ID();", a);

    // trg_articulo_bu impide reducir el inventario por debajo de lo comprometido
    // trg_articulo_au guarda el historial de precios (la app no lo escribe)
    public Task<int> ActualizarArticuloAsync(Articulo a) => db.EjecutarAsync(@"
        UPDATE articulo
           SET id_categoria = @IdCategoria, nombre = @Nombre, descripcion = @Descripcion,
               cantidad_total = @CantidadTotal, precio_dia = @PrecioDia, activo = @Activo
         WHERE id_articulo = @IdArticulo", a);

    // RN-11: baja lógica
    public Task<int> CambiarActivoArticuloAsync(int id, bool activo) =>
        db.EjecutarAsync("UPDATE articulo SET activo = @activo WHERE id_articulo = @id", new { id, activo });

    // Solo procede si nunca se ha rentado (FK RESTRICT)
    public Task<int> EliminarArticuloAsync(int id) =>
        db.EjecutarAsync("DELETE FROM articulo WHERE id_articulo = @id", new { id });

    public Task<IReadOnlyList<HistorialPrecio>> HistorialPreciosAsync(int? idArticulo = null) => db.ConsultarAsync<HistorialPrecio>(@"
        SELECT a.nombre AS articulo, h.precio_anterior, h.precio_nuevo, h.fecha_cambio, e.nombre AS empleado
          FROM historial_precio h
          JOIN articulo a ON a.id_articulo = h.id_articulo
          LEFT JOIN empleado e ON e.id_empleado = h.id_empleado
         WHERE @idArticulo IS NULL OR h.id_articulo = @idArticulo
         ORDER BY h.fecha_cambio DESC, h.id_historial DESC", new { idArticulo });
}
