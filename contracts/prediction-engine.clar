;; Title: Prediction Market Engine
;; Description: Allows users to create markets and bet on outcomes.

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-MARKET-CLOSED (err u101))

;; Data Maps
(define-map markets
    uint
    {
        question: (string-ascii 128),
        creator: principal,
        total-pool: uint,
        status: (string-ascii 10), ;; "OPEN", "CLOSED", "RESOLVED"
        outcome: (optional bool)
    }
)

(define-map bets 
    { market-id: uint, user: principal } 
    { amount: uint, pred: bool }
)

(define-data-var market-nonce uint u0)

;; Public Functions
(define-public (create-market (question (string-ascii 128)))
    (let ((id (var-get market-nonce)))
        (map-set markets id {
            question: question,
            creator: tx-sender,
            total-pool: u0,
            status: "OPEN",
            outcome: none
        })
        (var-set market-nonce (+ id u1))
        (ok id)
    )
)

(define-public (place-bet (id uint) (amount uint) (prediction bool))
    (let ((market (unwrap! (map-get? markets id) (err u102))))
        (asserts! (is-eq (get status market) "OPEN") ERR-MARKET-CLOSED)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set bets { market-id: id, user: tx-sender } { amount: amount, pred: prediction })
        (map-set markets id (merge market { total-pool: (+ (get total-pool market) amount) }))
        (ok true)
    )
)

(define-public (resolve-market (id uint) (outcome bool))
    (let ((market (unwrap! (map-get? markets id) (err u102))))
        (asserts! (is-eq tx-sender (get creator market)) ERR-NOT-AUTHORIZED)
        (map-set markets id (merge market { status: "RESOLVED", outcome: (some outcome) }))
        (ok true)
    )
)
