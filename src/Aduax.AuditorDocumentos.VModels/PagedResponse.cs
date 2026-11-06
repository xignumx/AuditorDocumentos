namespace Aduax.AuditorDocumentos.VModels
{
    public class PagedResponse<T>
    {
        public List<T> Data { get; set; } = new();
        public int Page { get; set; }
        public int Size { get; set; }
        public int TotalRecords { get; set; }
        public int TotalPages { get; set; }
        public bool More { get; set; }
    }
}

