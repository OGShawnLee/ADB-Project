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

## 🛠️ Configuración del Proyecto en Visual Studio Code

### 1. Crear el Proyecto
Abre tu terminal y ejecuta los siguientes comandos para crear la estructura del proyecto usando la interfaz de línea de comandos de .NET (CLI):
```bash
# Crear un nuevo proyecto Web API con controladores
dotnet new webapi -o AdventureWorks.API --use-controllers

# Entrar a la carpeta del proyecto
cd AdventureWorks.API
```
*Nota: Para trabajar de forma cómoda en VS Code, se recomienda instalar la extensión **C# Dev Kit** oficial de Microsoft.*

### 2. Instalar Paquetes de NuGet
Instala los proveedores necesarios para conectarte a SQL Server y habilitar las herramientas de diseño ejecutando en la terminal:
```bash
dotnet add package Microsoft.EntityFrameworkCore.SqlServer
dotnet add package Microsoft.EntityFrameworkCore.Design
```

### 3. Configurar la Cadena de Conexión (`appsettings.json`)
Añade la conexión a tu servidor local de SQL Server en el archivo `appsettings.json`:
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=TU_SERVIDOR;Database=AdventureWorks;Trusted_Connection=True;TrustServerCertificate=True;"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
```

### 4. Ejecutar el Proyecto
Para compilar y arrancar la API con recarga en vivo (hot reload) mientras programas, ejecuta:
```bash
dotnet watch run
```
Esto abrirá automáticamente el navegador en la interfaz de Swagger (generalmente en `http://localhost:5XXX/swagger`).

---

## 💻 Arquitectura y Código de Ejemplo (Estilo Same-Line)

De acuerdo con el [CODING-STANDARD.md](file:///c:/Users/OGSha/OneDrive/Escritorio/Developer/Web%20Development/ADB-Project/CODING-STANDARD.md) del proyecto, el código C# debe seguir la indentación de **2 espacios** y el estilo de llaves **Same-Line** (abrir la llave `{` en la misma línea).

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
