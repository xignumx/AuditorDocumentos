import { useState } from "react";
import { PageHeader, VucemDocumentSelector } from "../components";
import IaDictionaryTab from "../components/iaRules/IaDictionaryTab";
import IaHistoryTab from "../components/iaRules/IaHistoryTab";
import IaPromptsTab from "../components/iaRules/IaPromptsTab";
import { IaDiccionarioCategoria } from "../constants/iaRules";
import "./IaRulesPage.css";

const SparkIcon = () => (
  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <path d="M12 3l1.9 5.1L19 10l-5.1 1.9L12 17l-1.9-5.1L5 10l5.1-1.9z" />
    <path d="M19 15l.9 2.1L22 18l-2.1.9L19 21l-.9-2.1L16 18l2.1-.9z" />
  </svg>
);

const TABS = [
  { id: "prompts", label: "Prompts" },
  { id: "diccionario", label: "Diccionario" },
  { id: "um", label: "Equivalencias UM" },
  { id: "historial", label: "Historial" },
];

/**
 * Reglas de IA (solo Compliance): prompts por tipo VUCEM, diccionario de sinónimos ES/EN,
 * equivalencias de unidad de medida e historial de versiones.
 */
export default function IaRulesPage() {
  const [selectedDocument, setSelectedDocument] = useState(null);
  const [activeTab, setActiveTab] = useState("prompts");

  return (
    <div className="ia-rules-page">
      <PageHeader
        icon={<SparkIcon />}
        title="Reglas de IA"
        subtitle="Prompts, diccionario de sinónimos y equivalencias de unidad de medida"
      />

      <div className="ia-rules-layout">
        <VucemDocumentSelector
          className="ia-rules-sidebar"
          value={selectedDocument}
          onChange={setSelectedDocument}
        />

        <div className="ia-rules-main">
          <div className="ia-tabs" role="tablist">
            {TABS.map((tab) => (
              <button
                key={tab.id}
                type="button"
                role="tab"
                aria-selected={activeTab === tab.id}
                className={`ia-tab ${activeTab === tab.id ? "active" : ""}`}
                onClick={() => setActiveTab(tab.id)}
              >
                {tab.label}
              </button>
            ))}
          </div>

          {activeTab === "prompts" && <IaPromptsTab selectedDocument={selectedDocument} />}
          {activeTab === "diccionario" && (
            <IaDictionaryTab categoria={IaDiccionarioCategoria.General} />
          )}
          {activeTab === "um" && (
            <IaDictionaryTab categoria={IaDiccionarioCategoria.UnidadMedida} />
          )}
          {activeTab === "historial" && <IaHistoryTab selectedDocument={selectedDocument} />}
        </div>
      </div>
    </div>
  );
}
