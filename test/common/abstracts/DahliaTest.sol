// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { OracleMock } from "../mocks/OracleMock.sol";
import { Test, console } from "@forge-std/Test.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { LibString } from "@solady/utils/LibString.sol";
import { Dahlia, IDahlia } from "src/core/contracts/Dahlia.sol";
import { IDahlia } from "src/core/interfaces/IDahlia.sol";
import { IDahliaOracle } from "src/oracles/interfaces/IDahliaOracle.sol";
import { WrappedVault } from "src/royco/contracts/WrappedVault.sol";

abstract contract DahliaTest is Test {
    using LibString for *;

    address public dualOracleAddress;

    function()[] internal setupFunctions;
    address public LENDER;
    address public BORROWER;
    address public immutable OWNER;
    address public immutable LIQUIDATOR;
    Dahlia public DAHLIA;

    constructor() {
        LENDER = createWallet("LENDER");
        BORROWER = createWallet("BORROWER");
        OWNER = createWallet("OWNER");
        LIQUIDATOR = createWallet("LIQUIDATOR");
    }

    modifier useMultipleSetupFunctions() {
        for (uint256 i = 0; i < setupFunctions.length; i++) {
            setupFunctions[i]();
            _;
            vm.clearMockedCalls();
        }
    }

    function assertEq(IDahlia.MarketStatus a, IDahlia.MarketStatus b, string memory err) internal pure virtual {
        vm.assertEq(uint256(a), uint256(b), err);
    }

    function createWallet(string memory name) private returns (address wallet) {
        uint256 privateKey = uint256(bytes32(bytes(name)));
        wallet = vm.addr(privateKey);
        vm.label(wallet, string.concat("[ ", name, " ]"));
    }

    function _ffiEnabled() internal view returns (bool) {
        // Option 1: If you want to use an env var (set it when you run forge test -ffi)
        return vm.envOr("FFI", false);
    }

    /// used https://stackoverflow.com/questions/71131781/is-there-an-efficient-way-to-join-an-array-of-strings-into-a-single-string-in-so
    function arrayToString(string[] memory words) internal pure returns (string memory) {
        bytes memory output;

        for (uint256 i = 0; i < words.length; i++) {
            output = abi.encodePacked(output, string.concat(words[i], " "));
        }

        return string(output);
    }

    function printToken(string memory prefix, IERC20Metadata token, uint256 balanceOf) internal view {
        uint256 decimals = token.decimals();
        string memory supply = toFloatString(balanceOf, decimals, token.symbol());
        console.log(string.concat(prefix, " ", supply, " ", address(token).toHexStringChecksummed(), " decimals:", decimals.toString()));
    }

    function toFloatString(uint256 value, uint256 decimals, string memory symbol) public pure returns (string memory) {
        uint256 ten = 10 ** decimals;
        uint256 integerPart = value / ten; // Whole number part
        uint256 fractionalValue = value % ten;
        uint256 divider = ten / 10;
        uint256 fractionalPart = fractionalValue / divider; // Fractional part (1 decimal place)
        string memory integerString = integerPart.toString();
        return fractionalPart == 0
            ? string.concat(integerString, " ", symbol)
            : string(abi.encodePacked(integerString, ".", fractionalPart.toString(), " ", symbol));
    }

    function toPercentString(uint256 value) public pure returns (string memory) {
        return toFloatString(value, 3, "%");
    }

    function printMarket(string memory divider, IDahlia.MarketId id) public view {
        IDahlia.Market memory market = DAHLIA.getMarket(id);
        address addr = address(market.vault);
        WrappedVault vault = WrappedVault(addr);
        IERC20Metadata loanToken = IERC20Metadata(market.loanToken);
        IERC20Metadata collateralToken = IERC20Metadata(market.collateralToken);
        console.log(string.concat(divider, vault.name(), " ------"));
        console.log(string.concat("borrowed: ", toFloatString(market.totalBorrowAssets, loanToken.decimals(), loanToken.symbol())));
        printToken("Loan token:", loanToken, loanToken.balanceOf(addr));
        printToken("Collateral:", collateralToken, market.totalCollateralAssets);
        console.log(
            string.concat(
                "BORROWER LTV:",
                toPercentString(DAHLIA.getPositionLTV(id, BORROWER)),
                " LLTV:",
                toPercentString(market.lltv),
                " Liquidation fee:",
                toPercentString(market.liquidationBonusRate)
            )
        );
        console.log("");
    }

    function createTestOracle(uint256 price) public virtual returns (IDahliaOracle) {
        OracleMock oracle = new OracleMock();
        oracle.setPrice(price);
        return oracle;
    }

    function copyMarket(IDahlia.Market memory realMarket) internal returns (IDahlia.MarketId id) {
        WrappedVault realVault = WrappedVault(address(realMarket.vault));
        IDahliaOracle oracle = realMarket.oracle;
        (uint256 price, bool isBadData) = oracle.getPrice();
        assertEq(isBadData, false);
        address loanToken = realMarket.loanToken;
        address collateralToken = realMarket.collateralToken;
        IDahlia.MarketConfig memory marketConfig = IDahlia.MarketConfig({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: createTestOracle(price),
            irm: realMarket.irm,
            lltv: realMarket.lltv,
            liquidationBonusRate: realMarket.liquidationBonusRate,
            name: string.concat("COPY ", realVault.name()),
            owner: realVault.owner()
        });
        id = DAHLIA.deployMarket(marketConfig);

        printMarket("---- CLONED: ", id);
    }
}
