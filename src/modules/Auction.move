/// File: Auction implements
/// Author: BobOng
/// Date: 2021-07-26

address 0xbd7e8be8fae9f60f2f5136433e36a091 {
/// The <Auction> module defined some struct of auction
module Auction {
    use 0x1::Signer;
    use 0x1::Token;
    use 0x1::Errors;
    use 0x1::Option;
    use 0x1::Timestamp;
    use 0xbd7e8be8fae9f60f2f5136433e36a091::Auc;

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
    const ERR_AUCTION_ID_MISMATCH: u8 = 10001;
    const ERR_AUCTION_EXISTS_ALREADY: u8 = 10002;
    const ERR_AUCTION_INVALID_STATE: u8 = 10003;
    const ERR_AUCTION_INVALID_SELLER: u8 = 10004;
    const ERR_AUCTION_BID_REPEATE: u8 = 10005;


    ///
    /// Auction data struct.
    struct Auction<TokenT> has copy, drop, key {
        /// Start auction time
        start_time: u64,
        /// End auction time
        end_time: u64,
        /// Reverse price
        reserve_price: u128,
        /// Increase price, each bid price number must several time of this number
        increments_price: u128,
        /// Hammer price, user can buy objective at this price
        hammer_price: u128,
        /// After user called hammer_price, this value is true
        hammer_locked: bool,

        /// seller informations
        seller: address,
        seller_deposit: Token::Token<Auc::Auc>,
        seller_objective: Token::Token<TokenT>,

        /// buyer informations
        buyer: address,
        buyer_bid_reserve: Token<Auc::Auc>,
    }


    //////////////////////////////////////////////////////////////////////////////
    // Internal fucntions

    fun do_auction_state<TokenT>(
        auction: &Auction<TokenT>,
        current_time: u64,
    ): u8 {
        if (Option::is_none(auction.objective) ||
                Option::is_none(auction.seller_deposit)) {
            INIT
        };

        if (auction.hammer_locked) {
            CONFIRM
        };

        if (current_time < auction.start_time) {
            PENDING
        };

        if (current_time <= auction.end_time) {
            BIDDING
        };

        if (Option::is_none(auction.buyer_bid_reserve)) {
            NO_BID
        };

        let bid_amount = Token::value<Auc::Auc>(auction.buyer_bid_reserve);
        if (bid_amount < auction.reserve_price) {
            UNDER_REVERSE
        };

        CONFIRM
    }

    /// check whether a proposal exists in `proposer_address`
    public fun auction_exists<TokenT: copy + drop + store>(
        auction_address: address
    ): bool acquires Auction {
        exists<Auction<TokenT>>(auction_address)
    }

    //////////////////////////////////////////////////////////////////////////////
    /// public functions

    ///
    /// Create auction for current signer
    ///
    public fun create<TokenT: store>(account: &signer,
                                     start_time: u64,
                                     end_time: u64,
                                     reserve_price: u128,
                                     increments_price: u128,
                                     hammer_price: u128) {
        assert(auction_exists(account),
            Errors::invalid_argument(ERR_AUCTION_EXISTS_ALREADY));
        let auction = Auction<TokenT> {
            seller: Signer::address_of(account),
            start_time,
            end_time,
            reserve_price,
            increments_price,
            hammer_price,
            seller_objective: Token::zero<TokenT>(),
            seller_deposit: Token::zero<TokenT>(),
            buyer_bid_reserve: Token::zero<Auc::Auc>()
        };
        move_to(account, auction);

        // TODO: Publish AuctionCreated event

    }

    ///
    /// Auction mortgage (call by auctioneer)
    ///
    public fun deposit<TokenT: store>(
        account: &signer,
        objective: Token::Token<TokenT>,
        seller_deposit: Token::Token<Auc::Auc>) acquires Auction {
        let auction = borrow_global_mut<Auction<TokenT>>(auctioner);
        let current_time = Timestamp::now_milliseconds();
        let state = do_auction_state<TokenT>(auction, current_time);
        assert(state == INIT,
            Errors::invalid_argument(ERR_AUCTION_INVALID_STATE));

        Token::deposit(&mut auction.seller_objective, objective);
        auction.seller_deposit = seller_deposit;
    }

    public fun auction_state<TokenT: store>(auctioner: address)  acquires Auction {
        let auction = borrow_global<Auction<TokenT>>(auctioner);
        let current_time = Timestamp::now_milliseconds();
        do_auction_state<TokenT>(auction, current_time)
    }

    public fun bid<TokenT: store>(account: &signer,
                                  auctioneer: address,
                                  bid_price: u128)  acquires Auction {
        let auction = borrow_global<Auction<TokenT>>(auctioneer);
        let current_time = Timestamp::now_milliseconds();
        let state = do_auction_state<TokenT>(auction, current_time);
        assert(state == BIDDING, Errors::invalid_state(ERR_AUCTION_INVALID_STATE));
        assert(auction.seller == auctioneer, Errors::invalid_argument(ERR_AUCTION_INVALID_SELLER));
        assert(auction.buyer != Signer::address_of(account), Errors::invalid_argument(ERR_AUCTION_BID_REPEATE));

        // Retreat bid deposit token to latest buyer who has bidden.
        if (!Option::is_none(auction.buyer) && !Option::is_none(auction.buyer_bid_reserve)) {
            let bid_reverse = Token::withdraw<Auc::Auc>(
                auction.buyer_bid_reserve, Token::value(auction.buyer_bid_reserve));
            Account::deposit(Signer::address_of(auction.buyer), bid_reverse);
        };

        // Put bid user to current buyer, Get AUC token from user and deposit it to auction.
        let token = Account::withdraw<Auc::Auc>(account, bid_price);
        Token::deposit<Auc::Auc>(&mut auction.buyer_bid_reserve, token);
        auction.buyer = Signer::address_of(account);
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
    public fun completed<TokenT: store>(account: &signer, auctioner: address) {
        let auction = borrow_global_mut<Auction<TokenT>>(auctioner);
        let current_time = Timestamp::now_milliseconds();
        let state = do_auction_state<TokenT>(auction, current_time);
        assert(state == NO_BID || state == CONFIRM || state == UNDER_REVERSE,
            Errors::invalid_argument(ERR_AUCTION_INVALID_STATE));

        // Bid succeed.
        if (state == CONFIRM) {
            /// Put bid amount to seller
            let bid_reserve = Token::withdraw(&mut auction.buyer_bid_reserve,
                Token::value<Auc::Auc>(auction.buyer_bid_reserve));
            Account::deposit<Auc::Auc>(auction.seller, bid_reserve);

            /// Put sell objective to buyer
            let sell_objective = Token::withdraw(&mut auction.seller_objective,
                Token::value<TokenT>(auction.seller_objective));
            Account::deposit<TokenT>(auction.buyer, sell_objective);
        } else if (state == NO_BID || state == UNDER_REVERSE) {
            // Retreat last buyer bid deposit token if there has bid
            if (!Option::is_none(auction.buyer) && !Option::is_none(auction.buyer_bid_reserve)) {
                let buyer_bid_reverse = Token::withdraw(&mut auction.buyer_bid_reserve,
                    Token::value<Auc::Auc>(auction.buyer_bid_reserve));
                Account::deposit(Signer::address_of(auction.buyer), buyer_bid_reverse);
            };

            // Retreat seller's assets
            let sell_objective = Token::withdraw(&mut auction.seller_objective,
                Token::value<TokenT>(auction.seller_objective));
            Account::deposit<TokenT>(auction.seller, sell_objective);

            let seller_deposit = Token::withdraw(&mut auction.seller_deposit,
                Token::value<TokenT>(auction.seller_deposit));
            Account::deposit<TokenT>(auction.seller, seller_deposit);
        };

        // TODO: publish AuctionCompleted event

    }

    fun platform_addr() {
        @0xbd7e8be8fae9f60f2f5136433e36a091
    }
}
}