codeunit 50301 "GFL Vendor Remittance Sender"
{
    // REQ 3: Envío automático de aviso de pago a proveedores
    //
    // Modo EVENTO (inmediato): OnAfterInsertEvent en Vendor Ledger Entry.
    //   Al registrar el pago, programa una tarea 10 s después (cuando la transacción
    //   ya ha hecho commit y las Detailed VLE de aplicación existen).
    //   La tarea ejecuta OnRun → ProcessUnsentRemittances, que encuentra y envía el pago.
    //
    // Modo JOB QUEUE (reintento): Job Queue llama a OnRun → ProcessUnsentRemittances.
    //   Si el pago no tiene facturas aplicadas aún, lo omite y lo reintenta la próxima vez.
    //
    // Modo MANUAL: Botón "Enviar aviso de pago" en Movimientos de proveedor.

    trigger OnRun()
    begin
        ProcessUnsentRemittances();
    end;

    // Firma garantizada en todas las versiones de BC.
    // Agenda el envío en una tarea diferida para que ocurra DESPUÉS del commit,
    // momento en que las Detailed VLE de aplicación ya están persistidas.
    [EventSubscriber(ObjectType::Table, Database::"Vendor Ledger Entry", 'OnAfterInsertEvent', '', false, false)]
    local procedure VendLedgEntry_OnAfterInsertEvent(var Rec: Record "Vendor Ledger Entry"; RunTrigger: Boolean)
    var
        Setup: Record "GFL Fin. Comm. Setup";
    begin
        if Rec.IsTemporary() then exit;
        if Rec."Document Type" <> Rec."Document Type"::Payment then exit;

        Setup.GetSetup();
        if not Setup."Auto Send Remittance" then exit;
        if Setup."Remittance Report ID" = 0 then exit;
        if Setup."Vendor Email From Address" = '' then exit;
        if not VendorSendRemittanceEnabled(Rec."Vendor No.") then exit;

        // Programa ProcessUnsentRemittances() para después del commit.
        // En ese momento las Detailed VLE de aplicación ya existen.
        // Si la tarea falla, el Job Queue actúa como red de seguridad.
        TaskScheduler.CreateTask(
            Codeunit::"GFL Vendor Remittance Sender",
            0,
            true,
            CompanyName(),
            CurrentDateTime() + 10000);
    end;

    procedure ProcessUnsentRemittances()
    var
        Setup: Record "GFL Fin. Comm. Setup";
        VendLedgerEntry: Record "Vendor Ledger Entry";
        EntriesProcessed: Integer;
        EntriesSent: Integer;
        EntriesError: Integer;
        EntriesSkipped: Integer;
    begin
        Setup.GetSetup();

        if not Setup."Auto Send Remittance" then
            exit;

        ValidateSetup(Setup);

        VendLedgerEntry.SetRange("Document Type", VendLedgerEntry."Document Type"::Payment);
        VendLedgerEntry.SetRange("GFL Remittance Sent", false);
        VendLedgerEntry.SetFilter("Posting Date", '>=%1', CalcDate('<-7D>', WorkDate()));

        if VendLedgerEntry.FindSet() then
            repeat
                EntriesProcessed += 1;

                if not VendorSendRemittanceEnabled(VendLedgerEntry."Vendor No.") then begin
                    // Proveedor sin "Enviar aviso de pago" activo — se omite
                    EntriesSkipped += 1;
                end else if PaymentHasAppliedEntries(VendLedgerEntry."Entry No.") then begin
                    if TrySendRemittanceForEntry(VendLedgerEntry, Setup) then begin
                        MarkAsSent(VendLedgerEntry);
                        EntriesSent += 1;
                    end else begin
                        EntriesError += 1;
                        LogMessage(StrSubstNo('Error enviando aviso pago %1 proveedor %2.',
                            VendLedgerEntry."Document No.", VendLedgerEntry."Vendor No."));
                    end;
                end else begin
                    // Sin facturas aplicadas aún — se reintentará en la próxima ejecución
                    EntriesSkipped += 1;
                end;

                Commit();
            until VendLedgerEntry.Next() = 0;

        LogMessage(StrSubstNo(
            'Proceso REQ3 completado. Revisados: %1, Enviados: %2, Errores: %3, Sin aplicar: %4',
            EntriesProcessed, EntriesSent, EntriesError, EntriesSkipped));
    end;

    /// <summary>
    /// Envío manual desde el botón en Movimientos de proveedor
    /// </summary>
    procedure SendRemittanceManual(var VendLedgerEntry: Record "Vendor Ledger Entry")
    var
        Setup: Record "GFL Fin. Comm. Setup";
        SentDateText: Text;
    begin
        Setup.GetSetup();

        ValidateSetup(Setup);

        if VendLedgerEntry."Document Type" <> VendLedgerEntry."Document Type"::Payment then
            Error('Solo se puede enviar aviso de pago para movimientos de tipo Pago.');

        if not VendorSendRemittanceEnabled(VendLedgerEntry."Vendor No.") then begin
            Message('El envío de avisos de pago no está habilitado para este proveedor. Active la opción "Enviar aviso de pago" en la ficha del proveedor para poder enviar.');
            exit;
        end;

        if not PaymentHasAppliedEntries(VendLedgerEntry."Entry No.") then
            Error('Este pago no tiene facturas liquidadas asociadas.');

        if VendLedgerEntry."GFL Remittance Sent" then begin
            SentDateText := Format(VendLedgerEntry."GFL Remittance Sent Date", 0, '<Day,2>/<Month,2>/<Year4> <Hours24,2>:<Minutes,2>');
            if not Confirm('Este aviso de pago ya fue enviado el %1. ¿Desea volver a enviarlo?',
                false, SentDateText) then
                exit;
        end else begin
            if not Confirm('¿Enviar aviso de pago %1 al proveedor %2?',
                true, VendLedgerEntry."Document No.", VendLedgerEntry."Vendor No.") then
                exit;
        end;

        if TrySendRemittanceForEntry(VendLedgerEntry, Setup) then begin
            MarkAsSent(VendLedgerEntry);
            Message('Aviso de pago enviado correctamente.');
        end else
            Error('Error al enviar. Verifique la configuración de email y los datos del proveedor.');
    end;

    /// <summary>
    /// Vista previa sin enviar
    /// </summary>
    procedure PreviewRemittance(VendLedgerEntry: Record "Vendor Ledger Entry")
    var
        Setup: Record "GFL Fin. Comm. Setup";
        VendLedgerEntryFilter: Record "Vendor Ledger Entry";
    begin
        Setup.GetSetup();

        if VendLedgerEntry."Document Type" <> VendLedgerEntry."Document Type"::Payment then
            Error('Solo se puede generar aviso de pago para movimientos de tipo Pago.');

        VendLedgerEntryFilter.SetRange("Vendor No.", VendLedgerEntry."Vendor No.");
        VendLedgerEntryFilter.SetRange("Document No.", VendLedgerEntry."Document No.");

        Report.Run(Setup."Remittance Report ID", true, false, VendLedgerEntryFilter);
    end;

    local procedure PaymentHasAppliedEntries(EntryNo: Integer): Boolean
    var
        DetailedVendLedgEntry: Record "Detailed Vendor Ledg. Entry";
    begin
        DetailedVendLedgEntry.SetRange("Vendor Ledger Entry No.", EntryNo);
        DetailedVendLedgEntry.SetRange("Entry Type", DetailedVendLedgEntry."Entry Type"::Application);
        exit(not DetailedVendLedgEntry.IsEmpty());
    end;

    [TryFunction]
    local procedure TrySendRemittanceForEntry(VendLedgerEntry: Record "Vendor Ledger Entry"; Setup: Record "GFL Fin. Comm. Setup")
    var
        Vendor: Record Vendor;
        TempBlob: Codeunit "Temp Blob";
        EmailMessage: Codeunit "Email Message";
        Email: Codeunit Email;
        EmailAccountCU: Codeunit "Email Account";
        TempEmailAccount: Record "Email Account" temporary;
        LanguageRec: Record Language;
        ReportOutStream: OutStream;
        ReportInStream: InStream;
        VendLedgerEntryFilter: Record "Vendor Ledger Entry";
        ToEmail: Text[250];
        FileName: Text;
        LanguageCode: Code[10];
        OldLanguageId: Integer;
        LanguageId: Integer;
    begin
        Vendor.Get(VendLedgerEntry."Vendor No.");
        ResolveVendorConfig(Vendor, Setup, ToEmail, LanguageCode);

        if ToEmail = '' then
            Error('El proveedor %1 - %2 no tiene email configurado.', Vendor."No.", Vendor.Name);

        OldLanguageId := GlobalLanguage();
        LanguageId := OldLanguageId;
        if LanguageCode <> '' then begin
            LanguageRec.SetRange(Code, LanguageCode);
            if LanguageRec.FindFirst() then
                LanguageId := LanguageRec."Windows Language ID";
        end;
        GlobalLanguage(LanguageId);

        TempBlob.CreateOutStream(ReportOutStream);
        VendLedgerEntryFilter.SetRange("Vendor No.", VendLedgerEntry."Vendor No.");
        VendLedgerEntryFilter.SetRange("Document No.", VendLedgerEntry."Document No.");
        Report.SaveAs(Setup."Remittance Report ID", '', ReportFormat::Pdf, ReportOutStream, VendLedgerEntryFilter);

        GlobalLanguage(OldLanguageId);

        TempBlob.CreateInStream(ReportInStream);
        FileName := GetRemittancePdfFileName(LanguageCode, Vendor."No.");

        EmailAccountCU.GetAllAccounts(TempEmailAccount);
        TempEmailAccount.SetRange("Email Address", Setup."Vendor Email From Address");
        if not TempEmailAccount.FindFirst() then
            Error('No se encontró la cuenta de correo "%1" en BC.', Setup."Vendor Email From Address");

        EmailMessage.Create(ToEmail, GetRemittanceEmailSubject(LanguageCode), GetVendorEmailBody(Vendor, LanguageCode, Setup), true);
        EmailMessage.AddAttachment(FileName, 'application/pdf', ReportInStream);
        Email.Send(EmailMessage, TempEmailAccount);
    end;

    local procedure ResolveVendorConfig(Vendor: Record Vendor; Setup: Record "GFL Fin. Comm. Setup"; var ToEmail: Text[250]; var LanguageCode: Code[10])
    var
        CustomReportSelection: Record "Custom Report Selection";
    begin
        ToEmail := Vendor."E-Mail";
        LanguageCode := Vendor."Language Code";
        if LanguageCode = '' then
            LanguageCode := 'ESP';

        CustomReportSelection.SetRange("Source Type", Database::Vendor);
        CustomReportSelection.SetRange("Source No.", Vendor."No.");
        CustomReportSelection.SetRange(Usage, Enum::"Report Selection Usage"::"V.Remittance");
        if CustomReportSelection.FindFirst() then
            if CustomReportSelection."Send To Email" <> '' then
                ToEmail := CopyStr(CustomReportSelection."Send To Email", 1, 250);
    end;

    local procedure GetVendorLanguageGroup(LanguageCode: Code[10]): Code[10]
    begin
        case LanguageCode of
            'ESP', 'ESS': exit('ESP');
            'ENU': exit('ENU');
            'FRA', 'FRF': exit('FRA');
            'DEU', 'DES': exit('DEU');
            else
                exit('ENU');
        end;
    end;

    local procedure GetRemittanceEmailSubject(LanguageCode: Code[10]): Text
    begin
        case GetVendorLanguageGroup(LanguageCode) of
            'ESP': exit('Aviso de pago - Global Food Link S.L.');
            'FRA': exit('Avis de paiement - Global Food Link S.L.');
            'DEU': exit('Zahlungsavis - Global Food Link S.L.');
            else
                exit('Remittance Advice - Global Food Link S.L.');
        end;
    end;

    local procedure GetRemittancePdfFileName(LanguageCode: Code[10]; VendorNo: Code[20]): Text
    var
        DateStr: Text;
    begin
        DateStr := Format(WorkDate(), 0, '<Day,2><Month,2><Year4>');
        case GetVendorLanguageGroup(LanguageCode) of
            'ESP': exit('AvisoPago_' + VendorNo + '_' + DateStr + '.pdf');
            'FRA': exit('AvisPaiement_' + VendorNo + '_' + DateStr + '.pdf');
            'DEU': exit('Zahlungsavis_' + VendorNo + '_' + DateStr + '.pdf');
            else
                exit('RemittanceAdvice_' + VendorNo + '_' + DateStr + '.pdf');
        end;
    end;

    local procedure GetVendorEmailBody(Vendor: Record Vendor; LanguageCode: Code[10]; Setup: Record "GFL Fin. Comm. Setup"): Text
    var
        Body: TextBuilder;
        Lang: Code[10];
        Greeting, Para1, Para2, Para3, PrivacyText: Text;
        AddrLine: Text;
    begin
        Lang := GetVendorLanguageGroup(LanguageCode);

        case Lang of
            'ESP':
                begin
                    Greeting := StrSubstNo('Estimado/a <strong>%1</strong>,', Vendor.Name);
                    Para1 := 'Le informamos que hemos procedido a realizar el pago correspondiente a las facturas detalladas en el documento adjunto.';
                    Para2 := 'Adjunto encontrará el aviso de pago con el detalle de las facturas incluidas.';
                    Para3 := 'Para cualquier consulta, no dude en ponerse en contacto con nuestro departamento de administración.';
                    PrivacyText := 'Este mensaje y sus adjuntos son confidenciales y están destinados únicamente al destinatario. Si ha recibido este mensaje por error, le rogamos que lo elimine y nos lo comunique. Global Food Link S.L. trata sus datos de acuerdo con el Reglamento General de Protección de Datos (RGPD).';
                end;
            'FRA':
                begin
                    Greeting := StrSubstNo('Cher/Chère <strong>%1</strong>,', Vendor.Name);
                    Para1 := 'Nous vous informons que nous avons procédé au paiement correspondant aux factures détaillées dans le document ci-joint.';
                    Para2 := 'Veuillez trouver ci-joint l''avis de paiement avec le détail des factures incluses.';
                    Para3 := 'Pour toute question, n''hésitez pas à contacter notre service comptable.';
                    PrivacyText := 'Ce message et ses pièces jointes sont confidentiels et destinés uniquement au destinataire. Si vous avez reçu ce message par erreur, veuillez le supprimer et nous en informer. Global Food Link S.L. traite vos données conformément au Règlement Général sur la Protection des Données (RGPD).';
                end;
            'DEU':
                begin
                    Greeting := StrSubstNo('Sehr geehrte/r <strong>%1</strong>,', Vendor.Name);
                    Para1 := 'Wir informieren Sie, dass die Zahlung für die im beigefügten Dokument aufgeführten Rechnungen durchgeführt wurde.';
                    Para2 := 'Anbei finden Sie die Zahlungsbestätigung mit den Details der enthaltenen Rechnungen.';
                    Para3 := 'Bei Fragen stehen wir Ihnen gerne zur Verfügung.';
                    PrivacyText := 'Diese Nachricht und ihre Anhänge sind vertraulich und ausschließlich für den Empfänger bestimmt. Wenn Sie diese Nachricht irrtümlich erhalten haben, löschen Sie sie bitte und benachrichtigen Sie uns. Global Food Link S.L. verarbeitet Ihre Daten gemäß der Datenschutz-Grundverordnung (DSGVO).';
                end;
            else begin
                Greeting := StrSubstNo('Dear <strong>%1</strong>,', Vendor.Name);
                Para1 := 'We are pleased to inform you that payment has been made for the invoices detailed in the attached document.';
                Para2 := 'Please find attached the remittance advice with the details of the included invoices.';
                Para3 := 'For any queries, please do not hesitate to contact our accounts department.';
                PrivacyText := 'This message and its attachments are confidential and intended solely for the recipient. If you have received this message in error, please delete it and notify us. Global Food Link S.L. processes your data in accordance with the General Data Protection Regulation (GDPR).';
            end;
        end;

        Body.AppendLine('<html><body style="margin:0;padding:0;font-family:Arial,sans-serif;font-size:14px;color:#333333;background:#ffffff;">');
        Body.AppendLine('<div style="max-width:580px;padding:40px 32px;">');

        Body.AppendLine('<p style="margin:0;">' + Greeting + '</p>');
        Body.AppendLine('<br/>');
        Body.AppendLine(StrSubstNo('<p style="margin:0 0 14px 0;">%1</p>', Para1));
        Body.AppendLine(StrSubstNo('<p style="margin:0 0 14px 0;">%1</p>', Para2));
        Body.AppendLine(StrSubstNo('<p style="margin:0;">%1</p>', Para3));

        Body.AppendLine('<br/><br/>');
        Body.AppendLine('<p style="margin:20px 0 20px 0;">Un saludo / Best regards / Cordialement,</p>');
        Body.AppendLine('<br/>');
        Body.AppendLine(StrSubstNo('<p style="margin:0 0 2px 0;"><strong>%1</strong></p>', Setup."Vendor Email From Name"));

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

    local procedure MarkAsSent(var VendLedgerEntry: Record "Vendor Ledger Entry")
    begin
        VendLedgerEntry."GFL Remittance Sent" := true;
        VendLedgerEntry."GFL Remittance Sent Date" := CurrentDateTime();
        VendLedgerEntry.Modify();
    end;

    local procedure ValidateSetup(Setup: Record "GFL Fin. Comm. Setup")
    var
        EmailAccountCU: Codeunit "Email Account";
        TempEmailAccount: Record "Email Account" temporary;
    begin
        if Setup."Remittance Report ID" = 0 then
            Error('Debe configurar el ID del informe de Aviso de Pago en Config. Comunicaciones Financieras GFL.');
        if Setup."Vendor Email From Address" = '' then
            Error('Debe configurar la dirección de email del remitente (proveedores) en Config. Comunicaciones Financieras GFL.');
        EmailAccountCU.GetAllAccounts(TempEmailAccount);
        TempEmailAccount.SetRange("Email Address", Setup."Vendor Email From Address");
        if TempEmailAccount.IsEmpty() then
            Error('No se encontró ninguna cuenta de correo electrónico en BC con la dirección "%1". Configúrela en Configuración → Cuentas de correo electrónico.',
                Setup."Vendor Email From Address");
    end;

    local procedure VendorSendRemittanceEnabled(VendorNo: Code[20]): Boolean
    var
        Vendor: Record Vendor;
    begin
        if not Vendor.Get(VendorNo) then exit(false);
        exit(Vendor."GFL Send Remittance");
    end;

    local procedure LogMessage(Msg: Text)
    begin
        if GuiAllowed then
            Message(Msg);
    end;
}
