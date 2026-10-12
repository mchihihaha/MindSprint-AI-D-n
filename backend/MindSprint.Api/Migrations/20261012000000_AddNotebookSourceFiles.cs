using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using MindSprint.Api.Data;

namespace MindSprint.Api.Migrations;

[DbContext(typeof(AppDbContext)), Migration("20261012000000_AddNotebookSourceFiles")]
public class AddNotebookSourceFiles : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<byte[]>(name: "FileBytes", table: "NotebookSources", type: "varbinary(max)", nullable: true);
        migrationBuilder.AddColumn<string>(name: "FileMediaType", table: "NotebookSources", type: "nvarchar(max)", nullable: true);
    }
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropColumn(name: "FileBytes", table: "NotebookSources");
        migrationBuilder.DropColumn(name: "FileMediaType", table: "NotebookSources");
    }
}
