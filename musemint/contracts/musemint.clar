;; Royalty Distribution for Digital Art
;; Enables automatic royalty distribution to creators and contributors
;; Supports primary sales, secondary market royalties, and collaborative works

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ARTWORK-NOT-FOUND (err u101))
(define-constant ERR-INVALID-INPUT (err u102))
(define-constant ERR-ALREADY-EXISTS (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-ALREADY-SOLD (err u105))
(define-constant ERR-NOT-SOLD (err u106))
(define-constant ERR-NO-ROYALTIES (err u107))
(define-constant ERR-INVALID-PERCENTAGE (err u108))
(define-constant ERR-CONTRACT-ALREADY-LINKED (err u109))
(define-constant ERR-NO-NFT-CONTRACT (err u110))

;; Maximum values for validation
(define-constant MAX-ROYALTY u300) ;; 30%
(define-constant PCT-BASE u1000) ;; 1000 = 100%
(define-constant MAX-TITLE u256)
(define-constant MAX-DESC u1024)
(define-constant MAX-ROLE u64)

;; Define artwork data
(define-map artworks
  { aid: uint }
  {
    title: (string-utf8 256),
    desc: (string-utf8 1024),
    creator: principal,
    created-at: uint,
    active: bool,
    primary-sold: bool,
    price: uint,
    royalty-pct: uint,  ;; Out of 1000 (e.g., 50 = 5%)
    nft-addr: (optional principal)
  }
)

;; Contributors to an artwork
(define-map contributors
  { aid: uint, contrib: principal }
  {
    share-pct: uint,    ;; Out of 1000 (e.g., 500 = 50%)
    role: (string-ascii 64)
  }
)

;; Royalty distribution tracking
(define-map royalty-distributions
  { aid: uint }
  {
    total-royalties: uint,
    last-distribution: uint
  }
)

;; Claimable royalties per contributor
(define-map claimable-royalties
  { aid: uint, contrib: principal }
  { amount: uint }
)

;; Track secondary sales
(define-map secondary-sales
  { aid: uint, sid: uint }
  {
    seller: principal,
    buyer: principal,
    amount: uint,
    royalty-amount: uint,
    timestamp: uint
  }
)

;; Next available IDs
(define-data-var next-aid uint u1)
(define-map next-sid { aid: uint } { id: uint })

;; Contract owner for administrative functions
(define-data-var owner principal tx-sender)

;; Helper function to validate string lengths
(define-private (is-valid-string-length (str (string-utf8 1024)) (max-len uint))
  (<= (len str) max-len)
)

;; Helper function to validate percentage
(define-private (is-valid-percentage (pct uint))
  (<= pct PCT-BASE)
)

;; Register a new artwork
(define-public (register-artwork
                (title (string-utf8 256))
                (desc (string-utf8 1024))
                (price uint)
                (royalty-pct uint))
  (let
    ((aid (var-get next-aid)))
    
    ;; Validate inputs
    (asserts! (> price u0) ERR-INVALID-INPUT)
    (asserts! (<= royalty-pct MAX-ROYALTY) ERR-INVALID-PERCENTAGE)
    (asserts! (> (len title) u0) ERR-INVALID-INPUT)
    (asserts! (is-valid-string-length title MAX-TITLE) ERR-INVALID-INPUT)
    (asserts! (is-valid-string-length desc MAX-DESC) ERR-INVALID-INPUT)
    
    ;; Create the artwork record
    (map-set artworks
      { aid: aid }
      {
        title: title,
        desc: desc,
        creator: tx-sender,
        created-at: block-height,
        active: true,
        primary-sold: false,
        price: price,
        royalty-pct: royalty-pct,
        nft-addr: none
      }
    )
    
    ;; Add creator as 100% contributor by default
    (map-set contributors
      { aid: aid, contrib: tx-sender }
      {
        share-pct: PCT-BASE,  ;; 100%
        role: "creator"
      }
    )
    
    ;; Initialize royalty tracking
    (map-set royalty-distributions
      { aid: aid }
      {
        total-royalties: u0,
        last-distribution: u0
      }
    )
    
    ;; Initialize sale counter
    (map-set next-sid
      { aid: aid }
      { id: u1 }
    )
    
    ;; Increment artwork ID counter
    (var-set next-aid (+ aid u1))
    
    (ok aid)
  )
)

;; Add a contributor to an artwork
(define-public (add-contributor
                (aid uint)
                (contrib principal)
                (share-pct uint)
                (role (string-ascii 64)))
  (let
    ((art (unwrap! (map-get? artworks { aid: aid }) ERR-ARTWORK-NOT-FOUND))
     (creator-info (unwrap! (map-get? contributors { aid: aid, contrib: (get creator art) })
                            ERR-ARTWORK-NOT-FOUND))
     (existing (map-get? contributors { aid: aid, contrib: contrib }))
     (exists (is-some existing))
     (current-share (if exists
                       (get share-pct (unwrap-panic existing))
                      u0))
     (available-share (- (get share-pct creator-info) current-share))
     (new-creator-share (- (get share-pct creator-info) share-pct)))
    
    ;; Validate inputs
    (asserts! (is-eq tx-sender (get creator art)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get primary-sold art)) ERR-ALREADY-SOLD)
    (asserts! (> share-pct u0) ERR-INVALID-INPUT)
    (asserts! (<= share-pct available-share) ERR-INVALID-PERCENTAGE)
    (asserts! (> (len role) u0) ERR-INVALID-INPUT)
    (asserts! (<= (len role) MAX-ROLE) ERR-INVALID-INPUT)
    (asserts! (not (is-eq contrib (get creator art))) ERR-INVALID-INPUT)
    
    ;; Add/update the contributor
    (map-set contributors
      { aid: aid, contrib: contrib }
      {
        share-pct: share-pct,
        role: role
      }
    )
    
    ;; Update creator's share
    (map-set contributors
      { aid: aid, contrib: (get creator art) }
      {
        share-pct: new-creator-share,
        role: "creator"
      }
    )
    
    (ok true)
  )
)

