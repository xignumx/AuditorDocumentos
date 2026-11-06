import "./RadioGroup.css";

export default function RadioGroup({ name, options, value, onChange }) {
  return (
    <div className="radio-group">
      {options.map((option) => (
        <label key={option.value} className="radio-option">
          <input
            type="radio"
            name={name}
            value={option.value}
            checked={value === option.value}
            onChange={(e) => onChange?.(e.target.value)}
          />
          <span className="radio-custom"></span>
          <span className="radio-label">{option.label}</span>
        </label>
      ))}
    </div>
  );
}
