namespace Aduax.AuditorDocumentos.VModels
{
    public class PagedRequest
    {
        public string? Filter { get; set; }
        public int Page { get; set; } = 1;
        public int Size { get; set; } = 10;
    }

    public class PagedRequest<T>
    {
        public T? Data { get; set; }
        public int Page { get; set; } = 1;
        public int Size { get; set; } = 10;
    }
}