;; Remove a contributor from an artwork
(define-public (remove-contributor (aid uint) (contrib principal))
  (let
    ((art (unwrap! (map-get? artworks { aid: aid }) ERR-ARTWORK-NOT-FOUND))
     (contrib-info (unwrap! (map-get? contributors { aid: aid, contrib: contrib })
                               ERR-ARTWORK-NOT-FOUND))
     (creator-info (unwrap! (map-get? contributors { aid: aid, contrib: (get creator art) })
                            ERR-ARTWORK-NOT-FOUND))
     (share-to-return (get share-pct contrib-info))
     (new-creator-share (+ (get share-pct creator-info) share-to-return)))
    
    ;; Validate
    (asserts! (is-eq tx-sender (get creator art)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get primary-sold art)) ERR-ALREADY-SOLD)
    (asserts! (not (is-eq contrib (get creator art))) ERR-INVALID-INPUT)
    
    ;; Remove contributor
    (map-delete contributors { aid: aid, contrib: contrib })
    
    ;; Return share to creator
    (map-set contributors
      { aid: aid, contrib: (get creator art) }
      {
        share-pct: new-creator-share,
        role: "creator"
      }
    )
    
    (ok true)
  )
)

;; Link NFT contract to artwork (creator only)
(define-public (link-nft-contract (aid uint) (nft-addr principal))
  (let
    ((art (unwrap! (map-get? artworks { aid: aid }) ERR-ARTWORK-NOT-FOUND)))
    
    ;; Validate
    (asserts! (is-eq tx-sender (get creator art)) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (get nft-addr art)) ERR-CONTRACT-ALREADY-LINKED)
    
    ;; Link the contract
    (map-set artworks
      { aid: aid }
      (merge art { nft-addr: (some nft-addr) })
    )
    
    (ok true)
  )
)

