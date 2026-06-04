# 🚀 Guía de Implementación: API REST con ASP.NET Core y EF Core

Este documento sirve como guía y plan de desarrollo para implementar la API REST requerida en el proyecto final, utilizando **ASP.NET Core** en **Visual Studio Code (VS Code)** y conectándose a **SQL Server** mediante **Entity Framework Core (EF Core)**.

---

## ❓ ¿Se puede usar EF Core aquí?

**¡Sí, totalmente!** Pero con una condición muy importante impuesta por los requerimientos del curso:

> [!IMPORTANT]
> **Regla de Oro del Proyecto:**
> Las operaciones de inserción, actualización, eliminación y consulta de la tabla de **Productos** **no** deben realizarse usando las consultas automáticas de LINQ (`context.Products.Add()`, `context.SaveChanges()`, etc.).
> 
> **Debes ejecutar los Procedimientos Almacenados y Funciones** que creaste en SQL Server a través de EF Core. EF Core actuará como el puente de conexión y mapeador de los resultados.

---

## 🚀 Estado de la Configuración y Primeros Pasos

El esqueleto inicial del proyecto de la API ya ha sido creado y configurado en la raíz bajo la carpeta `AdventureWorks.API/`.

### 📂 Estructura del Repositorio
* **`AdventureWorks.API/`**: Proyecto Web API en .NET Core.
* **[`.editorconfig`](./.editorconfig)**: Archivo de reglas de formateo (mecanografía de 2 espacios, llaves Same-Line).
* **[`REFERENCE.md`](./REFERENCE.md)**: Requerimientos y rúbrica oficial del curso.
* **[`CODING-STANDARD.md`](./CODING-STANDARD.md)**: Estándar y reglas de codificación en C# y SQL.

---

## 🛠️ Cómo Trabajar en el Proyecto

### 1. Iniciar la API en Desarrollo
Entra a la carpeta del proyecto y arranca la API con recarga automática:
```bash
cd AdventureWorks.API
dotnet watch run
```
*Nota: Esto levantará el servidor en desarrollo y abrirá la documentación de OpenAPI/Swagger automáticamente.*

