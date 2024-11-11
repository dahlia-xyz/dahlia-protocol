// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Vm } from "@forge-std/Test.sol";
import { PointsFactory } from "@royco/PointsFactory.sol";
import { Dahlia } from "src/core/contracts/Dahlia.sol";
import { DahliaRegistry, IDahliaRegistry } from "src/core/contracts/DahliaRegistry.sol";
import { Constants } from "src/core/helpers/Constants.sol";
import { MarketMath } from "src/core/helpers/MarketMath.sol";

import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { IrmFactory } from "src/irm/contracts/IrmFactory.sol";
import { VariableIrm } from "src/irm/contracts/VariableIrm.sol";
import { IrmConstants } from "src/irm/helpers/IrmConstants.sol";
import { IIrm } from "src/irm/interfaces/IIrm.sol";
import { OracleFactory } from "src/oracles/contracts/OracleFactory.sol";
import { IDahliaOracle } from "src/oracles/interfaces/IDahliaOracle.sol";
import { WrappedVaultFactory } from "src/royco/contracts/WrappedVaultFactory.sol";
import { BoundUtils } from "test/common/BoundUtils.sol";
import { TestConstants } from "test/common/TestConstants.sol";
import { ERC20Mock, IERC20 } from "test/common/mocks/ERC20Mock.sol";
import { OracleMock } from "test/common/mocks/OracleMock.sol";
import { Mainnet } from "test/oracles/Constants.sol";

interface IERC20Mint is IERC20 {
    function mint(address account, uint256 value) external returns (bool);
}

contract DahliaExt is Dahlia {
    constructor(address _owner, address addressRegistry) Dahlia(_owner, addressRegistry) { }

    // function forceChangeMarketLltv(IDahlia.MarketId marketId, uint24 lltv) external {
    //     markets[marketId].market.lltv = lltv;
    // }
}

