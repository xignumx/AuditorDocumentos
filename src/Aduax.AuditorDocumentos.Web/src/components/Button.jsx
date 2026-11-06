import "./Button.css";

export default function Button({
  children,
  variant = "primary",
  icon,
  onClick,
  disabled = false,
  type = "button",
}) {
  return (
    <button
      type={type}
      className={`oc-button oc-button-${variant}`}
      onClick={onClick}
      disabled={disabled}
    >
      {icon && <span className="oc-button-icon">{icon}</span>}
      <span>{children}</span>
    </button>
  );
}
