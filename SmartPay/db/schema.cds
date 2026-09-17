namespace smartpay;

using { cuid, managed } from '@sap/cds/common';

/* ============================================================
   MASTER DATA
   ============================================================ */

entity CompanyMaster : cuid, managed {
  companyCode  : String(20)  @mandatory;
  companyName  : String(255);
  currencyCode : String(3);
}

entity SupplierMaster : cuid, managed {
  sourceSystem       : String(50)  @mandatory;
  sourceSupplierId   : String(100) @mandatory;   // unique with sourceSystem
  legalName          : String(255) @mandatory;
  taxId              : String(100);
  status             : String(30) enum { ACTIVE; BLOCKED; INACTIVE; } default 'ACTIVE';
  defaultCurrency    : String(3);
  updatedFromSourceAt: Timestamp;

  purchaseOrders     : Association to many POHeader on purchaseOrders.supplier = $self;
  invoices           : Association to many InvoiceHeader on invoices.supplier = $self;
}

/* ============================================================
   PURCHASE ORDER
   ============================================================ */

entity POHeader : cuid, managed {
  sourceSystem         : String(50)  @mandatory;
  sourcePoNumber       : String(100) @mandatory;  // unique with sourceSystem/company
  poStatus             : String(30) enum { DRAFT; INTERNAL_REVIEW; SENT; ACKNOWLEDGED; OPEN; CLOSED; CANCELLED; } default 'DRAFT';
  poType               : String(30) enum { STANDARD; SERVICE; LIMIT; };
  supplier             : Association to SupplierMaster @mandatory;
  company              : Association to CompanyMaster  @mandatory;
  currencyCode         : String(3) @mandatory;
  totalOrderValue      : Decimal(18,2);
  openOrderValue       : Decimal(18,2);
  toleranceProfileCode : String(50);
  updatedFromSourceAt  : Timestamp;

  lines                : Composition of many POLine on lines.po = $self;
  sesHeaders           : Association to many SESHeader on sesHeaders.po = $self;
}

entity POLine : cuid {
  po                   : Association to POHeader @mandatory;
  lineNumber           : Integer @mandatory;      // unique per PO
  materialServiceCode  : String(100);
  orderedQuantity      : Decimal(18,4);
  receivedQuantity     : Decimal(18,4);
  invoicedQuantity     : Decimal(18,4);
  openQuantity         : Decimal(18,4);           // must not go negative
  unitPrice            : Decimal(18,6);
  lineValue             : Decimal(18,2);
  openValue             : Decimal(18,2);            // must not go negative
  finalInvoiceFlag     : Boolean default false;

  invoiceLines         : Association to many InvoiceLine on invoiceLines.poLine = $self;
}

/* ============================================================
   SERVICE ENTRY SHEET (SES)
   ============================================================ */

entity SESHeader : cuid, managed {
  sourceSystem     : String(50)  @mandatory;
  sourceSesNumber  : String(100) @mandatory;      // unique with sourceSystem
  sesStatus        : String(30) enum { DRAFT; SUBMITTED; ACCEPTED; APPROVED; REJECTED; } default 'DRAFT';
  po               : Association to POHeader @mandatory;

  lines            : Composition of many SESLine on lines.ses = $self;
}

entity SESLine : cuid {
  ses               : Association to SESHeader @mandatory;
  poLine            : Association to POLine;
  lineNumber        : Integer;
  serviceDescription: String(255);
  acceptedQuantity  : Decimal(18,4);
  unitPrice         : Decimal(18,6);
  lineValue         : Decimal(18,2);
}

/* ============================================================
   INVOICE INTAKE
   ============================================================ */

entity InvoiceDocument : cuid, managed {
  invoice           : Association to InvoiceHeader;
  fileName          : String(255);
  mimeType          : String(100);
  fileSizeBytes     : Integer;
  storageUri        : String(1000);               // /data/documents/... (MVP) or S3 URI (Phase 1)
  sourceChannel     : String(20) enum { PORTAL; EMAIL; };
  rawExtractionJson : LargeString;                 // canonical OCR/Document AI payload
}

