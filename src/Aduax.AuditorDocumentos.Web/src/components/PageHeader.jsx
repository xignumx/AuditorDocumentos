import "./PageHeader.css";

export default function PageHeader({ icon, title, subtitle }) {
  return (
    <header className="page-header">
      <div className="page-header-content">
        {icon && <span className="page-header-icon">{icon}</span>}
        <div className="page-header-text">
          <h1 className="page-header-title">{title}</h1>
          {subtitle && <p className="page-header-subtitle">{subtitle}</p>}
        </div>
      </div>
    </header>
  );
}
