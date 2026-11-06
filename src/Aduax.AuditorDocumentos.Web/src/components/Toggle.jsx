import "./Toggle.css";

export default function Toggle({ checked, onChange, label, disabled = false }) {
  return (
    <label className={`toggle-wrapper ${disabled ? "disabled" : ""}`}>
      <div className={`toggle ${checked ? "active" : ""}`}>
        <input
          type="checkbox"
          checked={checked}
          onChange={(e) => onChange?.(e.target.checked)}
          disabled={disabled}
        />
        <span className="toggle-slider"></span>
      </div>
      {label && <span className="toggle-label">{label}</span>}
    </label>
  );
}
