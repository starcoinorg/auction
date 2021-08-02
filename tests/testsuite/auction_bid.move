//! account: alice, 100000000000000 0x1::STC::STC
//! account: bob, 0x81144d60492982a45ba93fba47cae988, 100000000000000 0x1::STC::STC
//! account: cindy, 100000000000000 0x1::STC::STC

//! sender: alice
address alice = {{alice}};
module alice::TokenMock {
    // mock AUC token
    struct AUC has copy, drop, store { }
}


//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    // Using `alice` to create an auction
    use alice::TokenMock::{AUC};
    use 0x1::Account;
    use 0x1::Token;
    use 0x1::Math;

    fun init(account: signer) {
        let precision: u8 = 9; //STC precision is also 9.
        let scaling_factor = Math::pow(10, (precision as u64));
        let amount: u128 = 50000 * scaling_factor;

        // Resister and mint AUC
        Token::register_token<AUC>(&account, precision);
        Account::do_accept_token<AUC>(&account);
        let token = Token::mint<AUC>(&account, amount);
        Account::deposit_to_self(&account, token);
    }
}

//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    // Using `alice` to create an auction
    use alice::TokenMock::{AUC};
    use 0x1::STC::{STC};
    use 0x1::Account;
    use 0x1::Math;
    use 0x1::Signer;
    use 0x1::Timestamp;
    use 0xBdfBbC6A3e7a0c994b720158B171305b::Auction;

    fun init(account: signer) {
        let precision: u8 = 9; //STC precision is also 9.
        let scaling_factor = Math::pow(10, (precision as u64));

        let start_time = Timestamp::now_milliseconds();
        let end_time = start_time + 3600000;
        let start_price = 100 * scaling_factor;
        let reserve_price = 500 * scaling_factor;
        let increments_price = 10 * scaling_factor;
        let hammer_price = 1000 * scaling_factor;

        Auction::create<AUC, STC>(
            &account, start_time, end_time, start_price, reserve_price, increments_price, hammer_price);
        let after_create_state = Auction::auction_state<AUC, STC>(Signer::address_of(&account));
        assert(after_create_state == 0, 30001);

        let objective = Account::withdraw<AUC>(&account, 10 * scaling_factor);
        Auction::deposit<AUC, STC>(
            &account, Signer::address_of(&account), objective, start_price);
        let after_deposit_state = Auction::auction_state<AUC, STC>(Signer::address_of(&account));
        assert(after_deposit_state == 2, 30002);
    }
}

//! new-transaction
//! sender: bob
address alice = {{alice}};
address bob = {{bob}};
script {
    // Using `bob` to bid the auction which created by `alice`
    use 0x1::STC::{STC};
    use alice::TokenMock::{AUC};
    use 0x1::Math;
    use 0x1::Signer;
    //use 0x1::Debug;
    use 0xBdfBbC6A3e7a0c994b720158B171305b::Auction;

    fun init(account: signer) {
        let precision: u8 = 9; // STC precision is also 9.
        let scaling_factor = Math::pow(10, (precision as u64));

        let state = Auction::auction_state<AUC, STC>(@alice);
        assert(state == 2, 30003);

        // First bid from `bob`
        let first_bid_price = 110 * scaling_factor;
        Auction::bid<AUC, STC>(&account, @alice, 110 * scaling_factor);

        // Check current bid is `bob`, and now bid price is 110 STC
        let (_, _, _, _, _, _, seller, buyer, bid_reserve_amount) = Auction::auction_info<AUC, STC>(@alice);
        assert(buyer == Signer::address_of(&account), 30004);
        assert(seller == @alice, 30004);
        assert(bid_reserve_amount == first_bid_price, 30005);
    }
}

//! new-transaction
//! sender: cindy
address alice = {{alice}};
address cindy = {{cindy}};
script {
    // Using `cindy` to bid the auction which created by `alice`
    use 0x1::STC::{STC};
    use alice::TokenMock::{AUC};
    use 0x1::Math;
    use 0x1::Signer;
    //use 0x1::Debug;
    use 0xBdfBbC6A3e7a0c994b720158B171305b::Auction;

    fun init(account: signer) {
        let precision: u8 = 9; // STC precision is also 9.
        let scaling_factor = Math::pow(10, (precision as u64));

        let state = Auction::auction_state<AUC, STC>(@alice);
        assert(state == 2, 30006);

        // Second bid from `cindy`
        let second_bid_price = 520 * scaling_factor;
        Auction::bid<AUC, STC>(&account, @alice, second_bid_price);

        // Check current bid is `bob`, and now bid price is 120 STC
        let (_start_time, _end_time, _, _, _, _, _seller, _buyer, _bid_reserve_amount) = Auction::auction_info<AUC, STC>(@alice);
        assert(_buyer == Signer::address_of(&account), 30007);
        assert(_bid_reserve_amount == second_bid_price, 30008);
    }
}

//! block-prologue
//! author: alice
//! block-number: 1
//! block-time: 7200000

//! new-transaction
//! sender: cindy
address alice = {{alice}};
address cindy = {{cindy}};
script {
    // Using `cindy` to bid the auction which created by `alice`
    use 0x1::STC::{STC};
    use alice::TokenMock::{AUC};
    use 0x1::Signer;
    use 0x1::Account;
    use 0xBdfBbC6A3e7a0c994b720158B171305b::Auction;

    fun init(_account: signer) {
        let (_start_time, _end_time, _, _, _, _state, _seller, _buyer, _bid_reserve_amount) =
            Auction::auction_info<AUC, STC>(@alice);
        assert(_state == 5, 30009);

        let balance1 = Account::balance<AUC>(Signer::address_of(&_account));
        assert(balance1 <= 0, 30010);

        Auction::completed<AUC, STC>(@alice);

        // Get auction objective from buyer
        let balance2 = Account::balance<AUC>(Signer::address_of(&_account));
        assert(balance2 > 0, 30011);
    }
}


////! new-transaction
////! sender: alice
//address alice = {{alice}};
//script {
//    // Clean the auction created by `alice`
//    use 0x1::STC::{STC};
//    use alice::TokenMock::{AUC};
//    use 0xBdfBbC6A3e7a0c994b720158B171305b::Auction;
//
//    fun init(_account: signer) {
//        Auction::<AUC, STC>(Signer::address_of(_account));
//    }
//}