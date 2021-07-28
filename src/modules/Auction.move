address 0xbd7e8be8fae9f60f2f5136433e36a091 {
/// The <Auction> module defined some struct of auction
module Auction {
    use 0x1::Signer;
    use 0x1::Account;
    use 0x1::Errors;
    use 0x1::Token;
    use 0x1::Option;
    use 0x1::Timestamp;
    use 0x1::Event;

    use 0xbd7e8be8fae9f60f2f5136433e36a091::Auc;
    use 0xbd7e8be8fae9f60f2f5136433e36a091::AucTokenUtil;

    ///
    /// Auction state
    ///
    const INIT: u8 = 0;
    const PENDING: u8 = 1;
    const BIDDING: u8 = 2;
    const UNDER_REVERSE: u8 = 4;
    const NO_BID: u8 = 5;
    const CONFIRM: u8 = 6;

    ///
    /// Auction error code
    ///
    const ERR_AUCTION_ID_MISMATCH: u64 = 10001;
    const ERR_AUCTION_EXISTS_ALREADY: u64 = 10002;
    const ERR_AUCTION_NOT_EXISTS: u64 = 10003;
    const ERR_AUCTION_INVALID_STATE: u64 = 10004;
    const ERR_AUCTION_INVALID_SELLER: u64 = 10005;
    const ERR_AUCTION_BID_REPEATE: u64 = 10006;

    struct AuctionCreatedEvent has drop, store {
        creator: address,
    }

    struct AuctionCompletedEvent has drop, store {
        creator: address,
    }

    struct AuctionBidedEvent has drop, store {
        creator: address,
        bidder: address,
        bid_price: u128,
    }

    ///
    /// Auction data struct.
    struct Auction<ObjectiveTokenT> has key {
        /// Start auction time
        start_time: u64,
        /// End auction time
        end_time: u64,
        /// Start price
        start_price, u128,
        /// Reverse price
        reserve_price: u128,
        /// Increase price, each bid price number must several time of this number
        increments_price: u128,
        /// Hammer price, user can buy objective at this price
        hammer_price: u128,
        /// After user called hammer_price, this value is true
        hammer_locked: bool,

        /// seller informations
        seller: Option::Option<address>,
        seller_deposit: Token::Token<Auc::Auc>,
        seller_objective: Token::Token<ObjectiveTokenT>,

        /// buyer informations
        buyer: Option::Option<address>,
        buyer_bid_reserve: Token::Token<Auc::Auc>,

        /// event stream for create
        auction_created_events: Event::EventHandle<AuctionCreatedEvent>,
        /// event stream for bid
        auction_bid_events: Event::EventHandle<AuctionBidedEvent>,
        /// event stream for auction completed
        auction_completed_events: Event::EventHandle<AuctionCompletedEvent>,
    }

    //////////////////////////////////////////////////////////////////////////////
    // Internal fucntions

    fun do_auction_state<ObjectiveTokenT: copy + drop + store>(auction: &Auction<ObjectiveTokenT>,
                                                               current_time: u64): u8 {
        if (Token::value<ObjectiveTokenT>(&auction.seller_objective) <= 0 ||
                Token::value<Auc::Auc>(&auction.seller_deposit) <= 0) {
            INIT
        } else if (auction.hammer_locked) {
            CONFIRM
        } else if (current_time < auction.start_time) {
            PENDING
        } else if (current_time <= auction.end_time) {
            BIDDING
        } else if (Token::value<Auc::Auc>(&auction.buyer_bid_reserve) <= auction.reserve_price) {
            UNDER_REVERSE
        } else {
            CONFIRM
        }
    }

    /// check whether a proposal exists in `proposer_address`
    fun auction_exists<ObjectiveTokenT: copy + drop + store>(
        auction_address: address
    ): bool {
        exists<Auction<ObjectiveTokenT>>(auction_address)
    }

    //////////////////////////////////////////////////////////////////////////////
    /// public functions

    ///
    /// Create auction for current signer
    ///
    public fun create<ObjectiveTokenT: copy + drop + store>(account: &signer,
                                                            start_time: u64,
                                                            end_time: u64,
                                                            start_price: u128,
                                                            reserve_price: u128,
                                                            increments_price: u128,
                                                            hammer_price: u128) {
        assert(!auction_exists<ObjectiveTokenT>(Signer::address_of(account)),
            Errors::invalid_argument(ERR_AUCTION_EXISTS_ALREADY));

        let auction = Auction<ObjectiveTokenT> {
            start_time,
            end_time,
            start_price,
            reserve_price,
            increments_price,
            hammer_price,
            hammer_locked: false,
            seller: Option::none<address>(),
            seller_objective: Token::zero<ObjectiveTokenT>(),
            seller_deposit: Token::zero<Auc::Auc>(),
            buyer: Option::none<address>(),
            buyer_bid_reserve: Token::zero<Auc::Auc>(),
            auction_created_events: Event::new_event_handle<AuctionCreatedEvent>(account),
            auction_bid_events: Event::new_event_handle<AuctionBidedEvent>(account),
            auction_completed_events: Event::new_event_handle<AuctionCompletedEvent>(account),
        };

        // Publish AuctionCreated event
        Event::emit_event(
            &mut auction.auction_created_events,
            AuctionCreatedEvent {
                creator: Signer::address_of(account),
            },
        );
        move_to(account, auction);
    }

    /// Drop auction if caller is owner
    public fun destruct<ObjectiveTokenT: copy + drop + store>(account : &signer) {
        assert(auction_exists<ObjectiveTokenT>(Signer::address_of(account)),
            Errors::invalid_argument(ERR_AUCTION_NOT_EXISTS));
        // TODO:
    }


    ///
    /// Auction `mortgage` (call by creator)
    ///
    public fun deposit<ObjectiveTokenT: copy + drop + store>(
        account: &signer,
        creator: address,
        objective: Token::Token<ObjectiveTokenT>,
        deposit_price: u128) acquires Auction {
        let auction = borrow_global_mut<Auction<ObjectiveTokenT>>(creator);
        let current_time = Timestamp::now_milliseconds();
        let state = do_auction_state<ObjectiveTokenT>(auction, current_time);
        assert(state == INIT, Errors::invalid_argument(ERR_AUCTION_INVALID_STATE));
        assert(deposit_price >= auction.start_price, Errors::invalid_argument(ERR_AUCTION_INSUFFICIENT_DEPOSIT));

        // Deposit object
        Token::deposit(&mut auction.seller_objective, objective);

        // Deposit token
        let depsit_token = Account::withdraw<Auc::Auc>(account, deposit_price);
        Token::deposit(&mut auction.seller_deposit, depsit_token    );

        auction.seller = Option::some<address>(Signer::address_of(account));
    }


    public fun auction_state<ObjectiveTokenT: copy + drop + store>(
        creator: address): u8 acquires Auction {
        let auction = borrow_global<Auction<ObjectiveTokenT>>(creator);
        let current_time = Timestamp::now_milliseconds();
        do_auction_state<ObjectiveTokenT>(auction, current_time)
    }

    public fun bid<ObjectiveTokenT: copy + drop + store>(account: &signer,
                                                         creator: address,
                                                         bid_price: u128) acquires Auction {
        let auction = borrow_global_mut<Auction<ObjectiveTokenT>>(creator);
        let current_time = Timestamp::now_milliseconds();
        let state = do_auction_state<ObjectiveTokenT>(auction, current_time);
        assert(state == BIDDING, Errors::invalid_state(ERR_AUCTION_INVALID_STATE));
        assert(Option::extract(&mut auction.buyer) != Signer::address_of(account),
            Errors::invalid_argument(ERR_AUCTION_BID_REPEATE));

        // Retreat bid deposit token to latest buyer who has bidden.
        let bid_reverse_amount = Token::value<Auc::Auc>(&auction.buyer_bid_reserve);
        assert(bid_price >= auction.reverse_price, );

        if (!Option::is_none(&auction.buyer) && bid_reverse_amount > 0) {
            let bid_reverse = Token::withdraw<Auc::Auc>(&mut auction.buyer_bid_reserve, bid_reverse_amount);
            Account::deposit(Option::extract(&mut auction.buyer), bid_reverse);
        };

        // Put bid user to current buyer, Get AUC token from user and deposit it to auction.
        let token = Account::withdraw<Auc::Auc>(account, bid_price);
        Token::deposit<Auc::Auc>(&mut auction.buyer_bid_reserve, token);
        auction.buyer = Option::some(Signer::address_of(account));


        // Publish AuctionBid event
        Event::emit_event(
            &mut auction.auction_bid_events,
            AuctionBidedEvent {
                bidder: Signer::address_of(account),
                creator,
                bid_price,
            },
        );
    }

    ///
    /// Complete the auction and clean up resources
    /// Seller:
    /// If successful, get back the auction money and deposit;
    /// if it fails, get back the objective
    ///
    /// Buyer:
    /// If successful, get back the subject matter.
    /// If it fails, get back the objective
    ///
    public fun completed<ObjectiveTokenT: copy + drop + store>(
        account: &signer,
        creator: address) acquires Auction {
        let auction = borrow_global_mut<Auction<ObjectiveTokenT>>(creator);
        let current_time = Timestamp::now_milliseconds();
        let state = do_auction_state<ObjectiveTokenT>(auction, current_time);
        assert(state == NO_BID || state == CONFIRM || state == UNDER_REVERSE,
            Errors::invalid_argument(ERR_AUCTION_INVALID_STATE));

        // Bid succeed.
        if (state == CONFIRM) {
            // Put bid amount to seller
            AucTokenUtil::extract_from_reverse(
                Option::extract(&mut auction.seller),
                &mut auction.buyer_bid_reserve);

            AucTokenUtil::extract_from_reverse(
                Option::extract(&mut auction.seller),
                &mut auction.seller_deposit);

            // Put sell objective to buyer
            AucTokenUtil::extract_from_reverse(
                Option::extract(&mut auction.buyer),
                &mut auction.seller_objective);
        } else if (state == NO_BID || state == UNDER_REVERSE) {
            // Retreat last buyer bid deposit token if there has bid
            if (!Option::is_none(&auction.buyer) &&
                    !AucTokenUtil::none_zero(&auction.buyer_bid_reserve)) {
                AucTokenUtil::extract_from_reverse(
                    Option::extract(&mut auction.buyer),
                    &mut auction.buyer_bid_reserve);
            };

            // Retreat seller's assets
            AucTokenUtil::extract_from_reverse(
                Option::extract(&mut auction.seller),
                &mut auction.seller_deposit);

            AucTokenUtil::extract_from_reverse(
                Option::extract(&mut auction.seller),
                &mut auction.seller_objective);
        };

        // Publish AuctionCompleted event
        Event::emit_event(
            &mut auction.auction_bid_events,
            AuctionCompletedEvent {
                bidder: Signer::address_of(account),
                creator,
                bid_price,
            },
        );
    }

    public fun auction_info<ObjectiveTokenT: copy + drop + store>(creator: address): (u64, u64, u128, u128, u128, u8) acquires Auction {
        let auction = borrow_global_mut<Auction<ObjectiveTokenT>>(creator);
        let current_time = Timestamp::now_milliseconds();
        let state = do_auction_state<ObjectiveTokenT>(auction, current_time);
        (
            auction.start_time,
            auction.end_time,
            auction.reserve_price,
            auction.increments_price,
            auction.hammer_price,
            state
        )
    }

    /// Buy objective with one price
    public fun hammer_buy(_account: &signer) {
        // TODO
    }

    fun platform_addr(): address {
        @0xbd7e8be8fae9f60f2f5136433e36a091
    }
}
}