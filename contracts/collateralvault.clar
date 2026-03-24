;; Define the SIP009 NFT trait
(define-trait sip009-nft-trait
  (
    (get-last-token-id () (response uint uint))
    (get-token-uri (uint) (response (optional (string-ascii 256)) uint))
    (get-owner (uint) (response (optional principal) uint))
    (transfer (uint principal principal) (response bool uint))
  )
)

;; Response types
(define-constant success-response (ok true))
(define-constant ERR-NOT-BORROWER (err u100))
(define-constant ERR-NOT-LENDER (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-REPAID (err u103))
(define-constant ERR-NOT-DUE (err u104))
(define-constant ERR-NOT-COLLATERALIZED (err u105))
(define-constant ERR-ALREADY-FUNDED (err u200))
(define-constant ERR-TRANSFER-FAILED (err u201))
(define-constant ERR-REPAY-FAILED (err u202))
(define-constant ERR-INVALID-AMOUNT (err u203))
(define-constant ERR-INVALID-BLOCK (err u204))
(define-constant ERR-INVALID-ID (err u205))
(define-constant ERR-INVALID-CONTRACT (err u206))
(define-constant ERR-UNAUTHORIZED (err u207))

;; Contract Data Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var min-block-time uint u1440)
(define-data-var loan-nonce uint u0)

;; Loan struct
(define-map loans
  {id: uint}
  {borrower: principal, 
   lender: (optional principal), 
   nft-id: uint, 
   principal: uint, 
   repay-amount: uint, 
   due-block: uint, 
   repaid: bool, 
   claimed: bool})

;; NFT token data
(define-map token-owners principal (list 1000 uint))
(define-map token-uris uint (string-ascii 256))
(define-data-var last-token-id uint u0)

;; NFT trait functions
(define-read-only (get-last-token-id)
  (ok (var-get last-token-id)))

(define-read-only (get-token-uri (id uint))
  (ok (map-get? token-uris id)))

(define-read-only (get-owner (id uint))
  (ok (some tx-sender)))

(define-public (transfer (id uint) (sender principal) (recipient principal))
  (let ((owner tx-sender))
    (if (is-eq owner sender)
        (ok true)
        (err u207))))

;; Borrower locks NFT as collateral, defines terms
(define-public (create-loan (nft-id uint) (loan-principal uint) (loan-repay uint) (loan-due uint))
  (begin
    (asserts! (and (> loan-principal u0) (>= loan-repay loan-principal)) ERR-INVALID-AMOUNT)
    (asserts! (> loan-due (var-get min-block-time)) ERR-INVALID-BLOCK)
    (asserts! (>= u4294967295 nft-id) ERR-INVALID-ID)
    (let ((next-id (+ (var-get loan-nonce) u1)))
      (var-set loan-nonce next-id)
      (ok (map-set loans 
        {id: next-id}
        {borrower: tx-sender, 
         lender: none, 
         nft-id: nft-id, 
         principal: loan-principal, 
         repay-amount: loan-repay, 
         due-block: loan-due, 
         repaid: false, 
         claimed: false})))))

;; Lender funds the loan
(define-public (fund-loan (id uint))
  (begin
    (asserts! (and (> id u0) (<= id (var-get loan-nonce))) ERR-INVALID-ID)
    (let ((loan (unwrap! (map-get? loans {id: id}) ERR-NOT-FOUND)))
      (begin
        (asserts! (is-none (get lender loan)) ERR-ALREADY-FUNDED)
        (try! (stx-transfer? (get principal loan) tx-sender (get borrower loan)))
        (ok (map-set loans 
          {id: id}
          {borrower: (get borrower loan), 
           lender: (some tx-sender), 
           nft-id: (get nft-id loan), 
           principal: (get principal loan), 
           repay-amount: (get repay-amount loan), 
           due-block: (get due-block loan), 
           repaid: false, 
           claimed: false}))))))

;; Borrower repays the loan
(define-public (repay-loan (id uint))
  (begin
    (asserts! (and (> id u0) (<= id (var-get loan-nonce))) ERR-INVALID-ID)
    (let ((loan (unwrap! (map-get? loans {id: id}) ERR-NOT-FOUND)))
      (begin
        (asserts! (is-eq tx-sender (get borrower loan)) ERR-NOT-BORROWER)
        (asserts! (and (not (get repaid loan)) (is-some (get lender loan))) ERR-ALREADY-REPAID)
        (let ((lender-addr (unwrap-panic (get lender loan))))
          (try! (stx-transfer? (get repay-amount loan) tx-sender lender-addr))
          (ok (map-set loans 
            {id: id}
            {borrower: (get borrower loan), 
             lender: (get lender loan), 
             nft-id: (get nft-id loan), 
             principal: (get principal loan), 
             repay-amount: (get repay-amount loan), 
             due-block: (get due-block loan), 
             repaid: true, 
             claimed: false})))))))

;; Lender claims NFT if borrower defaults
(define-public (claim-collateral (id uint))
  (begin
    (asserts! (and (> id u0) (<= id (var-get loan-nonce))) ERR-INVALID-ID)
    (let ((loan (unwrap! (map-get? loans {id: id}) ERR-NOT-FOUND)))
      (begin
        (asserts! (is-some (get lender loan)) ERR-NOT-LENDER)
        (asserts! (> (stx-get-balance tx-sender) (get due-block loan)) ERR-NOT-DUE)
        (asserts! (not (or (get repaid loan) (get claimed loan))) ERR-ALREADY-REPAID)
        (ok (map-set loans 
          {id: id}
          {borrower: (get borrower loan), 
           lender: (get lender loan), 
           nft-id: (get nft-id loan), 
           principal: (get principal loan), 
           repay-amount: (get repay-amount loan), 
           due-block: (get due-block loan), 
           repaid: (get repaid loan), 
           claimed: true}))))))

;; View loan details
(define-read-only (get-loan (id uint))
  (begin
    (asserts! (and (> id u0) (<= id (var-get loan-nonce))) ERR-INVALID-ID)
    (match (map-get? loans {id: id})
      loan (ok loan)
      ERR-NOT-FOUND)))