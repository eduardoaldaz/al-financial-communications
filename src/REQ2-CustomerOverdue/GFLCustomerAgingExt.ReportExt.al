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

        // ── Nuevos DataItems hijos de Customer ───────────────────────────────
        // addlast() es el keyword correcto; solo un bloque por DataItem padre.
        addlast(Customer)
        {
            // Datos de empresa: Company Information tiene siempre 1 registro.
            // Las columnas referencian campos reales de tabla (evita el problema
            // de scope de llamadas a procedimientos en reportextension).
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

            // Facturas abiertas NO vencidas: completamente separado del DataItem
            // de vencidas — no afecta TempCurrencyTotalBuffer ni lógica existente.
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