contract TestContext {
    struct MarketContext {
        Dahlia.MarketConfig marketConfig;
        IDahlia.MarketId marketId;
        DahliaExt dahlia;
        IDahliaRegistry dahliaRegistry;
        address alice;
        address bob;
        address carol;
        address marketAdmin;
        address royco;
        address owner;
        address[] permitted;
        OracleMock oracle;
        VariableIrm irm;
        ERC20Mock loanToken;
        ERC20Mock collateralToken;
    }

    Vm public vm;

    mapping(string => address) public wallets;
    mapping(string => address) public contracts;
    mapping(string => uint8) public defaultTokenDecimals;

    constructor(Vm vm_) {
        defaultTokenDecimals["USDC"] = 6;
        defaultTokenDecimals["WETH"] = 18;
        defaultTokenDecimals["WBTC"] = 8;
        vm = vm_;
    }

    function bootstrapMarket(string memory loanTokenName, string memory collateralTokenName, uint256 lltv, address owner)
        public
        returns (MarketContext memory)
    {
        Dahlia.MarketConfig memory config = createMarketConfig(loanTokenName, collateralTokenName, lltv - MarketMath.toPercent(10), lltv);
        config.owner = owner;
        return bootstrapMarket(config);
    }

    function bootstrapMarket(string memory loanTokenName, string memory collateralTokenName, uint256 lltv) public returns (MarketContext memory) {
        return bootstrapMarket(createMarketConfig(loanTokenName, collateralTokenName, lltv - MarketMath.toPercent(10), lltv));
    }

    function bootstrapMarket(string memory loanTokenName, string memory collateralTokenName, uint256 rltv, uint256 lltv)
        public
        returns (MarketContext memory)
    {
        return bootstrapMarket(createMarketConfig(loanTokenName, collateralTokenName, rltv, lltv));
    }

    function bootstrapMarket(Dahlia.MarketConfig memory marketConfig) public returns (MarketContext memory v) {
        vm.pauseGasMetering();
        v.alice = createWallet("ALICE");
        v.bob = createWallet("BOB");
        v.carol = createWallet("CAROL");
        v.owner = createWallet("OWNER");
        v.marketAdmin = createWallet("MARKET_ADMIN");
        v.royco = createWallet("ROYCO");
        v.permitted = new address[](2);
        v.permitted[0] = v.owner;
        v.permitted[1] = v.marketAdmin;
        v.dahlia = createDahlia();
        v.dahliaRegistry = v.dahlia.dahliaRegistry();
        createRoycoWrappedVaultFactory(
            v.dahlia,
            createWallet("ROYCO_OWNER"),
            createWallet("ROYCO_REE_RECIPIENT"),
            TestConstants.ROYCO_ERC4626I_FACTORY_PROTOCOL_FEE,
            TestConstants.ROYCO_ERC4626I_FACTORY_MIN_FRONTEND_FEE
        );

        v.marketConfig = marketConfig;
        v.marketId = deployDahliaMarket(v.marketConfig);
        v.oracle = OracleMock(address(marketConfig.oracle));
        v.loanToken = ERC20Mock(marketConfig.loanToken);
        v.collateralToken = ERC20Mock(marketConfig.collateralToken);

        vm.resumeGasMetering();
    }

    function setContractAddress(string memory name, address addr) public {
        contracts[name] = addr;
    }

    function setWalletAddress(string memory name, address addr) public {
        wallets[name] = addr;
    }

    function createERC20Token(string memory name) public virtual returns (ERC20Mock token) {
        return createERC20Token(name, defaultTokenDecimals[name]);
    }

    function createERC20Token(string memory name, uint8 decimals) public virtual returns (ERC20Mock token) {
        if (contracts[name] != address(0)) {
            return ERC20Mock(contracts[name]);
        }
        token = new ERC20Mock(name, name, decimals);
        vm.label(address(token), string.concat("[  ", name, "  ]"));
        contracts[name] = address(token);
    }

    function createWallet(string memory name) public virtual returns (address wallet) {
        if (wallets[name] != address(0)) {
            return wallets[name];
        }
        uint256 privateKey = uint256(bytes32(bytes(name)));
        wallet = vm.addr(privateKey);
        vm.label(wallet, string.concat("[ ", name, " ]"));
        wallets[name] = wallet;
    }

    function mint(string memory tokenName, string memory walletName, uint256 amount) public virtual returns (address wallet) {
        wallet = createWallet(walletName);
        ERC20Mock token = createERC20Token(tokenName);
        vm.prank(wallet);
        token.mint(wallet, amount);
        return wallet;
    }

    function setWalletBalance(string memory tokenName, string memory walletName, uint256 amount) public virtual returns (address wallet) {
        wallet = createWallet(walletName);
        ERC20Mock token = createERC20Token(tokenName);
        ERC20Mock(token).setBalance(wallet, amount);
    }

    function createTestOracle(uint256 price) public virtual returns (IDahliaOracle) {
        OracleMock oracle = new OracleMock();
        oracle.setPrice(price);
        return oracle;
    }

    function createTestIrm() public virtual returns (IIrm irm) {
        if (contracts["IrmFactory"] == address(0)) {
            contracts["IrmFactory"] = address(new IrmFactory());
        }
        irm = IrmFactory(contracts["IrmFactory"]).createVariableIrm(
            VariableIrm.Config({
                minTargetUtilization: 75 * IrmConstants.UTILIZATION_100_PERCENT / 100,
                maxTargetUtilization: 85 * IrmConstants.UTILIZATION_100_PERCENT / 100,
                targetUtilization: 85 * IrmConstants.UTILIZATION_100_PERCENT / 100,
                minFullUtilizationRate: 1_582_470_460,
                maxFullUtilizationRate: 3_164_940_920_000,
                zeroUtilizationRate: 158_247_046,
                rateHalfLife: 172_800,
                targetRatePercent: 0.2e18
            })
        );
    }

    function createDahliaRegistry(address owner) public returns (address dahliaRegistry) {
        if (contracts["dahliaRegistry"] != address(0)) {
            return contracts["dahliaRegistry"];
        }
        dahliaRegistry = address(new DahliaRegistry(owner));
        vm.prank(owner);
        DahliaRegistry(dahliaRegistry).allowIrm(IIrm(address(0)));
        vm.label(dahliaRegistry, "[ DAHLIA_REGISTRY ]");
        contracts["dahliaRegistry"] = dahliaRegistry;
    }

    function createDahlia() public returns (DahliaExt dahlia) {
        if (contracts["dahlia"] != address(0)) {
            return DahliaExt(contracts["dahlia"]);
        }
        address owner = createWallet("OWNER");
        address dahliaRegistry = createDahliaRegistry(owner);
        vm.startPrank(owner);

        dahlia = new DahliaExt(owner, dahliaRegistry);
        vm.label(address(dahlia), "[ DAHLIA ]");
        dahlia.setProtocolFeeRecipient(createWallet("PROTOCOL_FEE_RECIPIENT"));
        dahlia.setReserveFeeRecipient(createWallet("RESERVE_FEE_RECIPIENT"));

        vm.stopPrank();
        contracts["dahlia"] = address(dahlia);
    }

    function createMarketConfig(string memory loanToken, string memory collateralToken, uint256 rltv, uint256 lltv)
        public
        returns (Dahlia.MarketConfig memory)
    {
        return createMarketConfig(address(createERC20Token(loanToken)), address(createERC20Token(collateralToken)), rltv, lltv);
    }

    function createMarketConfig(address loanToken, address collateralToken, uint256 rltv, uint256 lltv)
        public
        returns (Dahlia.MarketConfig memory marketConfig)
    {
        address admin = createWallet("MARKET_ADMIN");
        marketConfig = IDahlia.MarketConfig({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: createTestOracle(Constants.ORACLE_PRICE_SCALE),
            irm: createTestIrm(),
            lltv: lltv,
            rltv: rltv,
            liquidationBonusRate: BoundUtils.randomLiquidationBonusRate(vm, lltv),
            owner: admin
        });
    }

    function copyMarketConfig(Dahlia.MarketConfig memory config, uint256 rltv, uint256 lltv) public returns (Dahlia.MarketConfig memory marketConfig) {
        marketConfig = IDahlia.MarketConfig({
            loanToken: config.loanToken,
            collateralToken: config.collateralToken,
            oracle: config.oracle,
            irm: config.irm,
            owner: config.owner,
            lltv: lltv,
            rltv: rltv,
            liquidationBonusRate: BoundUtils.randomLiquidationBonusRate(vm, lltv)
        });
    }

    function deployDahliaMarket(Dahlia.MarketConfig memory marketConfig) public returns (IDahlia.MarketId id) {
        Dahlia dahlia = createDahlia();
        vm.startPrank(wallets["OWNER"]);
        if (!dahlia.dahliaRegistry().isIrmAllowed(marketConfig.irm)) {
            dahlia.dahliaRegistry().allowIrm(marketConfig.irm);
        }
        vm.stopPrank();

        vm.prank(createWallet("MARKET_DEPLOYER"));
        id = dahlia.deployMarket(marketConfig);
    }

    function createRoycoWrappedVaultFactory(Dahlia dahlia, address roycoOwner, address protocolFeeRecipient, uint256 protocolFee, uint256 minimumFrontendFee)
        public
        virtual
        returns (WrappedVaultFactory wrappedVaultFactory)
    {
        address dahliaOwner = createWallet("OWNER");
        address dahliaRegistry = createDahliaRegistry(dahliaOwner);
        // skip if factory already created
        address existed = DahliaRegistry(dahliaRegistry).getAddress(Constants.ADDRESS_ID_ROYCO_WRAPPED_VAULT_FACTORY);
        if (existed != address(0)) {
            return WrappedVaultFactory(existed);
        }

        address pointsFactory = address(new PointsFactory(roycoOwner));
        wrappedVaultFactory = new WrappedVaultFactory(protocolFeeRecipient, protocolFee, minimumFrontendFee, roycoOwner, pointsFactory, address(dahlia));

        vm.startPrank(dahliaOwner);
        DahliaRegistry(dahliaRegistry).setAddress(Constants.ADDRESS_ID_ROYCO_WRAPPED_VAULT_FACTORY, address(wrappedVaultFactory));
        vm.stopPrank();
    }

    function createOracleFactory() public returns (address) {
        if (contracts["oracleFactory"] != address(0)) {
            return contracts["oracleFactory"];
        }
        address owner = createWallet("OWNER");
        OracleFactory factory = new OracleFactory(owner, Mainnet.UNISWAP_STATIC_ORACLE_ADDRESS);
        contracts["oracleFactory"] = address(factory);
        return address(factory);
    }
}
