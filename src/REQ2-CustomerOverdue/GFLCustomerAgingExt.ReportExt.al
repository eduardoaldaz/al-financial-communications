reportextension 50300 "GFL Customer Aging Ext." extends "Customer Detailed Aging"
{
    dataset
    {
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
    }

    // Funciones locales para obtener datos de la empresa
    local procedure GetEmpresaNombre(): Text[100]
    var
        Company: Record "Company Information";
    begin
        if Company.Get() then
            exit(Company.Name);  // <-- CORRECTO: el campo se llama "Name"
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