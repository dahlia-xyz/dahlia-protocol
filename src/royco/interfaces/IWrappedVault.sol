/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IWrappedVault {
    /// @return The address of the vault owner
    function owner() external view returns (address);

    /// @param account The address to get the principal balance of
    /// @return The principal balance of the given account
    function principal(address account) external view returns (uint256);

    /// @return The total principal of all accounts
    function totalPrincipal() external view returns (uint256);

    /// @param shares The amount of shares to mint
    /// @param receiver The address to mint the fees for
    /// @dev Can be called only by the Dahlia contract, used only to emit transfer event
    function mintFees(uint256 shares, address receiver) external;

    /// @param from The address to burn the shares for
    /// @param shares The amount of shares to burn
    /// @dev Can be called only by the Dahlia contract, used only to emit transfer event
    function burnShares(address from, uint256 shares) external;

    /// @param to The address to send the rewards to
    /// @param reward The reward token / points program to claim rewards from
    function claim(address to, address reward) external payable;

    /// @return assetTokenAddress The address of the asset token
    function asset() external view returns (address assetTokenAddress);

    /// @return totalManagedAssets The amount of eth controlled by the vault
    function totalAssets() external view returns (uint256 totalManagedAssets);

    /// @param assets The amount of assets to convert to shares
    /// @return shares The value of the given assets in shares
    function convertToShares(uint256 assets) external view returns (uint256 shares);

    /// @param shares The amount of shares to convert to assets
    /// @return assets The value of the given shares in assets
    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    /// @param receiver The address in question of who would be depositing, doesn't matter in this case
    /// @return maxAssets The maximum amount of assets that can be deposited
    function maxDeposit(address receiver) external view returns (uint256 maxAssets);

    /// @param assets The amount of assets that would be deposited
    /// @return shares The amount of shares that would be minted, *under ideal conditions* only
    function previewDeposit(uint256 assets) external view returns (uint256 shares);

    /// @param assets The amount of assets which should be deposited
    /// @param receiver The address user whom should receive the mevEth out
    /// @return shares The amount of shares minted
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /// @param receiver The address in question of who would be minting, doesn't matter in this case
    /// @return maxShares The maximum amount of shares that can be minted
    function maxMint(address receiver) external view returns (uint256 maxShares);

    /// @param shares The amount of shares that would be minted
    /// @return assets The amount of assets that would be required, *under ideal conditions* only
    function previewMint(uint256 shares) external view returns (uint256 assets);

    /// @param shares The amount of shares that should be minted
    /// @param receiver The address user whom should receive the mevEth out
    /// @return assets The amount of assets deposited
    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    /// @param owner The address in question of who would be withdrawing
    /// @return maxAssets The maximum amount of assets that can be withdrawn
    function maxWithdraw(address owner) external view returns (uint256 maxAssets);

    /// @param assets The amount of assets that would be withdrawn
    /// @return shares The amount of shares that would be burned, *under ideal conditions* only
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);

    /// @param assets The amount of assets that should be withdrawn
    /// @param receiver The address user whom should receive the mevEth out
    /// @param from The address of the owner of the mevEth
    /// @return shares The amount of shares burned
    function withdraw(uint256 assets, address receiver, address from) external returns (uint256 shares);

    /// @param owner The address in question of who would be redeeming their shares
    /// @return maxShares The maximum amount of shares they could redeem
    function maxRedeem(address owner) external view returns (uint256 maxShares);

    /// @param shares The amount of shares that would be burned
    /// @return assets The amount of assets that would be withdrawn, *under ideal conditions* only
    function previewRedeem(uint256 shares) external view returns (uint256 assets);

    /// @param shares The amount of shares that should be burned
    /// @param receiver The address user whom should receive the wETH out
    /// @param from The address of the owner of the lend assets
    /// @return assets The amount of assets withdrawn
    function redeem(uint256 shares, address receiver, address from) external returns (uint256 assets);

    /**
     * @dev Emitted when a deposit is made, either through mint or deposit
     */
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);

    /**
     * @dev Emitted when a withdrawal is made, either through redeem or withdraw
     */
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);
}
