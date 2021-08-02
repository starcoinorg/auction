address 0xBdfBbC6A3e7a0c994b720158B171305b {

/// AUC is a test token of Starcoin blockchain
/// It uses apis defined in the `Token` module.
module Auc {

    // use 0x1::Token;
    use 0x1::Account;

    // Dao config
    use 0x1::Token;
//    use 0x1::Dao;
//    use 0x1::ModifyDaoConfigProposal;
//    use 0x1::UpgradeModuleDaoProposal;
//    use 0x1::PackageTxnManager;
//    use 0x1::OnChainConfigDao;

//    use 0xBdfBbC6A3e7a0c994b720158B171305b::TokenSwapConfig;
    //    use 0x1::VMConfig;
//    use 0x1::ConsensusConfig;
//    use 0x1::RewardConfig;
//    use 0x1::TransactionTimeoutConfig;
//    use 0x1::TransactionPublishOption;
//    use 0x1::Option;
//    use 0x1::Config;
//    use 0x1::Version;
//    use 0x1::Signer;

    /// Auc token marker.
    struct Auc has copy, drop, store {}

    /// precision of USDx token.
    const PRECISION: u8 = 9;

    /// USDx initialization.
    public ( script ) fun init(account: signer) {
        Token::register_token<Auc>(&account, PRECISION);
        Account::do_accept_token<Auc>(&account);

//        // Configable
//        if (!Config::config_exist_by_address<Version::Version>(Signer::address_of(&account))) {
//            Config::publish_new_config<Version::Version>(&account, Version::new_version(1));
//        };
//
//        // Update upgrade strategy two phase
//        PackageTxnManager::update_module_upgrade_strategy(
//            &account,
//            PackageTxnManager::get_strategy_two_phase(),
//            Option::some(3600000u64),
//        );
//
//        Dao::plugin<Bdt>(
//            &account,
//            3600000,
//            3600000,
//            50,
//            3600000,
//        );
//        let upgrade_plan_cap = PackageTxnManager::extract_submit_upgrade_plan_cap(&account);
//        UpgradeModuleDaoProposal::plugin<Bdt>(
//            &account,
//            upgrade_plan_cap,
//        );
//
//        ModifyDaoConfigProposal::plugin<Bdt>(&account);
//
//        // Initialize configration value to 0
//        TokenSwapConfig::initialize(&account, 0u128);
//
//        // the following configurations are gov-ed by Dao.
//        OnChainConfigDao::plugin<Bdt, TokenSwapConfig::TokenSwapConfig>(&account);
    }

    public ( script ) fun mint(account: signer, amount: u128) {
        let token = Token::mint<Auc>(&account, amount);
        Account::deposit_to_self<Auc>(&account, token);
    }

    /// Returns true if `TokenType` is `USDx::USDx`
    public fun is_auc<TokenType: store>(): bool {
        Token::is_same_token<Auc, TokenType>()
    }

    spec is_auc {}

    /// Return USDx token address.
    public fun token_address(): address {
        Token::token_address<Auc>()
    }

    spec token_address {}
}
}