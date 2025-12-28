;; Title: Decentralized Arbitration (Court)
;; Description: A platform for resolving disputes through decentralized voting by "jurors".

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-DISPUTE-NOT-FOUND (err u101))
(define-constant ERR-VOTING-CLOSED (err u102))

;; Data Maps
(define-map disputes
    uint
    {
        claimant: principal,
        respondent: principal,
        evidence-url: (string-ascii 256),
        status: (string-ascii 20),
        votes-for: uint,
        votes-against: uint,
        end-height: uint
    }
)

(define-map juror-votes { dispute-id: uint, juror: principal } bool)

(define-data-var dispute-nonce uint u0)

;; Public Functions
(define-public (raise-dispute (respondent principal) (evidence (string-ascii 256)))
    (let
        ((id (var-get dispute-nonce)))
        (map-set disputes id {
            claimant: tx-sender,
            respondent: respondent,
            evidence-url: evidence,
            status: "OPEN",
            votes-for: u0,
            votes-against: u0,
            end-height: (+ stacks-block-height u1008) ;; ~1 week
        })
        (var-set dispute-nonce (+ id u1))
        (ok id)
    )
)

(define-public (vote-on-dispute (id uint) (vote-for bool))
    (let
        ((dispute (unwrap! (map-get? disputes id) ERR-DISPUTE-NOT-FOUND)))
        (asserts! (< stacks-block-height (get end-height dispute)) ERR-VOTING-CLOSED)
        (asserts! (is-none (map-get? juror-votes { dispute-id: id, juror: tx-sender })) (err u103))
        
        (map-set juror-votes { dispute-id: id, juror: tx-sender } vote-for)
        (if vote-for
            (map-set disputes id (merge dispute { votes-for: (+ (get votes-for dispute) u1) }))
            (map-set disputes id (merge dispute { votes-against: (+ (get votes-against dispute) u1) }))
        )
        (ok true)
    )
)

(define-public (finalize-dispute (id uint))
    (let
        ((dispute (unwrap! (map-get? disputes id) ERR-DISPUTE-NOT-FOUND)))
        (asserts! (>= stacks-block-height (get end-height dispute)) (err u104))
        
        (if (> (get votes-for dispute) (get votes-against dispute))
            (map-set disputes id (merge dispute { status: "CLAIMANT-WON" }))
            (map-set disputes id (merge dispute { status: "RESPONDENT-WON" }))
        )
        (ok true)
    )
)
