using { smartpay as db } from '../db/schema';

@requires: 'system-service'
@protocol: 'rest'
service ProcessingService @(path:'/processing') {

  
  @cds.redirection.target
  entity InvoiceHeaders as projection on db.InvoiceHeader;

  
  entity ValidationRuns as projection on db.ValidationRun;

  action pollMailbox()
    returns {
      messagesFound: Integer;
      documentsQueued: Integer;
    };

  action runExtraction(documentId: UUID)
    returns InvoiceHeaders;

  action runValidation(invoiceId: UUID)
    returns ValidationRuns;

  action postToLedgerOrErp(invoiceId: UUID)
    returns {
      posted: Boolean;
      integrationEventId: UUID;
    };

  
  entity PendingExtractions as projection on db.InvoiceDocument
    where rawExtractionJson is null;

  
  entity ReadyToPayQueue as projection on db.InvoiceHeader
    where readyToPayFlag = true
      and processingStatus <> 'PAID';
}