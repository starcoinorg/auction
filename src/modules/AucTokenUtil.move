address 0xbd7e8be8fae9f60f2f5136433e36a091 {
module AucTokenUtil {
    use 0x1::Token;
    use 0x1::Account;

    /// Extract token from token reverse
    public fun extract_from_reverse<TokenType: copy + drop + store>(account: address,
                                                                    reverse: &mut Token::Token<TokenType>) {
        let token_amount = Token::value<TokenType>(reverse);
        let token_reverse = Token::withdraw(reverse, token_amount);
        Account::deposit(account, token_reverse);
    }

    /// Deposit token to reverse token pool
    public fun deposit_to_reverse<TokenType: copy + drop + store>(account: &signer,
                                                                  reverse: &mut Token::Token<TokenType>,
                                                                  amount: u128) {
        let withdraw_token = Account::withdraw<TokenType>(account, amount);
        Token::deposit<TokenType>(reverse, withdraw_token);
    }

    /// Check token is none zero
    public fun none_zero<TokenType: copy + drop + store>(token : &Token::Token<TokenType>) : bool {
        Token::value(token) > 0
    }
}
}