entity InvoiceHeader : cuid, managed {
  invoiceNumber        : String(100) @mandatory;
  supplier             : Association to SupplierMaster @mandatory;
  po                   : Association to POHeader;
  company              : Association to CompanyMaster;
  invoiceDate          : Date;
  currencyCode         : String(3);
  invoiceValue         : Decimal(18,2);
  processingStatus     : String(30) enum {
    UPLOADED; UNDER_VALIDATION; READY_TO_PAY; EXCEPTION; REJECTED; PAID; RESUBMITTED;
  } default 'UPLOADED';
  readyToPayFlag       : Boolean default false;    // computed, never manually set
  extractionConfidence : Decimal(5,2);              // overall OCR confidence %

  documents            : Composition of many InvoiceDocument on documents.invoice = $self;
  lines                : Composition of many InvoiceLine   on lines.invoice = $self;
  validationRuns       : Association to many ValidationRun on validationRuns.invoice = $self;
  exceptions           : Association to many InvoiceException on exceptions.invoice = $self;
  auditEvents          : Association to many AuditEvent on auditEvents.invoice = $self;
}

entity InvoiceLine : cuid {
  invoice     : Association to InvoiceHeader @mandatory;
  lineNumber  : Integer;
  poLine      : Association to POLine;
  description : String(255);
  quantity    : Decimal(18,4);
  unitPrice   : Decimal(18,6);
  lineValue   : Decimal(18,2);
}

/* ============================================================
   VALIDATION ENGINE
   ============================================================ */

entity ValidationRule : cuid, managed {
  ruleCode      : String(20) @mandatory;           // e.g. R014 (OCR confidence threshold)
  ruleName      : String(255);
  ruleCategory  : String(30) enum {
    PO_MATCH; SES_MATCH; RATE_TOLERANCE; QTY_TOLERANCE; DUPLICATE; SUPPLIER_STATUS; OCR_CONFIDENCE;
  };
  toleranceType  : String(20) enum { PERCENT; ABSOLUTE; };
  toleranceValue : Decimal(18,4);
  severity       : String(20) enum { CRITICAL; WARNING; };
  autoRejectFlag : Boolean default false;
  ruleVersion    : Integer default 1;               // new version on publish; history preserved
  active         : Boolean default true;
}

entity ValidationRun : cuid, managed {
  invoice        : Association to InvoiceHeader @mandatory;
  runNumber      : Integer @mandatory;              // never overwritten, always incremented
  triggeredBy    : String(30) enum { SYSTEM; USER_CORRECTION; EXCEPTION_RESOLUTION; };
  startedAt      : Timestamp;
  completedAt    : Timestamp;
  overallResult  : String(20) enum { PASS; FAIL; PARTIAL; };

  results        : Composition of many ValidationResult on results.run = $self;
}

entity ValidationResult : cuid {
  run           : Association to ValidationRun @mandatory;
  rule          : Association to ValidationRule @mandatory;
  result        : String(20) enum { PASS; FAIL; WARNING; };
  expectedValue : String(255);                      // PO/SES reference value
  actualValue   : String(255);                      // OCR-extracted value
  variance      : Decimal(18,4);
}

/* ============================================================
   EXCEPTION WORKBENCH
   ============================================================ */

entity InvoiceException : cuid, managed {
  invoice       : Association to InvoiceHeader @mandatory;
  exceptionCode : String(20);
  exceptionType : String(50);
  severity      : String(20) enum { CRITICAL; WARNING; };
  status        : String(20) enum { OPEN; IN_PROGRESS; RESOLVED; REJECTED; } default 'OPEN';
  ownerRole     : String(30) enum { AP; BUYER; ADMIN; };
  assignedTo    : String(255);
  reasonText    : String(1000);

  actions       : Composition of many ExceptionAction on actions.exception = $self;
}

entity ExceptionAction : cuid, managed {
  exception     : Association to InvoiceException @mandatory;
  actionType    : String(30) enum {
    OVERRIDE_APPROVED; SUPPLIER_CORRECTION_REQUESTED; REJECTED; RESOLVED; COMMENT;
  };
  actionBy      : String(255);
  justification : String(1000);
  actionAt      : Timestamp;
}

/* ============================================================
   AUDIT & INTEGRATION
   ============================================================ */

entity AuditEvent : cuid {
  invoice           : Association to InvoiceHeader;
  po                : Association to POHeader;
  eventType         : String(50);
  eventDescription  : String(1000);
  performedBy       : String(255);
  performedAt       : Timestamp;
}

// entity IntegrationEvent : cuid {
//   channel      : String(20) enum { EMAIL; PORTAL; ERP; };
//   eventType    : String(50);                        // e.g. MAIL_RECEIVED, MALWARE_SCAN, ERP_POST
//   status       : String(20) enum { RECEIVED; PROCESSED; FAILED; };
//   payloadRef   : String(1000);
//   errorMessage : String(1000);
//   occurredAt   : Timestamp;
// }




