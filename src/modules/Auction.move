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
    const INIT: u8 = 0; // 初始化
    const PENDING: u8 = 1; // 待拍卖
    const BIDDING: u8 = 2; // 竞拍中
    const UNDER_BASIC: u8 = 4; // 未达到起拍价
    const NO_BID: u8 = 5; // 无人竞价
    const CONFIRM: u8 = 6; // 成交

    ///
    /// Auction error code
    ///
    const ERR_AUCTION_ID_MISMATCH: u8 = 10001;
    const ERR_AUCTION_EXISTS_ALREADY: u8 = 10002;
    const ERR_AUCTION_INVALID_STATE: u8 = 10003;

    ///
    /// 拍卖信息
    ///
    struct Auction<TokenT> has copy, drop, key {
    start_time: u64, // 起拍时间
        end_time: u64, // 结束时间

        reserve_price: u128, // 保留价
        increments_price: u128, // 加价阶梯
        hammer_price: u128, // 一口价
        hammer_locked: bool, // 一口价锁定

        seller: address, // 拍卖方
        seller_deposit: Token::Token<Auc::Auc>, // 拍卖保证金
        seller_objective: Token::Token<TokenT>, // 拍卖标的物

        buyer: address, // 当前买受人
        buyer_bid_amount: Token<Auc::Auc>, // 当前买受人出价
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

        if (Option::is_none(auction.buyer_bid_amount)) {
            NO_BID
        };

        let bid_amount = Token::value<Auc::Auc>(auction.buyer_bid_amount);
        if (bid_amount < auction.reserve_price) {
            UNDER_BASIC
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
    /// 创建拍卖
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
        };
        move_to(account, auction);

        // TODO: Publish AuctionCreated event

    }

    ///
    /// 拍卖抵押（拍卖方调用）
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

        auction.objective = objective;
        auction.seller_deposit = seller_deposit;
    }

    ///
    /// 查询状态
    ///
    public fun auction_state<TokenT: store>(auctioner: address) acquires Auction {
        let auction = borrow_global<Auction<TokenT>>(auctioner);
        let current_time = Timestamp::now_milliseconds();
        do_auction_state<TokenT>(auction, current_time)
    }

    ///
    /// 参与竞价
    ///
    public fun bid<TokenT: store>(
        account: &signer, auctioner: address, bid_price: u128) {
        let auction = borrow_global<Auction<TokenT>>(auctioner);
        let current_time = Timestamp::now_milliseconds();
        let state = do_auction_state<TokenT>(auction, current_time);
        assert(state == BIDDING, Errors::invalid_state(ERR_AUCTION_INVALID_STATE));

        // Get user token AUC token
        let token = Token::withdraw<Auc::Auc>(account, bid_price);
        token
    }


    ///
    /// 完成拍卖，清理资源
    /// 拍卖方：若成功，取回拍卖金和保证金，若失败，取拍得回标的物
    /// 买受方：若成功，取回标的物，若失败（参与方），取回拍卖保证金
    ///
    public fun completed<TokenT: store>(account: &signer, auctioner: address) {
        let auction = borrow_global_mut<Auction<TokenT>>(auctioner);
        let current_time = Timestamp::now_milliseconds();
        let state = do_auction_state<TokenT>(auction, current_time);
        assert(state == NO_BID || state == CONFIRM || state == UNDER_BASIC,
            Errors::invalid_argument(ERR_AUCTION_INVALID_STATE));

        if (state == NO_BID || state == UNDER_BASIC) {} else if (state == CONFIRM) {};

        // TODO: publish AuctionCompleted event

    }

    fun platform_addr() {
        @0xbd7e8be8fae9f60f2f5136433e36a091
    }
}
}