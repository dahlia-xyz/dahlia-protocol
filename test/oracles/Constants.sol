// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

library Mainnet {
    address internal constant UNISWAP_STATIC_ORACLE_ADDRESS = 0xB210CE856631EeEB767eFa666EC7C1C57738d438;
    address internal constant PYTH_STATIC_ORACLE_ADDRESS = 0x4305FB66699C3B2702D4d05CF36551390A4c69C6;
    address internal constant COMPTROLLER_ADDRESS = 0x168200cF227D4543302686124ac28aE0eaf2cA0B;
    address internal constant CIRCUIT_BREAKER_ADDRESS = 0xfd3065C629ee890Fd74F43b802c2fea4B7279B8c;
    address internal constant TIMELOCK_ADDRESS = 0x8412ebf45bAC1B340BbE8F318b928C466c4E39CA;
    address internal constant FRAX_HOT_WALLET = 0xdB3388e770F49A604E11f1a2084B39279492a61f;
    address internal constant FRAXSWAP_ROUTER_ADDRESS = 0xC14d550632db8592D1243Edc8B95b0Ad06703867;
    address internal constant UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address internal constant FRAX_ERC20 = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    address internal constant FXS_ERC20 = 0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0;
    address internal constant FRXETH_ERC20 = 0x5E8422345238F34275888049021821E8E08CAa1f;
    address internal constant SFRXETH_ERC20 = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    address internal constant FRXETH_ETH_CURVE_POOL_NOT_LP = 0xa1F8A6807c402E4A15ef4EBa36528A3FED24E577;
    address internal constant FRAX_USDC_CURVE_POOL_NOT_LP = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2;
    address internal constant LDO_ETH_CURVE_V2_POOL = 0x9409280DC1e6D33AB7A8C6EC03e5763FB61772B5;
    address internal constant FRAX_USDC_PLAIN_POOL = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2;
    address internal constant CPI_TRACKER_ORACLE = 0x66B7DFF2Ac66dc4d6FBB3Db1CB627BBb01fF3146;
    address internal constant FPI_ORACLE = 0xd2516e709a2e9D64F66B4c4009efE4F74F5FA40D;
    address internal constant FPI_ORACLE_V2 = 0x2469757756ebA7Bea6B7F054896e3Db74103A962;
    address internal constant GOHM_ORACLE = 0xe893297a9d4310976424fD0B25f53aC2B6464fe3;
    address internal constant SFRXETH_ORACLE = 0x27942aFe4EcB7F9945168094e0749CAC749aC97B;
    address internal constant SFRXETH_ORACLE_V2 = 0x807502C8EAdAc82C3227249f8aCf54d9d98F76d1;
    address internal constant FPI_CONTROLLER_POOL_ADDRESS = 0x2397321b301B80A1C0911d6f9ED4b6033d43cF51;
    address internal constant CONVEX_WRAPPER_FRAX_USDC_LP = 0x54a3A6aFd87F10Eea4Acc2A067A2C0b612B6D315;
    address internal constant CONVEX_WRAPPER_FRXETH_ETH_LP = 0xd1b222AAEdf2877CeEB3c66BDaA6858200eb48fC;
    address internal constant AAVE_TOKEN_DUAL_ORACLE_ADDRESS = 0x3284E1BCEaf70767A7575d0e1e10fAFbC4618B52;
    address internal constant APECOIN_DUAL_ORACLE_ADDRESS = 0x2CDF5812F4ebcF3BD533E8918D47Bd3e65514520;
    address internal constant CHAIN_LINK_TOKEN_DUAL_ORACLE = 0x605F7ADD3A14ACA676B1F60F3b36C772720946Aa;
    address internal constant FRAX_USDC_CURVE_LP_DUAL_ORACLE_ADDRESS = 0x2Ad35cce2a690E0bF1e6dCAC2F9175389F31D7F4;
    address internal constant FRXETH_ETH_CURVE_POOL_LP_DUAL_ORACLE_ADDRESS = 0x013723E5631c591Af50E89C2892b464530103481;
    address internal constant MAKER_DUAL_ORACLE_ADDRESS = 0x4c7b43EcE8958D7f6b184B3833DD1D383db1f83b;
    address internal constant SFRXETH_DUAL_ORACLE_ADDRESS = 0xd2F0fa7f2E6a60EEcf4b78c5b6D81002b9789F2c;
    address internal constant UNISWAP_DUAL_ORACLE_ADDRESS = 0x33A9D662d9F7cb2153e3a5102615B08865BeAbdB;
    address internal constant FRXETH_ETH_DUAL_ORACLE_ADDRESS = 0xb12c19C838499E3447AFd9e59274B1BE56b1546A;
    address internal constant SFRXETH_ETH_DUAL_ORACLE_ADDRESS = 0x1473F3e4d236CBBe3412b9f65B4c210756BE2C0E;
    address internal constant FRXETH_FRAX_ORACLE_ADDRESS = 0xC58F3385FBc1C8AD2c0C9a061D7c13b141D7A5Df;
    address internal constant SFRXETH_FRAX_ORACLE_ADDRESS = 0xB9af7723CfBd4469A7E8aa60B93428D648Bda99d;
    address internal constant AAVE_ETH_UNI_V3_POOL = 0x5aB53EE1d50eeF2C1DD3d5402789cd27bB52c1bB;
    address internal constant APE_WETH_UNI_V3_POOL = 0xAc4b3DacB91461209Ae9d41EC517c2B9Cb1B7DAF;
    address internal constant FRAX_USDC_V3_POOL = 0xc63B0708E2F7e69CB8A1df0e1389A98C35A76D52;
    address internal constant FRXETH_FRAX_V3_POOL = 0x36C060Cc4b088c830a561E959A679A58205D3F56;
    address internal constant LINK_ETH_UNI_V3_POOL = 0xa6Cc3C2531FdaA6Ae1A3CA84c2855806728693e8;
    address internal constant MKR_ETH_UNI_V3_POOL = 0xe8c6c9227491C0a8156A0106A0204d881BB7E531;
    address internal constant STATIC_UNI_V3_ORACLE = 0xB210CE856631EeEB767eFa666EC7C1C57738d438;
    address internal constant UNI_ETH_UNI_V3_POOL = 0x1d42064Fc4Beb5F8aAF85F4617AE8b3b5B8Bd801;
    address internal constant FRAX_WETH_UNI_V3_POOL = 0x92c7b5Ce4CB0e5483F3365C1449f21578eE9f21A;
    address internal constant USDC_WETH_UNI_V3_POOL = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
    address internal constant WBTC_USDC_UNI_V3_POOL = 0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16;
    address internal constant WETH_USDC_UNI_V3_POOL = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
    address internal constant AAVE_ERC20 = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
    address internal constant APE_ERC20 = 0x4d224452801ACEd8B2F0aebE155379bb5D594381;
    address internal constant CRV_ERC20 = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    address internal constant CVX_ERC20 = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;
    address internal constant FIL_ERC20 = 0xB8B01cec5CEd05C457654Fc0fda0948f859883CA;
    address internal constant FPIS_ERC20 = 0xc2544A32872A91F4A553b404C6950e89De901fdb;
    address internal constant FPI_ERC20 = 0x5Ca135cB8527d76e932f34B5145575F9d8cbE08E;
    address internal constant FRAX_USDC_CURVE_POOL_LP_ERC20 = 0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC;
    address internal constant FRXETH_ETH_CURVE_POOL_LP_ERC20 = 0xf43211935C781D5ca1a41d2041F397B8A7366C7A;
    address internal constant GOHM_ERC20 = 0x0ab87046fBb341D058F17CBC4c1133F25a20a52f;
    address internal constant LDO_ERC20 = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32;
    address internal constant LINK_ERC20 = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address internal constant MKR_ERC20 = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2;
    address internal constant UNI_ERC20 = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    address internal constant USDC_ERC20 = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant WBTC_ERC20 = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal constant WETH_ERC20 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant AAVE_USD_CHAINLINK_ORACLE = 0x547a514d5e3769680Ce22B2361c10Ea13619e8a9;
    address internal constant APE_USD_CHAINLINK_ORACLE = 0xD10aBbC76679a20055E167BB80A24ac851b37056;
    address internal constant WBTC_BTC_CHAINLINK_ORACLE = 0xfdFD9C85aD200c506Cf9e21F1FD8dd01932FBB23;
    address internal constant BTC_USD_CHAINLINK_ORACLE = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
    address internal constant CRV_USD_CHAINLINK_ORACLE = 0xCd627aA160A6fA45Eb793D19Ef54f5062F20f33f;
    address internal constant CVX_USD_CHAINLINK_ORACLE = 0xd962fC30A72A84cE50161031391756Bf2876Af5D;
    address internal constant ETH_USD_CHAINLINK_ORACLE = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address internal constant FIL_ETH_CHAINLINK_ORACLE = 0x0606Be69451B1C9861Ac6b3626b99093b713E801;
    address internal constant FIL_USD_CHAINLINK_ORACLE = 0x1A31D42149e82Eb99777f903C08A2E41A00085d3;
    address internal constant FRAX_USD_CHAINLINK_ORACLE = 0xB9E1E3A9feFf48998E45Fa90847ed4D467E8BcfD;
    address internal constant FXS_USD_CHAINLINK_ORACLE = 0x6Ebc52C8C1089be9eB3945C4350B68B8E4C2233f;
    address internal constant LDO_ETH_CHAINLINK_ORACLE = 0x4e844125952D32AcdF339BE976c98E22F6F318dB;
    address internal constant LINK_USD_CHAINLINK_ORACLE = 0x2c1d072e956AFFC0D435Cb7AC38EF18d24d9127c;
    address internal constant MKR_ETH_CHAINLINK_ORACLE = 0x24551a8Fb2A7211A25a17B1481f043A8a8adC7f2;
    address internal constant MKR_USD_CHAINLINK_ORACLE = 0xec1D1B3b0443256cc3860e24a46F108e699484Aa;
    address internal constant OHMV2_ETH_CHAINLINK_ORACLE = 0x9a72298ae3886221820B1c878d12D872087D3a23;
    address internal constant UNI_USD_CHAINLINK_ORACLE = 0x553303d460EE0afB37EdFf9bE42922D8FF63220e;
    address internal constant USDC_USD_CHAINLINK_ORACLE = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address internal constant UNI_WETH_CHAINLINK_ORACLE = 0xD6aA3D25116d8dA79Ea0246c4826EB951872e02e;
}
