import Toggle from "./Toggle";
import "./FieldCard.css";

export default function FieldCard({
  icon,
  label,
  visible,
  onVisibleChange,
  obligatory,
  onObligatoryChange,
  disableObligatory = false,
}) {
  return (
    <div className="field-card oc-light-card">
      <div className="field-card-header">
        {icon && <span className="field-card-icon">{icon}</span>}
        <span className="field-card-label">{label}</span>
      </div>
      <div className="field-card-toggles">
        <Toggle
          checked={visible}
          onChange={onVisibleChange}
          label="Visible"
        />
        <Toggle
          checked={obligatory}
          onChange={onObligatoryChange}
          label="Obligatorio"
          disabled={disableObligatory}
        />
      </div>
    </div>
  );
}