### 2. Configurar la Base de Datos (`appsettings.json`)
Asegúrate de ajustar la cadena de conexión en `appsettings.json` con tu servidor de base de datos local (o tu contenedor Docker):
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=TU_SERVIDOR;Database=AdventureWorks;Trusted_Connection=True;TrustServerCertificate=True;"
  }
}
```

### 3. Mantener el Formato Limpio
Para asegurar que todo el equipo cumpla con el estándar de código (llaves en la misma línea y 2 espacios de sangría), ejecuten este comando en la terminal antes de hacer un commit:
```bash
dotnet format
```
Esto auto-corregirá el formato de todo el proyecto según las reglas del archivo [`.editorconfig`](./.editorconfig).

---

## 🗄️ Control de Versiones para Base de Datos (Sugerencia)
Para que todo el equipo sincronice la base de datos a la par de la API, se sugiere crear una carpeta llamada `Database/` en la raíz del proyecto para subir los scripts SQL ordenados:
* `Database/01_clean_adventureworks.sql` (Limpieza de stored procedures predeterminados)
* `Database/02_security_users.sql` (Usuarios, roles y permisos)
* `Database/03_scalar_functions.sql` (Funciones de edad, impuesto, etc.)
* `Database/04_views.sql` (Vistas requeridas)
* `Database/05_stored_procedures.sql` (Procedimientos transaccionales CRUD)

---

## 💻 Arquitectura y Código de Ejemplo (Estilo Same-Line)

De acuerdo con el [CODING-STANDARD.md](./CODING-STANDARD.md) del proyecto, el código C# debe seguir la indentación de **2 espacios** y el estilo de llaves **Same-Line** (abrir la llave `{` en la misma línea).

### 1. Modelo de Producto (`Models/Product.cs`)
```csharp
namespace AdventureWorks.API.Models {
  public class Product {
    public int ProductID { get; set; }
    public string Name { get; set; } = string.Empty;
    public string ProductNumber { get; set; } = string.Empty;
    public decimal ListPrice { get; set; }
  }
}
```

### 2. Contexto de Base de Datos (`Data/AppDbContext.cs`)
```csharp
using Microsoft.EntityFrameworkCore;
using AdventureWorks.API.Models;

namespace AdventureWorks.API.Data {
  public class AppDbContext : DbContext {
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<Product> Products { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder) {
      // Mapeamos la entidad Product a la estructura de la base de datos
      modelBuilder.Entity<Product>().HasKey(p => p.ProductID);
    }
  }
}
```

### 3. Registro del Contexto (`Program.cs`)
```csharp
using AdventureWorks.API.Data;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Registrar DbContext
builder.Services.AddDbContext<AppDbContext>(options => {
  options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection"));
});

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

if (app.Environment.IsDevelopment()) {
  app.UseSwagger();
  app.UseSwaggerUI();
}

app.UseAuthorization();
app.MapControllers();
app.Run();
```

---

## ⚡ Ejecución de Procedimientos con EF Core en el Controlador

A continuación se muestra la estructura para tu `ProductsController` adaptada al estándar de codificación del proyecto:

```csharp
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Data;
using AdventureWorks.API.Data;
using AdventureWorks.API.Models;

namespace AdventureWorks.API.Controllers {
  [Route("api/[controller]")]
  [ApiController]
  public class ProductsController : ControllerBase {
    private readonly AppDbContext dbContext;

    public class ApiResponse {
      public int StatusCode { get; set; }
      public string Message { get; set; } = string.Empty;
      public int? NewId { get; set; }
    }

    public ProductsController(AppDbContext dbContext) {
      this.dbContext = dbContext;
    }

    // 1. CONSULTAR UNO O TODOS
    [HttpGet]
    public async Task<IActionResult> GetProducts([FromQuery] int? id) {
      // Llamamos al procedimiento de consulta que maneja ambos casos
      var idParam = new SqlParameter("@ProductID", id ?? (object)DBNull.Value);
      
      var query = dbContext.Products
        .FromSqlRaw("EXEC dbo.sp_GetProducts @ProductID", idParam);

      var result = await query.ToListAsync();

      if (id.HasValue && !result.Any()) {
        return NotFound(new { Message = $"Producto con ID {id} no encontrado." });
      }

      return Ok(result);
    }

    // 2. INSERTAR (POST)
    [HttpPost]
    public async Task<IActionResult> CreateProduct([FromBody] Product product) {
      var nameParam = new SqlParameter("@Name", product.Name);
      var numParam = new SqlParameter("@ProductNumber", product.ProductNumber);
      var priceParam = new SqlParameter("@ListPrice", product.ListPrice);

      var statusParam = new SqlParameter("@StatusCode", SqlDbType.Int) {
        Direction = ParameterDirection.Output
      };
      var msgParam = new SqlParameter("@Message", SqlDbType.VarChar, 250) {
        Direction = ParameterDirection.Output
      };
      var newIdParam = new SqlParameter("@NewId", SqlDbType.Int) {
        Direction = ParameterDirection.Output
      };

      await dbContext.Database.ExecuteSqlRawAsync(
        "EXEC dbo.sp_InsertProduct @Name, @ProductNumber, @ListPrice, @StatusCode OUTPUT, @Message OUTPUT, @NewId OUTPUT",
        nameParam, numParam, priceParam, statusParam, msgParam, newIdParam
      );

      int dbStatusCode = (int)statusParam.Value;
      string dbMessage = (string)msgParam.Value;
      int? newId = newIdParam.Value != DBNull.Value ? (int?)newIdParam.Value : null;

      return ProcessDbResponse(dbStatusCode, dbMessage, newId);
    }

    // 3. ACTUALIZAR (PUT)
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateProduct(int id, [FromBody] Product product) {
      var idParam = new SqlParameter("@ProductID", id);
      var nameParam = new SqlParameter("@Name", product.Name);
      var numParam = new SqlParameter("@ProductNumber", product.ProductNumber);
      var priceParam = new SqlParameter("@ListPrice", product.ListPrice);

      var statusParam = new SqlParameter("@StatusCode", SqlDbType.Int) {
        Direction = ParameterDirection.Output
      };
      var msgParam = new SqlParameter("@Message", SqlDbType.VarChar, 250) {
        Direction = ParameterDirection.Output
      };

      await dbContext.Database.ExecuteSqlRawAsync(
        "EXEC dbo.sp_UpdateProduct @ProductID, @Name, @ProductNumber, @ListPrice, @StatusCode OUTPUT, @Message OUTPUT",
        idParam, nameParam, numParam, priceParam, statusParam, msgParam
      );

      int dbStatusCode = (int)statusParam.Value;
      string dbMessage = (string)msgParam.Value;

      return ProcessDbResponse(dbStatusCode, dbMessage, null);
    }

    // 4. ELIMINAR (DELETE)
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteProduct(int id) {
      var idParam = new SqlParameter("@ProductID", id);
      var statusParam = new SqlParameter("@StatusCode", SqlDbType.Int) {
        Direction = ParameterDirection.Output
      };
      var msgParam = new SqlParameter("@Message", SqlDbType.VarChar, 250) {
        Direction = ParameterDirection.Output
      };

      await dbContext.Database.ExecuteSqlRawAsync(
        "EXEC dbo.sp_DeleteProduct @ProductID, @StatusCode OUTPUT, @Message OUTPUT",
        idParam, statusParam, msgParam
      );

      int dbStatusCode = (int)statusParam.Value;
      string dbMessage = (string)msgParam.Value;

      return ProcessDbResponse(dbStatusCode, dbMessage, null);
    }

    // Helper para procesar la respuesta basada en el código de estado devuelto por SQL Server
    private IActionResult ProcessDbResponse(int statusCode, string message, int? newId) {
      var response = new ApiResponse {
        StatusCode = statusCode,
        Message = message,
        NewId = newId
      };

      switch (statusCode) {
        case 200: {
          return Ok(response);
        }
        case 400: {
          return BadRequest(response);
        }
        case 404: {
          return NotFound(response);
        }
        case 500: {
          return StatusCode(500, response);
        }
        default: {
          return StatusCode(statusCode, response);
        }
      }
    }
  }
}
```

---

## 💡 Ventajas de usar EF Core para esto
1. **Inyección de Dependencias nativa:** Te facilita inyectar la conexión de base de datos en los controladores de ASP.NET Core de forma limpia.
2. **Mapeo de Consultas (`FromSqlRaw`):** Mapea automáticamente el set de datos devuelto por la base de datos hacia objetos C# (`Product`), evitando que tengas que leer manualmente el `SqlDataReader`.
3. **Mantenibilidad:** Si más adelante necesitas añadir logs o migraciones, la infraestructura ya está en su lugar.
