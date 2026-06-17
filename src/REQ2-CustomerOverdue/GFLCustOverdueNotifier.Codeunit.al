codeunit 50300 "GFL Cust. Overdue Notifier"
{
    // REQ 2: Envío programado de extracto de deuda pendiente a clientes
    // Producción: Job Queue los días 1 y 15 de cada mes
    // Idioma del email determinado por Language Code del cliente (ENU/ESP/FRA/DEU)
    // Report y email destino obtenidos de Custom Report Selection (C.Statement) cuando existe

    trigger OnRun()
    begin
        SendOverdueNotifications();
    end;

    // --- Public ---

    procedure SendForCustomer(Customer: Record Customer)
    var
        Setup: Record "GFL Fin. Comm. Setup";
        CutoffDate: Date;
        ReportId: Integer;
        SendToEmail: Text[250];
        LanguageCode: Code[10];
    begin
        Setup.GetSetup();
        ValidateSetup(Setup);
        CutoffDate := CalcDate(StrSubstNo('<-%1D>', Setup."Overdue Days Threshold"), WorkDate());

        ResolveCustomerConfig(Customer, Setup, ReportId, SendToEmail, LanguageCode);

        if SendToEmail = '' then begin
            Message('El cliente %1 (%2) no tiene email configurado.', Customer."No.", Customer.Name);
            exit;
        end;

        if not CustomerHasOverdueEntries(Customer."No.", CutoffDate) then begin
            Message('El cliente %1 (%2) no tiene movimientos vencidos con más de %3 días de antigüedad.',
                Customer."No.", Customer.Name, Setup."Overdue Days Threshold");
            exit;
        end;

        if TrySendReportToCustomer(Customer, ReportId, SendToEmail, LanguageCode, CutoffDate, Setup) then
            Message('Email enviado correctamente a %1 (%2) → %3.', Customer."No.", Customer.Name, SendToEmail)
        else
            Message('Error al enviar email a %1 (%2).', Customer."No.", Customer.Name);
    end;

    procedure SendOverdueNotifications()
    begin
        RunOverdueNotifications(false);
    end;

    procedure SendOverdueNotificationsForced()
    begin
        RunOverdueNotifications(true);
    end;

    local procedure RunOverdueNotifications(SkipChecks: Boolean)
    var
        Setup: Record "GFL Fin. Comm. Setup";
        Customer: Record Customer;
        CutoffDate: Date;
        CustomersProcessed, CustomersSent, CustomersSkipped, CustomersError : Integer;
        Result: Integer;
    begin
        Setup.GetSetup();

        if not SkipChecks then begin
            if not Setup."Customer Overdue Enabled" then
                exit;
            if not (Date2DMY(WorkDate(), 1) in [1, 15]) then
                exit;
        end;

        ValidateSetup(Setup);
        CutoffDate := CalcDate(StrSubstNo('<-%1D>', Setup."Overdue Days Threshold"), WorkDate());

        if SkipChecks and AnyCustomerSentToday() then
            if not Confirm('Los extractos ya se enviaron hoy. ¿Desea enviarlos de nuevo?', false) then
                exit;

        Customer.SetRange("Print Statements", true);
        if Customer.FindSet() then
            repeat
                CustomersProcessed += 1;
                Result := ProcessCustomer(Customer, CutoffDate, Setup, SkipChecks);
                case Result of
                    1:
                        CustomersSent += 1;
                    2:
                        CustomersError += 1;
                    else
                        CustomersSkipped += 1;
                end;
                Commit();
            until Customer.Next() = 0;

        LogMessage(StrSubstNo(
            'Proceso REQ2 completado. Revisados: %1, Enviados: %2, Omitidos: %3, Errores: %4',
            CustomersProcessed, CustomersSent, CustomersSkipped, CustomersError));
    end;

    // --- Local ---

    local procedure ProcessCustomer(Customer: Record Customer; CutoffDate: Date; Setup: Record "GFL Fin. Comm. Setup"; SkipChecks: Boolean): Integer
    var
        ReportId: Integer;
        SendToEmail: Text[250];
        LanguageCode: Code[10];
    begin
        // En modo automático (Job Queue), saltar clientes ya enviados hoy
        if not SkipChecks then
            if Customer."GFL Last Statement Sent Date" = WorkDate() then
                exit(0);

        ResolveCustomerConfig(Customer, Setup, ReportId, SendToEmail, LanguageCode);

        if SendToEmail = '' then begin
            LogMessage(StrSubstNo('Cliente %1 (%2) sin email - omitido.', Customer."No.", Customer.Name));
            exit(0);
        end;

        if not CustomerHasOverdueEntries(Customer."No.", CutoffDate) then
            exit(0);

        if TrySendReportToCustomer(Customer, ReportId, SendToEmail, LanguageCode, CutoffDate, Setup) then begin
            UpdateLastSentDate(Customer);
            exit(1);
        end;

        LogMessage(StrSubstNo('Error enviando a cliente %1 (%2).', Customer."No.", Customer.Name));
        exit(2);
    end;

    local procedure AnyCustomerSentToday(): Boolean
    var
        Customer: Record Customer;
    begin
        Customer.SetRange("Print Statements", true);
        Customer.SetRange("GFL Last Statement Sent Date", WorkDate());
        exit(not Customer.IsEmpty());
    end;

    local procedure UpdateLastSentDate(var Customer: Record Customer)
    begin
        Customer."GFL Last Statement Sent Date" := WorkDate();
        Customer.Modify();
    end;

    local procedure ResolveCustomerConfig(Customer: Record Customer; Setup: Record "GFL Fin. Comm. Setup"; var ReportId: Integer; var SendToEmail: Text[250]; var LanguageCode: Code[10])
    var
        CustomReportSelection: Record "Custom Report Selection";
    begin
        ReportId := Setup."Customer Overdue Report ID";
        SendToEmail := Customer."E-Mail";
        LanguageCode := Customer."Language Code";
        if LanguageCode = '' then
            LanguageCode := 'ESP';

        CustomReportSelection.SetRange("Source Type", Database::Customer);
        CustomReportSelection.SetRange("Source No.", Customer."No.");
        CustomReportSelection.SetRange(Usage, Enum::"Report Selection Usage"::"C.Statement");
        if CustomReportSelection.FindFirst() then begin
            if CustomReportSelection."Report ID" <> 0 then
                ReportId := CustomReportSelection."Report ID";
            if CustomReportSelection."Send To Email" <> '' then
                SendToEmail := CopyStr(CustomReportSelection."Send To Email", 1, 250);
        end;
    end;

    [TryFunction]
    local procedure TrySendReportToCustomer(Customer: Record Customer; ReportId: Integer; SendToEmail: Text[250]; LanguageCode: Code[10]; CutoffDate: Date; Setup: Record "GFL Fin. Comm. Setup")
    var
        TempBlob: Codeunit "Temp Blob";
        EmailMessage: Codeunit "Email Message";
        Email: Codeunit Email;
        EmailAccountCU: Codeunit "Email Account";
        TempEmailAccount: Record "Email Account" temporary;
        ReportOutStream: OutStream;
        ReportInStream: InStream;
        CustomerFilter: Record Customer;
        LanguageRec: Record Language;
        FileName: Text;
        OldLanguageId: Integer;
        LanguageId: Integer;
    begin
        OldLanguageId := GlobalLanguage();
        LanguageId := OldLanguageId;
        if LanguageCode <> '' then begin
            LanguageRec.SetRange(Code, LanguageCode);
            if LanguageRec.FindFirst() then
                LanguageId := LanguageRec."Windows Language ID";
        end;
        GlobalLanguage(LanguageId);

        TempBlob.CreateOutStream(ReportOutStream);
        CustomerFilter.SetRange("No.", Customer."No.");
        Report.SaveAs(
            ReportId,
            GetReportRequestXml(Customer."No.", CutoffDate),
            ReportFormat::Pdf,
            ReportOutStream,
            CustomerFilter);

        GlobalLanguage(OldLanguageId);

        TempBlob.CreateInStream(ReportInStream);
        FileName := GetPdfFileName(LanguageCode, Customer."No.");

        EmailAccountCU.GetAllAccounts(TempEmailAccount);
        TempEmailAccount.SetRange("Email Address", Setup."Customer Email From Address");
        if not TempEmailAccount.FindFirst() then
            Error('No se encontró la cuenta de correo "%1" en BC.', Setup."Customer Email From Address");

        EmailMessage.Create(SendToEmail, GetEmailSubject(LanguageCode), GetEmailBody(LanguageCode, Setup), true);
        EmailMessage.AddAttachment(FileName, 'application/pdf', ReportInStream);
        Email.Send(EmailMessage, TempEmailAccount);
    end;

    local procedure GetEmailSubject(LanguageCode: Code[10]): Text
    begin
        case GetLanguageGroup(LanguageCode) of
            'ENU':
                exit('Global Food Link S.L. - Outstanding Balance Statement');
            'FRA':
                exit('Global Food Link S.L. - Relevé de solde impayé');
            'DEU':
                exit('Global Food Link S.L. - Offene-Posten-Aufstellung');
            else
                exit('Global Food Link S.L. - Extracto de deuda pendiente');
        end;
    end;

    local procedure GetPdfFileName(LanguageCode: Code[10]; CustomerNo: Code[20]): Text
    var
        DateStr: Text;
    begin
        DateStr := Format(WorkDate(), 0, '<Year4><Month,2><Day,2>');
        case GetLanguageGroup(LanguageCode) of
            'ENU':
                exit(StrSubstNo('Outstanding_balance_statement_%1_%2.pdf', CustomerNo, DateStr));
            'FRA':
                exit(StrSubstNo('Releve_solde_impaye_%1_%2.pdf', CustomerNo, DateStr));
            'DEU':
                exit(StrSubstNo('Offene_Posten_Aufstellung_%1_%2.pdf', CustomerNo, DateStr));
            else
                exit(StrSubstNo('Extracto_deuda_pendiente_%1_%2.pdf', CustomerNo, DateStr));
        end;
    end;

    local procedure GetEmailBody(LanguageCode: Code[10]; Setup: Record "GFL Fin. Comm. Setup"): Text
    var
        Body: TextBuilder;
        Lang: Code[10];
        Greeting: Text;
        Para1: Text;
        Para2: Text;
        Para3: Text;
        Para4: Text;
        PrivacyText: Text;
        AddrLine: Text;
    begin
        Lang := GetLanguageGroup(LanguageCode);

        case Lang of
            'ENU':
                begin
                    Greeting := 'Dear Customer,';
                    Para1 := 'Please find attached the details of outstanding invoices with our company.';
                    Para2 := 'We kindly request that you proceed with the settlement of the outstanding amounts at your earliest convenience.';
                    Para3 := '*If you have already made your payment in recent days, please disregard this notification.';
                    Para4 := 'For any queries or clarifications, please do not hesitate to contact our administration department.';
                    PrivacyText := 'The personal data included in this communication will be processed by Global Food Link S.L. in accordance with applicable data protection regulations. You may consult additional information in our Privacy Policy.';
                end;
            'FRA':
                begin
                    Greeting := 'Cher/Chère client(e),';
                    Para1 := 'Veuillez trouver ci-joint le détail des factures en attente de paiement auprès de notre société.';
                    Para2 := 'Nous vous prions de bien vouloir procéder à la régularisation des montants en suspens dans les meilleurs délais.';
                    Para3 := '*Si vous avez déjà effectué votre paiement ces derniers jours, veuillez ne pas tenir compte de cette notification.';
                    Para4 := 'Pour toute question ou clarification, n''hésitez pas à contacter notre service administratif.';
                    PrivacyText := 'Les données personnelles incluses dans cette communication seront traitées par Global Food Link S.L. conformément à la réglementation en vigueur en matière de protection des données. Vous pouvez consulter des informations complémentaires dans notre Politique de Confidentialité.';
                end;
            'DEU':
                begin
                    Greeting := 'Sehr geehrter Kunde, sehr geehrte Kundin,';
                    Para1 := 'Anbei finden Sie die Aufstellung der offenen Rechnungen bei unserem Unternehmen.';
                    Para2 := 'Wir bitten Sie, die ausstehenden Beträge schnellstmöglich zu begleichen.';
                    Para3 := '*Sollten Sie Ihre Zahlung bereits in den letzten Tagen geleistet haben, bitten wir Sie, diese Benachrichtigung zu ignorieren.';
                    Para4 := 'Bei Fragen oder Unklarheiten zögern Sie bitte nicht, unsere Verwaltungsabteilung zu kontaktieren.';
                    PrivacyText := 'Die in dieser Mitteilung enthaltenen personenbezogenen Daten werden von Global Food Link S.L. gemäß den geltenden Datenschutzbestimmungen verarbeitet. Weitere Informationen finden Sie in unserer Datenschutzerklärung.';
                end;
            else begin
                Greeting := 'Estimado/a cliente,';
                Para1 := 'Adjunto encontrará el detalle de las facturas pendientes de pago con nuestra empresa.';
                Para2 := 'Le rogamos proceda a la regularización de los importes pendientes a la mayor brevedad posible.';
                Para3 := '*Si ya ha realizado su pago en los últimos días por favor ignore este correo de notificación.';
                Para4 := 'Para cualquier consulta o aclaración, no dude en contactar con nuestro departamento de administración.';
                PrivacyText := 'Los datos personales incluidos en esta comunicación serán tratados por Global Food Link S.L. conforme a la normativa vigente en materia de protección de datos. Puede consultar información adicional en nuestra Política de Privacidad.';
            end;
        end;

        // Clean corporate HTML — no borders, no boxes, white background
        Body.AppendLine('<html><body style="margin:0;padding:0;font-family:Arial,sans-serif;font-size:14px;color:#333333;background:#ffffff;">');
        Body.AppendLine('<div style="max-width:580px;padding:40px 32px;">');

        // Saludo + blank line
        Body.AppendLine(StrSubstNo('<p style="margin:0;">%1</p>', Greeting));
        Body.AppendLine('<br/>');

        // Paragraphs — no blank lines between them
        Body.AppendLine(StrSubstNo('<p style="margin:0 0 14px 0;">%1</p>', Para1));
        Body.AppendLine(StrSubstNo('<p style="margin:0 0 14px 0;">%1</p>', Para2));
        Body.AppendLine(StrSubstNo('<p style="margin:0 0 14px 0;">%1</p>', Para3));
        Body.AppendLine(StrSubstNo('<p style="margin:0;">%1</p>', Para4));

        // Two blank lines before closing
        Body.AppendLine('<br/><br/>');
        Body.AppendLine('<p style="margin:0;">Un saludo / Best regards / Cordialement,</p>');
        Body.AppendLine('<br/>');

        // Signature — name + address on consecutive lines
        Body.AppendLine(StrSubstNo('<p style="margin:0 0 2px 0;"><strong>%1</strong></p>', Setup."Customer Email From Name"));
        AddrLine := '';
        if Setup."Company Address" <> '' then
            AddrLine := AddrLine + Setup."Company Address";
        if (Setup."Company Address" <> '') and (Setup."Company Website" <> '') then
            AddrLine := AddrLine + ' | ';
        if Setup."Company Website" <> '' then begin
            AddrLine := AddrLine + '<a href="';
            AddrLine := AddrLine + Setup."Company Website";
            AddrLine := AddrLine + '" style="color:#333333;">';
            AddrLine := AddrLine + Setup."Company Website";
            AddrLine := AddrLine + '</a>';
        end;
        Body.AppendLine('<p style="margin:0;">' + AddrLine + '</p>');

        AppendBannerHtml(Body, Setup);

        // Blank line + privacy text
        Body.AppendLine('<br/>');
        Body.AppendLine(StrSubstNo('<p style="font-size:11px;color:#999999;margin:0;line-height:1.5;">%1</p>', PrivacyText));

        Body.AppendLine('</div>');
        Body.AppendLine('</body></html>');

        exit(Body.ToText());
    end;

    local procedure AppendBannerHtml(var Body: TextBuilder; Setup: Record "GFL Fin. Comm. Setup")
    var
        TempBlob: Codeunit "Temp Blob";
        Base64: Codeunit "Base64 Convert";
        BannerBase64: Text;
        OutStr: OutStream;
        InStr: InStream;
    begin
        if not Setup."Email Banner".HasValue() then exit;

        TempBlob.CreateOutStream(OutStr);
        Setup."Email Banner".ExportStream(OutStr);
        TempBlob.CreateInStream(InStr);
        BannerBase64 := Base64.ToBase64(InStr);

        if BannerBase64 = '' then exit;

        if Setup."LinkedIn URL" <> '' then
            Body.AppendLine(StrSubstNo('<a href="%1" style="display:block;line-height:0;">', Setup."LinkedIn URL"));
        Body.AppendLine('<img src="data:image/png;base64,' + BannerBase64 + '" style="display:block;border:0;max-width:100%;" alt="Global Food Link"/>');
        if Setup."LinkedIn URL" <> '' then
            Body.AppendLine('</a>');
    end;

    local procedure GetLanguageGroup(LanguageCode: Code[10]): Code[10]
    begin
        case LanguageCode of
            'ESP', 'ESS':
                exit('ESP');
            'ENU':
                exit('ENU');
            'FRA', 'FRF':
                exit('FRA');
            'DEU', 'DES':
                exit('DEU');
            else
                exit('ENU');
        end;
    end;

    local procedure ValidateSetup(Setup: Record "GFL Fin. Comm. Setup")
    var
        EmailAccountCU: Codeunit "Email Account";
        TempEmailAccount: Record "Email Account" temporary;
    begin
        if Setup."Customer Overdue Report ID" = 0 then
            Error('Debe configurar el ID del informe de Deuda Pendiente en Config. Comunicaciones Financieras GFL.');
        if Setup."Customer Email From Address" = '' then
            Error('Debe configurar la dirección de email del remitente (clientes) en Config. Comunicaciones Financieras GFL.');
        EmailAccountCU.GetAllAccounts(TempEmailAccount);
        TempEmailAccount.SetRange("Email Address", Setup."Customer Email From Address");
        if TempEmailAccount.IsEmpty() then
            Error('No se encontró ninguna cuenta de correo electrónico en BC con la dirección "%1". Configúrela en Configuración → Cuentas de correo electrónico.',
                Setup."Customer Email From Address");
    end;

    local procedure CustomerHasOverdueEntries(CustomerNo: Code[20]; CutoffDate: Date): Boolean
    var
        CustLedgerEntry: Record "Cust. Ledger Entry";
    begin
        CustLedgerEntry.SetRange("Customer No.", CustomerNo);
        CustLedgerEntry.SetRange(Open, true);
        CustLedgerEntry.SetFilter("Document Type", '%1|%2',
            CustLedgerEntry."Document Type"::Invoice,
            CustLedgerEntry."Document Type"::"Credit Memo");
        CustLedgerEntry.SetFilter("Due Date", '..%1', CutoffDate);
        exit(not CustLedgerEntry.IsEmpty());
    end;

    local procedure GetReportRequestXml(CustomerNo: Code[20]; CutoffDate: Date): Text
    var
        ReportXml: TextBuilder;
    begin
        ReportXml.AppendLine('<?xml version="1.0" standalone="yes"?>');
        ReportXml.AppendLine('<ReportParameters name="Customer Detailed Aging" id="106">');
        ReportXml.AppendLine('<Options>');
        ReportXml.AppendLine(StrSubstNo('<Field name="EndDate">%1</Field>',
            Format(CutoffDate, 0, '<Year4>-<Month,2>-<Day,2>')));
        ReportXml.AppendLine('<Field name="OnlyOpen">true</Field>');
        ReportXml.AppendLine('</Options>');
        ReportXml.AppendLine('<DataItems>');
        ReportXml.AppendLine('<DataItem name="Header">VERSION(1) SORTING(Field1)</DataItem>');
        ReportXml.AppendLine(StrSubstNo(
            '<DataItem name="Customer">VERSION(1) SORTING(Field1) WHERE(Field1=1(%1))</DataItem>',
            CustomerNo));
        ReportXml.AppendLine(
            '<DataItem name="Cust. Ledger Entry">VERSION(1) SORTING(Field3,Field4,Field11)</DataItem>');
        ReportXml.AppendLine('<DataItem name="Integer">VERSION(1) SORTING(Field1)</DataItem>');
        ReportXml.AppendLine('<DataItem name="Integer2">VERSION(1) SORTING(Field1)</DataItem>');
        ReportXml.AppendLine('</DataItems>');
        ReportXml.AppendLine('</ReportParameters>');
        exit(ReportXml.ToText());
    end;

    local procedure LogMessage(Msg: Text)
    begin
        if GuiAllowed then
            Message(Msg);
    end;
}