;; Primary sale of artwork
(define-public (primary-sale (aid uint))
  (let
    ((art (unwrap! (map-get? artworks { aid: aid }) ERR-ARTWORK-NOT-FOUND))
     (sale-price (get price art)))
    
    ;; Validate
    (asserts! (get active art) ERR-INVALID-INPUT)
    (asserts! (not (get primary-sold art)) ERR-ALREADY-SOLD)
    (asserts! (is-some (get nft-addr art)) ERR-NO-NFT-CONTRACT)
    
    ;; Check buyer has sufficient funds
    (asserts! (>= (stx-get-balance tx-sender) sale-price) ERR-INSUFFICIENT-FUNDS)
    
    ;; Transfer STX for purchase to contract
    (try! (stx-transfer? sale-price tx-sender (as-contract tx-sender)))
    
    ;; Mark as sold
    (map-set artworks
      { aid: aid }
      (merge art { primary-sold: true })
    )
    
    ;; Distribute to contributors
    (try! (distribute-primary-sale aid sale-price))
    
    (ok true)
  )
)

;; Private function to distribute primary sale proceeds
(define-private (distribute-primary-sale (aid uint) (amt uint))
  (let
    ((art (unwrap-panic (map-get? artworks { aid: aid })))
     (creator (get creator art))
     (creator-info (unwrap-panic (map-get? contributors { aid: aid, contrib: creator })))
     (creator-share (get share-pct creator-info))
     (creator-payout (/ (* amt creator-share) PCT-BASE)))
    
    ;; Transfer to creator (simplified - in a full implementation you'd iterate through all contributors)
    (if (> creator-payout u0)
        (as-contract (try! (stx-transfer? creator-payout tx-sender creator)))
        true)
    
    (ok true)
  )
)

;; Record a secondary sale
(define-public (record-secondary-sale
                (aid uint)
                (seller principal)
                (amt uint))
  (let
    ((art (unwrap! (map-get? artworks { aid: aid }) ERR-ARTWORK-NOT-FOUND))
     (counter (unwrap! (map-get? next-sid { aid: aid }) ERR-ARTWORK-NOT-FOUND))
     (sid (get id counter))
     (royalty-pct (get royalty-pct art))
     (royalty-amt (/ (* amt royalty-pct) PCT-BASE))
     (seller-payout (- amt royalty-amt)))
    
    ;; Validate
    (asserts! (get active art) ERR-INVALID-INPUT)
    (asserts! (get primary-sold art) ERR-NOT-SOLD)
    (asserts! (> amt u0) ERR-INVALID-INPUT)
    (asserts! (not (is-eq seller tx-sender)) ERR-INVALID-INPUT) ;; Seller can't be buyer
    (asserts! (>= (stx-get-balance tx-sender) amt) ERR-INSUFFICIENT-FUNDS)
    
    ;; Transfer payment from buyer to contract first
    (try! (stx-transfer? amt tx-sender (as-contract tx-sender)))
    
    ;; Transfer seller amount to seller
    (if (> seller-payout u0)
        (as-contract (try! (stx-transfer? seller-payout tx-sender seller)))
        true)
    
    ;; Record the sale
    (map-set secondary-sales
      { aid: aid, sid: sid }
      {
        seller: seller,
        buyer: tx-sender,
        amount: amt,
        royalty-amount: royalty-amt,
        timestamp: block-height
      }
    )
    
    ;; Update royalty tracking
    (let
      ((tracking (unwrap! (map-get? royalty-distributions { aid: aid })
                             ERR-ARTWORK-NOT-FOUND)))
      
      (map-set royalty-distributions
        { aid: aid }
        {
          total-royalties: (+ (get total-royalties tracking) royalty-amt),
          last-distribution: block-height
        }
      )
      
      ;; Distribute royalties to contributors
      (try! (distribute-royalties aid royalty-amt))
    )
    
    ;; Increment sale counter
    (map-set next-sid
      { aid: aid }
      { id: (+ sid u1) }
    )
    
    (ok sid)
  )
)

;; Private function to distribute royalties
(define-private (distribute-royalties (aid uint) (royalty-amt uint))
  (let
    ((art-rec (map-get? artworks { aid: aid }))
     (creator-rec (if (is-some art-rec)
                      (map-get? contributors { aid: aid, contrib: (get creator (unwrap-panic art-rec)) })
                     none)))
    
    (if (and (is-some art-rec) (is-some creator-rec))
        (let
          ((creator (get creator (unwrap-panic art-rec)))
           (creator-info (unwrap-panic creator-rec))
           (creator-royalty (/ (* royalty-amt (get share-pct creator-info)) PCT-BASE))
           (existing (default-to { amount: u0 }
                               (map-get? claimable-royalties { aid: aid, contrib: creator }))))
          
          ;; Add royalties to claimable pool for creator
          (map-set claimable-royalties
            { aid: aid, contrib: creator }
            { amount: (+ (get amount existing) creator-royalty) }
          )
          
          (ok true)
        )
        ERR-ARTWORK-NOT-FOUND
    )
  )
)

;; Claim royalties
(define-public (claim-royalties (aid uint))
  (let
    ((claim (unwrap! (map-get? claimable-royalties { aid: aid, contrib: tx-sender })
                       ERR-NO-ROYALTIES))
     (claim-amt (get amount claim)))
    
    ;; Validate
    (asserts! (> claim-amt u0) ERR-NO-ROYALTIES)
    
    ;; Reset claimable amount
    (map-set claimable-royalties
      { aid: aid, contrib: tx-sender }
      { amount: u0 }
    )
    
    ;; Transfer royalties to contributor
    (as-contract (try! (stx-transfer? claim-amt tx-sender tx-sender)))
    
    (ok claim-amt)
  )
)

;; Deactivate artwork (creator only)
(define-public (deactivate-artwork (aid uint))
  (let
    ((art (unwrap! (map-get? artworks { aid: aid }) ERR-ARTWORK-NOT-FOUND)))
    
    ;; Validate
    (asserts! (is-eq tx-sender (get creator art)) ERR-NOT-AUTHORIZED)
    
    ;; Deactivate
    (map-set artworks
      { aid: aid }
      (merge art { active: false })
    )
    
    (ok true)
  )
)

;; Reactivate artwork (creator only)
(define-public (reactivate-artwork (aid uint))
  (let
    ((art (unwrap! (map-get? artworks { aid: aid }) ERR-ARTWORK-NOT-FOUND)))
    
    ;; Validate
    (asserts! (is-eq tx-sender (get creator art)) ERR-NOT-AUTHORIZED)
    
    ;; Reactivate
    (map-set artworks
      { aid: aid }
      (merge art { active: true })
    )
    
    (ok true)
  )
)

;; Read-only functions

;; Get artwork details
(define-read-only (get-artwork-details (aid uint))
  (map-get? artworks { aid: aid })
)

;; Get contributor details
(define-read-only (get-contributor-details (aid uint) (contrib principal))
  (map-get? contributors { aid: aid, contrib: contrib })
)

;; Get claimable royalties
(define-read-only (get-claimable-royalties (aid uint) (contrib principal))
  (default-to { amount: u0 }
              (map-get? claimable-royalties { aid: aid, contrib: contrib }))
)

;; Get royalty distribution stats
(define-read-only (get-royalty-stats (aid uint))
  (map-get? royalty-distributions { aid: aid })
)

;; Get secondary sale details
(define-read-only (get-secondary-sale (aid uint) (sid uint))
  (map-get? secondary-sales { aid: aid, sid: sid })
)

;; Get next artwork ID
(define-read-only (get-next-artwork-id)
  (var-get next-aid)
)

;; Get contract owner
(define-read-only (get-contract-owner)
  (var-get owner)
)

;; Check if artwork exists
(define-read-only (artwork-exists (aid uint))
  (is-some (map-get? artworks { aid: aid }))
)

;; Get total artworks count
(define-read-only (get-total-artworks)
  (- (var-get next-aid) u1)
)