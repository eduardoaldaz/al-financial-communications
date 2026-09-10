reportextension 50300 "GFL Customer Aging Ext." extends "Customer Detailed Aging"
{
    dataset
    {
        // ── Columnas extra sobre el DataItem existente de vencidas ───────────
        add("Cust. Ledger Entry")
        {
            column(VAT_No; Customer."VAT Registration No.") { }
            column(Address; Customer.Address) { }
            column(City; Customer.City) { }
            column(PostCode; Customer."Post Code") { }
            column(Country; Customer."Country/Region Code") { }
            column(GFLDocumentType; "Document Type") { }
            column(YourReference; "Your Reference") { }
        }

        modify("Cust. Ledger Entry")
        {
            trigger OnBeforeAfterGetRecord()
            begin
                if not ("Document Type" in ["Document Type"::Invoice, "Document Type"::"Credit Memo"]) then
                    CurrReport.Skip();
            end;
        }

        // ── Datos de empresa (hijo de Cust. Ledger Entry) ────────────────────
        // Company Information tiene siempre 1 registro. Al ser hijo de CLE,
        // emite una fila por entrada vencida. El RDLC usa First() para obtener
        // el primer valor — funciona correctamente.
        // La tablix principal (Table1) lleva filtro adicional para excluir
        // estas filas del informe de vencidas (EmpresaNombre = nothing).
        addlast("Cust. Ledger Entry")
        {
            dataitem(GFLCompanyInfo; "Company Information")
            {
                DataItemTableView = sorting("Primary Key");

                column(EmpresaNombre; Name) { }
                column(EmpresaDireccion; Address) { }
                column(EmpresaPostCode; "Post Code") { }
                column(EmpresaCiudad; City) { }
                column(EmpresaPais; "Country/Region Code") { }
                column(EmpresaVAT; "VAT Registration No.") { }
            }
        }

        // ── Facturas abiertas NO vencidas (hijo de Customer) ─────────────────
        // Completamente separado del DataItem de vencidas — no afecta los
        // totales TempCurrencyTotalBuffer ni la lógica existente.
        addlast(Customer)
        {
            dataitem(GFLOpenEntry; "Cust. Ledger Entry")
            {
                DataItemLink = "Customer No." = field("No.");
                DataItemLinkReference = Customer;
                DataItemTableView = sorting("Customer No.", "Currency Code", "Due Date")
                                   where(Open = const(true));

                trigger OnPreDataItem()
                var
                    Setup: Record "GFL Fin. Comm. Setup";
                    CutoffDate: Date;
                begin
                    Setup.GetSetup();
                    CutoffDate := CalcDate(StrSubstNo('<-%1D>', Setup."Overdue Days Threshold"), WorkDate());
                    SetFilter("Due Date", '>%1', CutoffDate);
                    SetFilter("Document Type", '%1|%2',
                        "Document Type"::Invoice,
                        "Document Type"::"Credit Memo");
                end;

                trigger OnAfterGetRecord()
                begin
                    CalcFields("Remaining Amount");
                end;

                column(GFLOpen_DocumentNo; "Document No.") { }
                column(GFLOpen_DocumentType; "Document Type") { }
                column(GFLOpen_PostingDate; "Posting Date") { }
                column(GFLOpen_DueDate; "Due Date") { }
                column(GFLOpen_Description; Description) { }
                column(GFLOpen_YourReference; "Your Reference") { }
                column(GFLOpen_RemainingAmount; "Remaining Amount") { }
                column(GFLOpen_CurrencyCode; "Currency Code") { }
            }
        }
    }
}
