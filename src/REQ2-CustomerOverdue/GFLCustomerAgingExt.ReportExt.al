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

            // Columnas de la empresa con nombres únicos (evitan conflicto)
            column(EmpresaNombre; GetEmpresaNombre()) { }
            column(EmpresaDireccion; GetEmpresaDireccion()) { }
            column(EmpresaPostCode; GetEmpresaPostCode()) { }
            column(EmpresaCiudad; GetEmpresaCiudad()) { }
            column(EmpresaPais; GetEmpresaPais()) { }
            column(EmpresaVAT; GetEmpresaVAT()) { }
        }

        modify("Cust. Ledger Entry")
        {
            trigger OnBeforeAfterGetRecord()
            begin
                if not ("Document Type" in ["Document Type"::Invoice, "Document Type"::"Credit Memo"]) then
                    CurrReport.Skip();
            end;
        }

        // ── Nuevo DataItem: facturas abiertas NO vencidas ────────────────────
        // Completamente separado del DataItem de vencidas — no afecta los
        // totales TempCurrencyTotalBuffer ni la lógica existente.
        add(Customer)
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
                    // Solo facturas/notas de crédito con Due Date > CutoffDate
                    // (el mismo umbral que separa vencidas de no vencidas)
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

    // ── Funciones locales para datos de la empresa ───────────────────────────

    local procedure GetEmpresaNombre(): Text[100]
    var
        Company: Record "Company Information";
    begin
        if Company.Get() then
            exit(Company.Name);
        exit('');
    end;

    local procedure GetEmpresaDireccion(): Text[100]
    var
        Company: Record "Company Information";
    begin
        if Company.Get() then
            exit(Company.Address);
        exit('');
    end;

    local procedure GetEmpresaPostCode(): Code[20]
    var
        Company: Record "Company Information";
    begin
        if Company.Get() then
            exit(Company."Post Code");
        exit('');
    end;

    local procedure GetEmpresaCiudad(): Text[30]
    var
        Company: Record "Company Information";
    begin
        if Company.Get() then
            exit(Company.City);
        exit('');
    end;

    local procedure GetEmpresaPais(): Code[10]
    var
        Company: Record "Company Information";
    begin
        if Company.Get() then
            exit(Company."Country/Region Code");
        exit('');
    end;

    local procedure GetEmpresaVAT(): Text[20]
    var
        Company: Record "Company Information";
    begin
        if Company.Get() then
            exit(Company."VAT Registration No.");
        exit('');
    end;
}
