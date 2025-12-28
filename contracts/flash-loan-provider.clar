;; Title: Flash Loan Provider
;; Description: Provides temporary STX liquidity for the duration of a single transaction.

;; Trait for flash loan recipients
(define-trait flash-loan-recipient
    (
        (execute-flash-loan (uint) (response bool uint))
    )
)

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-REPAYMENT (err u101))
(define-constant FEE-BASIS-POINTS u10) ;; 0.1% fee

;; Public Functions
(define-public (flash-loan (amount uint) (recipient <flash-loan-recipient>))
    (let
        ((initial-balance (stx-get-balance (as-contract tx-sender)))
         (fee (/ (* amount FEE-BASIS-POINTS) u10000)))
        
        ;; 1. Send funds to recipient
        (try! (as-contract (stx-transfer? amount tx-sender (contract-of recipient))))
        
        ;; 2. Recipient executes logic
        (try! (contract-call? recipient execute-flash-loan amount))
        
        ;; 3. Ensure funds are returned with fee
        (let ((final-balance (stx-get-balance (as-contract tx-sender))))
            (asserts! (>= final-balance (+ initial-balance fee)) ERR-INSUFFICIENT-REPAYMENT)
            (ok true)
        )
    )
)

;; Allows deposits to the pool
(define-public (deposit (amount uint))
    (stx-transfer? amount tx-sender (as-contract tx-sender))
)
