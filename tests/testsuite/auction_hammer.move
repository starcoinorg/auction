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

        Auction::create<AUC, STC>(&account, start_time, end_time, start_price, reserve_price, increments_price, hammer_price);
        let after_create_state = Auction::auction_state<AUC, STC>(Signer::address_of(&account));
        assert(after_create_state == 0, 40001);

        let objective = Account::withdraw<AUC>(&account, 10 * scaling_factor);
        Auction::deposit<AUC, STC>(
            &account, Signer::address_of(&account), objective, start_price);
        let after_deposit_state = Auction::auction_state<AUC, STC>(Signer::address_of(&account));
        assert(after_deposit_state == 2, 40002);
    }
}

//! new-transaction
//! sender: bob
address bob = {{bob}};
address alice = {{alice}};
script {
    // Using `bob` hammer buy
    use alice::TokenMock::{AUC};
    use 0x1::STC::{STC};
    use 0xBdfBbC6A3e7a0c994b720158B171305b::Auction;

    fun init(account: signer) {
        Auction::hammer_buy<AUC, STC>(&account, @alice);
        let after_deposit_state = Auction::auction_state<AUC, STC>(@alice);
        assert(after_deposit_state == 5, 40003);
    }
}