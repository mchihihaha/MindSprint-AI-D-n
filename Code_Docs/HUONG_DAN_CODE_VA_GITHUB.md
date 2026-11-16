# HƯỚNG DẪN MÃ NGUỒN (CODE) & QUẢN TRỊ GITHUB — DỰ ÁN MINDSPRINT AI

* **Kho lưu trữ GitHub:** [https://github.com/tungtungsahul/MindSprint-AI-D-n](https://github.com/tungtungsahul/MindSprint-AI-D-n)
* **Công nghệ cốt lõi:** ASP.NET Core 8 (.NET 8), Entity Framework Core 8, PostgreSQL 17, HTML5/CSS3/Vanilla JS ES6+.

---

## 1. CONNECT DB — KẾT NỐI CƠ SỞ DỮ LIỆU POSTGRESQL

Hệ thống sử dụng Entity Framework Core 8 kết hợp với bộ điều khiển dữ liệu `Npgsql.EntityFrameworkCore.PostgreSQL`.

### 1.1. Cấu hình Chuỗi kết nối (Connection String)
Chuỗi kết nối được quản lý linh hoạt thông qua `appsettings.json` cho môi trường phát triển cục bộ và biến môi trường `DATABASE_URL` (hoặc `ConnectionStrings__DefaultConnection`) khi triển khai trên nền tảng đám mây Render:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Port=5432;Database=mindsprint;Username=postgres;Password=your_secure_password;Maximum Pool Size=50;Pooling=true;SSL Mode=Prefer;"
  }
}
```

### 1.2. Đăng ký DbContext trong `Program.cs`
Trong tệp khởi động `backend/MindSprint.Api/Program.cs`, dịch vụ `AppDbContext` được đăng ký vào thùng chứa phụ thuộc (IoC Container):

```csharp
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection") 
    ?? Environment.GetEnvironmentVariable("DATABASE_URL");

