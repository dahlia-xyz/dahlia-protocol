// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { Vm, console } from "forge-std/Test.sol";
import { TestContext } from "test/common/TestContext.sol";
import { ERC20Mock } from "test/common/mocks/ERC20Mock.sol";

interface IERC20Mint is IERC20Metadata {
    function mint(address account, uint256 value) external returns (bool);
    function owner() external view returns (address);
}

contract TestContextNetwork is TestContext {
    //    mapping(string => address) public tokenOwners;
    mapping(address => address) public tokenSuppliers;
    mapping(address => string) public contractName;

    constructor(Vm vm_) TestContext(vm_) { }

    function _addContract(string memory name, address addr) internal {
        contracts[name] = addr;
        contractName[addr] = name;
        //        tokenOwners[name] = IERC20Mint(addr).owner();
        vm.label(addr, string.concat("[ ", name, " ]"));
    }

    function _addContract(string memory name, address addr, address supplier) internal {
        contracts[name] = addr;
        contractName[addr] = name;
        tokenSuppliers[addr] = supplier;
        vm.label(addr, string.concat("[ ", name, " ]"));
    }

    function _mint(address addr, address wallet, uint256 amount) public {
        IERC20Mint token = IERC20Mint(addr);
        address supplier = tokenSuppliers[addr];
        string memory tokenName = contractName[addr];
        if (supplier == address(0)) {
            address owner = token.owner();
            console.log("_mint(): owner:", owner, amount, tokenName);
            vm.prank(owner);
            token.mint(wallet, amount);
        } else {
            console.log("transfer(): supplier:", supplier, amount, tokenName);
            vm.prank(supplier);
            token.transfer(wallet, amount);
        }
    }

    function _mint(string memory name, address wallet, uint256 amount) public {
        _mint(contracts[name], wallet, amount);
    }

    function createERC20Token(string memory name) public view override returns (ERC20Mock token) {
        return ERC20Mock(contracts[name]);
    }
}
