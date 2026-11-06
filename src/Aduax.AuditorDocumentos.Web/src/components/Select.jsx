import { useState, useRef, useEffect } from "react";
import "./Select.css";

export default function Select({
  options = [],
  value,
  onChange,
  placeholder = "Seleccione una opción...",
  disabled = false,
}) {
  const [isOpen, setIsOpen] = useState(false);
  const selectRef = useRef(null);

  const selectedOption = options.find((opt) => opt.value === value);

  useEffect(() => {
    const handleClickOutside = (event) => {
      if (selectRef.current && !selectRef.current.contains(event.target)) {
        setIsOpen(false);
      }
    };

    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const handleSelect = (option) => {
    onChange?.(option.value);
    setIsOpen(false);
  };

  return (
    <div
      ref={selectRef}
      className={`oc-dropdown-select ${disabled ? "disabled" : ""} ${isOpen ? "open" : ""}`}
    >
      <div
        className={`select-selected ${isOpen ? "select-arrow-active" : ""}`}
        onClick={() => !disabled && setIsOpen(!isOpen)}
      >
        <span className={selectedOption ? "has-value" : "placeholder"}>
          {selectedOption ? selectedOption.label : placeholder}
        </span>
        <svg
          className="select-arrow"
          width="12"
          height="8"
          viewBox="0 0 12 8"
          fill="none"
        >
          <path
            d="M1 1.5L6 6.5L11 1.5"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </div>
      {isOpen && !disabled && (
        <div className="select-items">
          {options.map((option) => (
            <div
              key={option.value}
              className={`select-item ${value === option.value ? "same-as-selected" : ""}`}
              onClick={() => handleSelect(option)}
            >
              {option.label}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
