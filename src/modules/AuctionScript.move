address 0xbd7e8be8fae9f60f2f5136433e36a091 {
module AuctionScript {
    use 0xbd7e8be8fae9f60f2f5136433e36a091::Auction;
    use 0x1::Account;

    public ( script ) fun create<ObjectiveTokenT: copy + drop + store,
                                 BidTokenType: copy + drop + store>(account: signer,
                                                                    start_time: u64,
                                                                    end_time: u64,
                                                                    start_price: u128,
                                                                    reserve_price: u128,
                                                                    increments_price: u128,
                                                                    hammer_price: u128) {
        Auction::create<ObjectiveTokenT, BidTokenType>(
            &account, start_time, end_time,
            start_price, reserve_price,
            increments_price, hammer_price);
    }

    public ( script ) fun deposit<ObjectiveTokenT: copy + drop + store,
                                  BidTokenType: copy + drop + store>(account: signer,
                                                                     creator: address,
                                                                     objective_price: u128,
                                                                     deposit_price: u128) {
        let objective_token = Account::withdraw<ObjectiveTokenT>(&account, objective_price);
        Auction::deposit<ObjectiveTokenT, BidTokenType>(
            &account, creator, objective_token, deposit_price);
    }

    public ( script ) fun bid<ObjectiveTokenT: copy + drop + store,
                              BidTokenType: copy + drop + store>(account: signer,
                                                                 creator: address,
                                                                 bid_price: u128) {
        Auction::bid<ObjectiveTokenT, BidTokenType>(&account, creator, bid_price);
    }

    public ( script ) fun completed<ObjectiveTokenT: copy + drop + store,
                                    BidTokenType: copy + drop + store>(creator: address) {
        Auction::completed<ObjectiveTokenT, BidTokenType>(creator);
    }

    public ( script ) fun auction_info<ObjectiveTokenT: copy + drop + store,
                                       BidTokenType: copy + drop + store>(creator: address):
    (u64, u64, u128, u128, u128, u8, address, address, u128) {
        Auction::auction_info<ObjectiveTokenT, BidTokenType>(creator)
    }
}
}