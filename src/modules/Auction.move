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
    use 0x1::Debug;

    use 0xbd7e8be8fae9f60f2f5136433e36a091::AucTokenUtil;

    ///
    /// Auction state
    ///
    const INIT: u8 = 0;
    const PENDING: u8 = 1;
    const BIDDING: u8 = 2;
    const UNDER_REVERSE: u8 = 3;
    const NO_BID: u8 = 4;
    const CONFIRM: u8 = 5;

    ///
    /// Auction error code
    ///
    const ERR_AUCTION_ID_MISMATCH: u64 = 10001;
    const ERR_AUCTION_EXISTS_ALREADY: u64 = 10002;
    const ERR_AUCTION_NOT_EXISTS: u64 = 10003;
    const ERR_AUCTION_INVALID_STATE: u64 = 10004;
    const ERR_AUCTION_INVALID_SELLER: u64 = 10005;
    const ERR_AUCTION_BID_REPEATE: u64 = 10006;
    const ERR_AUCTION_INSUFFICIENT_DEPOSIT : u64 = 1007;
    const ERR_AUCTION_BLOW_START_PRICE : u64 = 1008;
    const ERR_AUCTION_BID_RESERVE_NOT_CLEAN : u64 = 1009;
    const ERR_AUCTION_BID_CANNOT_BE_SELLER : u64 = 1010;

    struct AuctionCreatedEvent has drop, store {
        creator: address,
    }

    struct AuctionCompletedEvent has drop, store {
        creator: address,
    }

    struct AuctionPassedEvent has drop, store {
        creator: address,
    }

    struct AuctionBidedEvent has drop, store {
        creator: address,
        bidder: address,
        bid_price: u128,
    }

    ///
    /// Auction data struct.
    struct Auction<ObjectiveTokenT, BidTokenType> has key {
        /// Start auction time
        start_time: u64,
        /// End auction time
        end_time: u64,
        /// Start price
        start_price: u128,
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
        seller_deposit: Token::Token<BidTokenType>,
        seller_objective: Token::Token<ObjectiveTokenT>,

        /// buyer informations
        buyer: Option::Option<address>,
        buyer_bid_reserve: Token::Token<BidTokenType>,

        /// event stream for create
        auction_created_events: Event::EventHandle<AuctionCreatedEvent>,
        /// event stream for bid
        auction_bid_events: Event::EventHandle<AuctionBidedEvent>,
        /// event stream for auction completed
        auction_completed_events: Event::EventHandle<AuctionCompletedEvent>,
        /// event stream for auction completed
        auction_passed_events: Event::EventHandle<AuctionPassedEvent>,
    }

    //////////////////////////////////////////////////////////////////////////////
    // Internal fucntions

    fun do_auction_state<ObjectiveTokenT: copy + drop + store,
                         BidTokenType: copy + drop + store>(auction: &Auction<ObjectiveTokenT, BidTokenType>,
                                                            current_time: u64): u8 {
        if (Token::value<ObjectiveTokenT>(&auction.seller_objective) <= 0 ||
                Token::value<BidTokenType>(&auction.seller_deposit) <= 0) {
            INIT
        } else if (auction.hammer_locked) {
            CONFIRM
        } else if (current_time < auction.start_time) {
            PENDING
        } else if (current_time <= auction.end_time) {
            BIDDING
        } else if (Token::value<BidTokenType>(&auction.buyer_bid_reserve) <= auction.reserve_price) {
            UNDER_REVERSE
        } else {
            CONFIRM
        }
    }

    /// check whether a proposal exists in `proposer_address`
    fun auction_exists<ObjectiveTokenT: copy + drop + store,
                       BidTokenType: copy + drop + store>(
        auction_address: address
    ): bool {
        exists<Auction<ObjectiveTokenT, BidTokenType>>(auction_address)
    }

    //////////////////////////////////////////////////////////////////////////////
    /// public functions

    ///
    /// Create auction for current signer
    ///
    public fun create<ObjectiveTokenT: copy + drop + store,
                      BidTokenType: copy + drop + store>(account: &signer,
                                                         start_time: u64,
                                                         end_time: u64,
                                                         start_price: u128,
                                                         reserve_price: u128,
                                                         increments_price: u128,
                                                         hammer_price: u128) {
        assert(!auction_exists<ObjectiveTokenT, BidTokenType>(Signer::address_of(account)),
            Errors::invalid_argument(ERR_AUCTION_EXISTS_ALREADY));

        let auction = Auction<ObjectiveTokenT, BidTokenType> {
            start_time,
            end_time,
            start_price,
            reserve_price,
            increments_price,
            hammer_price,
            hammer_locked: false,
            seller: Option::none<address>(),
            seller_objective: Token::zero<ObjectiveTokenT>(),
            seller_deposit: Token::zero<BidTokenType>(),
            buyer: Option::none<address>(),
            buyer_bid_reserve: Token::zero<BidTokenType>(),
            auction_created_events: Event::new_event_handle<AuctionCreatedEvent>(account),
            auction_bid_events: Event::new_event_handle<AuctionBidedEvent>(account),
            auction_completed_events: Event::new_event_handle<AuctionCompletedEvent>(account),
            auction_passed_events: Event::new_event_handle<AuctionPassedEvent>(account),
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

    ///
    /// Drop auction if caller is owner
    ///
    public fun destroy<ObjectiveTokenT: copy + drop + store,
                       BidTokenType: copy + drop + store>(
        creator: address) acquires Auction {

        assert(auction_exists<ObjectiveTokenT, BidTokenType>(creator),
            Errors::invalid_argument(ERR_AUCTION_NOT_EXISTS));

        let auction = borrow_global_mut<Auction<ObjectiveTokenT, BidTokenType>>(creator);
        let current_time = Timestamp::now_milliseconds();
        let _state = do_auction_state(auction, current_time);

        // Debug::print(&22222222);

//        assert(_state == UNDER_REVERSE ||
//                _state == NO_BID ||
//                _state == CONFIRM, Errors::invalid_state(ERR_AUCTION_INVALID_STATE));

        let Auction {
            start_time: _,
            end_time: _,
            start_price: _,
            reserve_price: _,
            increments_price: _,
            hammer_price: _,
            hammer_locked: _,
            seller,
            seller_deposit,
            seller_objective,
            buyer,
            buyer_bid_reserve,
            auction_created_events,
            auction_bid_events,
            auction_completed_events,
            auction_passed_events,
        } = move_from<Auction<ObjectiveTokenT, BidTokenType>>(creator);

        //Debug::print(&33333333);

        let _ = Option::extract(&mut seller);
        Option::destroy_none(seller);

        let _ = Option::extract(&mut buyer);
        Option::destroy_none(buyer);

        //Debug::print(&44444444);

        Token::destroy_zero(seller_deposit);
        Token::destroy_zero(seller_objective);
        Token::destroy_zero(buyer_bid_reserve);

        Event::destroy_handle(auction_created_events);
        Event::destroy_handle(auction_bid_events);
        Event::destroy_handle(auction_completed_events);
        Event::destroy_handle(auction_passed_events);

        //Debug::print(&55555555);
    }

    ///
    /// Auction `mortgage` (call by creator)
    ///
    public fun deposit<ObjectiveTokenT: copy + drop + store,
                       BidTokenType: copy + drop + store>(
        account: &signer,
        creator: address,
        objective: Token::Token<ObjectiveTokenT>,
        deposit_price: u128) acquires Auction {
        let auction = borrow_global_mut<Auction<ObjectiveTokenT, BidTokenType>>(creator);
        let current_time = Timestamp::now_milliseconds();
        let state = do_auction_state(auction, current_time);
        assert(state == INIT, Errors::invalid_argument(ERR_AUCTION_INVALID_STATE));
        assert(deposit_price >= auction.start_price, Errors::invalid_argument(ERR_AUCTION_INSUFFICIENT_DEPOSIT));

        // Deposit object
        Token::deposit(&mut auction.seller_objective, objective);

        // Deposit token
        let depsit_token = Account::withdraw<BidTokenType>(account, deposit_price);
        Token::deposit(&mut auction.seller_deposit, depsit_token);

        // Assign current user to seller
        Option::fill(&mut auction.seller, Signer::address_of(account));
    }


    public fun auction_state<ObjectiveTokenT: copy + drop + store,
                             BidTokenType: copy + drop + store>(
        creator: address): u8 acquires Auction {
        let auction = borrow_global<Auction<ObjectiveTokenT, BidTokenType>>(creator);
        let current_time = Timestamp::now_milliseconds();
        do_auction_state(auction, current_time)
    }

    public fun bid<ObjectiveTokenT: copy + drop + store,
                   BidTokenType: copy + drop + store>(account: &signer,
                                                      creator: address,
                                                      bid_price: u128) acquires Auction {

        let auction = borrow_global_mut<Auction<ObjectiveTokenT, BidTokenType>>(creator);
        let current_time = Timestamp::now_milliseconds();
        let state = do_auction_state(auction, current_time);
        assert(state == BIDDING, Errors::invalid_state(ERR_AUCTION_INVALID_STATE));

        let account_address = Signer::address_of(account);
        let last_buyer = Option::get_with_default(&auction.buyer, default_addr());
        let seller = Option::get_with_default(&auction.seller, default_addr());
        assert(bid_price >= auction.start_price, Errors::invalid_state(ERR_AUCTION_BLOW_START_PRICE));
        assert(account_address != seller, Errors::invalid_state(ERR_AUCTION_BID_CANNOT_BE_SELLER));

        // The same user cannot bid twice in a row
        assert(account_address != last_buyer, Errors::invalid_argument(ERR_AUCTION_BID_REPEATE));

        // Retreat bid deposit token to latest buyer who has bidden.
        let bid_reverse_amount = Token::value<BidTokenType>(&auction.buyer_bid_reserve);
        if (last_buyer != default_addr() && bid_reverse_amount > 0) {
            AucTokenUtil::extract_from_reverse(last_buyer, &mut auction.buyer_bid_reserve);
        };

        Debug::print(&bid_reverse_amount);

        // Assert bid reverse is clean
        assert(AucTokenUtil::zero(&auction.buyer_bid_reserve), ERR_AUCTION_BID_RESERVE_NOT_CLEAN);

        // Put bid user to current buyer, Get AUC token from user and deposit it to auction.
        let token = Account::withdraw<BidTokenType>(account, bid_price);
        Token::deposit<BidTokenType>(&mut auction.buyer_bid_reserve, token);

        // Auto accept ObjectTokenType
        AucTokenUtil::maybe_accept_token<ObjectiveTokenT>(account);

        // Replace old buyer to new buyer
        let new_buyer = Signer::address_of(account);
        if (Option::is_some(&mut auction.buyer)) {
            let _ = Option::swap(&mut auction.buyer, new_buyer);
        } else {
            Option::fill(&mut auction.buyer, new_buyer);
        };

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
    public fun completed<ObjectiveTokenT: copy + drop + store,
                         BidTokenType: copy + drop + store>(
        creator: address) acquires Auction {
        let auction = borrow_global_mut<Auction<ObjectiveTokenT, BidTokenType>>(creator);
        let current_time = Timestamp::now_milliseconds();
        let state = do_auction_state(auction, current_time);
        assert(state == NO_BID || state == CONFIRM || state == UNDER_REVERSE,
            Errors::invalid_argument(ERR_AUCTION_INVALID_STATE));

        let seller = Option::get_with_default(&auction.seller, default_addr());
        let buyer = Option::get_with_default(&auction.buyer, default_addr());

        // Bid succeed.
        if (state == CONFIRM) {
            // Put bid amount to seller
            AucTokenUtil::extract_from_reverse(seller, &mut auction.buyer_bid_reserve);
            AucTokenUtil::extract_from_reverse(seller, &mut auction.seller_deposit);

            // Put sell objective to buyer
            AucTokenUtil::extract_from_reverse(buyer, &mut auction.seller_objective);

            // Publish AuctionCompleted event
            Event::emit_event(
                &mut auction.auction_completed_events,
                AuctionCompletedEvent {
                    creator,
                },
            );

        } else if (state == NO_BID || state == UNDER_REVERSE) {
            // Retreat last buyer bid deposit token if there has bid
            if (buyer != default_addr() && AucTokenUtil::non_zero(&auction.buyer_bid_reserve)) {
                AucTokenUtil::extract_from_reverse(buyer, &mut auction.buyer_bid_reserve);
            };

            // Retreat seller's assets
            let seller = Option::get_with_default(&auction.seller, default_addr());
            AucTokenUtil::extract_from_reverse(seller, &mut auction.seller_deposit);
            AucTokenUtil::extract_from_reverse(seller, &mut auction.seller_objective);

            // Publish AuctionPassed event
            Event::emit_event(
                &mut auction.auction_passed_events,
                AuctionPassedEvent {
                    creator,
                },
            );
        };
    }

    public fun auction_info<ObjectiveTokenT: copy + drop + store,
                            BidTokenType: copy + drop + store>(
        creator: address) : (u64, u64, u128, u128, u128, u8, address, address, u128) acquires Auction {
        let auction = borrow_global_mut<Auction<ObjectiveTokenT, BidTokenType>>(creator);
        let current_time = Timestamp::now_milliseconds();
        let state = do_auction_state(auction, current_time);
        (
            auction.start_time,
            auction.end_time,
            auction.reserve_price,
            auction.increments_price,
            auction.hammer_price,
            state,
            Option::get_with_default(&auction.seller, default_addr()),
            Option::get_with_default(&auction.buyer, default_addr()),
            Token::value(&auction.buyer_bid_reserve),
        )
    }

    /// Buy objective with one price
    public fun hammer_buy(_account : &signer) {

    }

    fun platform_addr(): address {
        @0xbd7e8be8fae9f60f2f5136433e36a091
    }

    fun default_addr(): address {
        platform_addr()
    }
}
}