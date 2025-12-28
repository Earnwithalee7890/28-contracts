;; Title: Liquid Staking Token (LST)
;; Description: A SIP-010 token representing staked STX, enabling liquidity while earning rewards.

(impl-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

(define-fungible-token stSTX)

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant CONTRACT-OWNER tx-sender)

;; SIP-010 Functions
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (ft-transfer? stSTX amount sender recipient)
    )
)

(define-read-only (get-name) (ok "Liquid Staked STX"))
(define-read-only (get-symbol) (ok "stSTX"))
(define-read-only (get-decimals) (ok u6))
(define-read-only (get-balance (user principal)) (ok (ft-get-balance stSTX user)))
(define-read-only (get-total-supply) (ok (ft-get-supply stSTX)))
(define-read-only (get-token-uri) (ok none))

;; Staking Logic
(define-public (stake (amount uint))
    (begin
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (ft-mint? stSTX amount tx-sender)
    )
)

(define-public (unstake (amount uint))
    (begin
        (try! (ft-burn? stSTX amount tx-sender))
        (as-contract (stx-transfer? amount tx-sender tx-sender))
    )
)

;; Reward logic (pseudo)
(define-public (distribute-rewards (total-reward uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        ;; In a real LST, this would adjust the exchange rate or mint more tokens
        (ok true)
    )
)