builder.Services.AddDbContext<AppDbContext>(options =>
{
    options.UseNpgsql(connectionString, npgsqlOptions =>
    {
        npgsqlOptions.EnableRetryOnFailure(
            maxRetryCount: 5,
            maxRetryDelay: TimeSpan.FromSeconds(10),
            errorCodesToAdd: null);
        npgsqlOptions.CommandTimeout(30);
    });
});
```

### 1.3. Lớp ngữ cảnh dữ liệu `AppDbContext.cs`
Định nghĩa tập hợp các bảng dữ liệu (`DbSet<T>`) và các ràng buộc toàn vẹn:

```csharp
namespace MindSprint.Api.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<Flashcard> Flashcards => Set<Flashcard>();
    public DbSet<CardProgress> CardProgresses => Set<CardProgress>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<Notebook> Notebooks => Set<Notebook>();
    public DbSet<NotebookSource> NotebookSources => Set<NotebookSource>();
    public DbSet<NotebookNote> NotebookNotes => Set<NotebookNote>();
    public DbSet<NotebookGenerationCache> NotebookGenerationCaches => Set<NotebookGenerationCache>();
    public DbSet<KanbanTask> Tasks => Set<KanbanTask>();
    public DbSet<UserStudyDay> UserStudyDays => Set<UserStudyDay>();
    public DbSet<StudySchedule> StudySchedules => Set<StudySchedule>();
    public DbSet<WeakArea> WeakAreas => Set<WeakArea>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        // Ràng buộc chỉ mục duy nhất
        b.Entity<User>().HasIndex(u => u.Email).IsUnique();
        b.Entity<Flashcard>().HasIndex(f => f.ExternalId).IsUnique();
        b.Entity<CardProgress>().HasIndex(p => new { p.UserId, p.FlashcardId }).IsUnique();

        // Khóa ngoại và quan hệ xóa tầng Cascade
        b.Entity<Flashcard>().HasOne(f => f.Owner)
            .WithMany()
            .HasForeignKey(f => f.OwnerId)
            .OnDelete(DeleteBehavior.Cascade);

        // Kiểm soát tương tranh lạc quan (Optimistic Concurrency Control)
        b.Entity<Flashcard>().Property(f => f.Version).IsConcurrencyToken();
        b.Entity<Flashcard>().Property(f => f.UpdatedAt).IsConcurrencyToken();
    }
}
```

---

## 2. CRUD QUẢN LÝ SẢN PHẨM / THẺ HỌC (FLASHCARD ITEMS)

Toàn bộ thao tác nghiệp vụ Quản lý Thẻ học (Thêm, Đọc, Sửa, Xóa) được đóng gói trong bộ điều khiển `FlashcardsController.cs` với kiểm soát bảo mật và cô lập quyền sở hữu:

### 2.1. Đọc danh sách Thẻ học có phân loại & tìm kiếm (READ)
```csharp
[Authorize, HttpGet]
public async Task<IActionResult> GetAll([FromQuery] string? category, [FromQuery] string? subCategory)
{
    var uid = UserId; // Lấy từ ClaimsPrincipal của JWT
    
    // Thẻ hệ thống (OwnerId == null) hoặc thẻ của chính người dùng đăng nhập
    var q = db.Flashcards.AsNoTracking().Where(f => (f.OwnerId == null || f.OwnerId == uid) && f.OwnerId != -1);
    
    if (!string.IsNullOrEmpty(category) && category != "all") 
        q = q.Where(f => f.Category == category);
    if (!string.IsNullOrEmpty(subCategory) && subCategory != "all") 
        q = q.Where(f => f.SubCategory == subCategory);

    var rows = await q.GroupJoin(db.CardProgresses.Where(p => p.UserId == uid), 
            f => f.Id, p => p.FlashcardId,
            (f, ps) => new { f, p = ps.FirstOrDefault() })
        .Select(x => new CardResponse
        {
            Id = x.f.ExternalId,
            Category = x.f.Category,
            SubCategory = x.f.SubCategory,
            Question = x.f.Question,
            Answer = x.f.Answer,
            Example = x.f.Example,
            Status = x.p != null ? x.p.Status : "new",
            Repetition = x.p != null ? x.p.Repetition : 0,
            Interval = x.p != null ? x.p.IntervalDays : 1,
            EFactor = x.p != null ? x.p.EFactor : 2.5,
            Version = x.f.Version,
            UpdatedAt = x.f.UpdatedAt
        }).ToListAsync();

    return Ok(rows);
}
```

### 2.2. Thêm mới Sản phẩm / Thẻ học (CREATE)
```csharp
[Authorize, HttpPost]
public async Task<IActionResult> Create([FromBody] CardDto dto)
{
    var card = new Flashcard
    {
        Category = dto.Category,
        SubCategory = dto.SubCategory,
        Question = dto.Question,
        Answer = dto.Answer,
        Example = dto.Example,
        OwnerId = UserId, // Gán chủ sở hữu là người tạo
        UpdatedAt = DateTime.UtcNow,
        Version = 1
    };
    if (!string.IsNullOrWhiteSpace(dto.ExternalId)) 
        card.ExternalId = dto.ExternalId;

    db.Flashcards.Add(card);
    await db.SaveChangesAsync();

    return Ok(new { id = card.ExternalId, version = card.Version, updatedAt = card.UpdatedAt });
}
```

### 2.3. Cập nhật Sản phẩm / Thẻ học kèm kiểm soát tương tranh (UPDATE)
```csharp
[Authorize, HttpPut("{externalId}")]
public async Task<IActionResult> Update(string externalId, [FromBody] CardDto dto)
{
    var card = await db.Flashcards.FirstOrDefaultAsync(f => f.ExternalId == externalId && f.OwnerId == UserId);
    if (card is null) return NotFound();

    // Kiểm tra Optimistic Concurrency Token
    if (dto.Version.HasValue && dto.Version.Value != card.Version)
        return CardConflict(card);

    card.Category = dto.Category;
    card.SubCategory = dto.SubCategory;
    card.Question = dto.Question;
    card.Answer = dto.Answer;
    card.Example = dto.Example;
    card.Version++; // Tăng phiên bản sau mỗi lần cập nhật
    card.UpdatedAt = DateTime.UtcNow;

    try 
    { 
        await db.SaveChangesAsync(); 
    }
    catch (DbUpdateConcurrencyException) 
    { 
        return await ReloadConflict(card); 
    }

    return Ok(new { version = card.Version, updatedAt = card.UpdatedAt });
}
```

### 2.4. Xóa Sản phẩm / Thẻ học (DELETE)
```csharp
[Authorize, HttpDelete("{externalId}")]
public async Task<IActionResult> Delete(string externalId, [FromQuery] int? version)
{
    var card = await db.Flashcards.FirstOrDefaultAsync(f => f.ExternalId == externalId && f.OwnerId == UserId);
    if (card is null) return NotFound();

    if (version.HasValue && version.Value != card.Version)
    {
        return Conflict(new { message = "Thẻ đã được thay đổi. Vui lòng tải lại.", serverVersion = card.Version });
    }

    db.Flashcards.Remove(card);
    try 
    { 
        await db.SaveChangesAsync(); 
    }
    catch (DbUpdateConcurrencyException) 
    { 
        return await ReloadConflict(card); 
    }

    return NoContent();
}
```

---

## 3. Đối chiếu đóng góp trên GitHub

Mỗi báo cáo cá nhân liên kết tới issue và bằng chứng bàn giao của thành viên nhóm Lập trình Web.

| Thành viên | Tài khoản GitHub | Báo cáo cá nhân |
| --- | --- | --- |
| Nguyễn Trần Bảo Duy | [@tungtungsahul](https://github.com/tungtungsahul) | [Xem báo cáo](../Bao_cao/bc_NguyenTranBaoDuy.md) |
| Đỗ Đình Phan Diễn | [@phandien665-prog](https://github.com/phandien665-prog) | [Xem báo cáo](../Bao_cao/bc_DoDinhPhanDien.md) |
| Vũ Đình Hùng | [@James-Lloyd20](https://github.com/James-Lloyd20) | [Xem báo cáo](../Bao_cao/bc_VuDinhHung.md) |
| Nguyễn Minh Chiến | [@mchihihaha](https://github.com/mchihihaha) | [Xem báo cáo](../Bao_cao/bc_MinhChien.md) |
| Nguyễn Tuấn Linh | [@tuanlinh0511](https://github.com/tuanlinh0511) | [Xem báo cáo](../Bao_cao/bc_TuanLinh.md) |
