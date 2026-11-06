import { useMemo, useState } from "react";
import "./TagInput.css";

const splitValue = (value, separators) => {
  if (typeof value !== "string") {
    return [];
  }
  const hasSpace = separators.includes(" ");
  const hasSemicolon = separators.includes(";");
  if (hasSpace && hasSemicolon) {
    return value
      .split(/[;\s]+/)
      .map((item) => item.trim())
      .filter(Boolean);
  }
  if (hasSpace) {
    return value
      .split(/\s+/)
      .map((item) => item.trim())
      .filter(Boolean);
  }
  return value
    .split(";")
    .map((item) => item.trim())
    .filter(Boolean);
};

const joinValue = (tags, joinWith) => tags.join(joinWith);

export default function TagInput({
  value = "",
  onChange,
  placeholder,
  disabled = false,
  separators = [";"],
  joinWith = ";",
  sanitizeInput,
}) {
  const [inputValue, setInputValue] = useState("");
  const tags = useMemo(() => splitValue(value, separators), [value, separators]);

  const cleanInput = (text) =>
    sanitizeInput ? sanitizeInput(String(text ?? "")) : String(text ?? "");

  const commitTags = (nextTags) => {
    if (disabled) {
      return;
    }
    if (onChange) {
      onChange(joinValue(nextTags, joinWith));
    }
  };

  const addFromInput = (rawValue) => {
    const parts = splitValue(cleanInput(rawValue), separators);
    if (!parts.length) {
      return false;
    }
    commitTags([...tags, ...parts]);
    return true;
  };

  const handleKeyDown = (event) => {
    if (disabled) {
      return;
    }
    const isSeparatorKey = separators.includes(event.key);
    if (isSeparatorKey || event.key === "Enter") {
      event.preventDefault();
      if (addFromInput(inputValue)) {
        setInputValue("");
      }
      return;
    }
    if (event.key === "Backspace" && !inputValue) {
      if (tags.length) {
        commitTags(tags.slice(0, -1));
      }
    }
  };

  const handleBlur = () => {
    if (disabled) {
      return;
    }
    if (addFromInput(inputValue)) {
      setInputValue("");
    }
  };

  const handlePaste = (event) => {
    if (disabled) {
      return;
    }
    const text = cleanInput(event.clipboardData.getData("text"));
    const hasSeparator = separators.some((sep) =>
      sep === " " ? /\s/.test(text) : text.includes(sep)
    );
    if (!text || !hasSeparator) {
      return;
    }
    event.preventDefault();
    const combined = cleanInput(`${inputValue}${text}`);
    if (addFromInput(combined)) {
      setInputValue("");
    }
  };

  const removeTag = (index) => {
    commitTags(tags.filter((_, idx) => idx !== index));
  };

  return (
    <div className={`tag-input ${disabled ? "disabled" : ""}`}>
      {tags.map((tag, index) => (
        <span key={`${tag}-${index}`} className="tag-chip">
          {tag}
          <button
            type="button"
            className="tag-remove"
            onClick={() => removeTag(index)}
            disabled={disabled}
            aria-label={`Eliminar ${tag}`}
          >
            ×
          </button>
        </span>
      ))}
      <input
        className="tag-input-field"
        type="text"
        value={inputValue}
        onChange={(event) => setInputValue(cleanInput(event.target.value))}
        onKeyDown={handleKeyDown}
        onBlur={handleBlur}
        onPaste={handlePaste}
        placeholder={tags.length ? "" : placeholder}
        disabled={disabled}
      />
    </div>
  );
}
